import Foundation

/// Читает публичные JSON-эндпоинты Reddit. Ни OAuth, ни аккаунта — только чтение.
/// Анонимный трафик режут жёстко, поэтому пауза между запросами, ретраи и запасной хост.
public actor RedditFetcher {

    public enum Failure: LocalizedError {
        case rateLimited
        case blocked
        case badStatus(Int)
        case malformed
        case empty

        public var errorDescription: String? {
            switch self {
            case .rateLimited: "Reddit is rate-limiting this device. Wait a minute and try again."
            case .blocked: "Reddit is not serving data to this device. Try again later or use a VPN."
            case .badStatus(let code): "Reddit responded with status \(code)."
            case .malformed: "Reddit sent a response in an unknown format."
            case .empty: "No posts matched the current filters."
            }
        }

        /// Отказ по адресу, а не по данным: те же посты стоит попробовать взять из RSS.
        var isBlocked: Bool {
            switch self {
            case .blocked, .rateLimited: true
            case .badStatus(let code): code >= 500
            default: false
            }
        }
    }

    /// Первый запрос идёт на основной хост, ретраи — на старый: он отдаёт JSON,
    /// когда основной уже отвечает 403.
    private static let hosts = ["www.reddit.com", "old.reddit.com"]
    private static let attempts = 3

    private let session: URLSession
    private let minimumInterval: TimeInterval = 2
    private var lastRequest: Date = .distantPast

    /// True when the last `topPosts` had to fall back to RSS. RSS carries no NSFW
    /// flag, so safe mode can't verify those posts — the caller uses this to say so
    /// instead of silently pretending the filter still works.
    public private(set) var lastFetchUsedRSS = false

    public init(userAgent: String = "ios:com.local.adhdreels:v1.0 (personal use)") {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        configuration.timeoutIntervalForRequest = 20
        self.session = URLSession(configuration: configuration)
    }

    /// Топ подреддита за окно: hour, day, week, month, year, all. Ответ кладётся в кеш
    /// и дальше отдаётся оттуда; `refresh` выбрасывает весь кеш и идёт в сеть заново.
    public func topPosts(
        subreddit: String,
        window: String = "day",
        limit: Int = 25,
        allowNSFW: Bool = false,
        minimumScore: Int = 500,
        refresh: Bool = false
    ) async throws -> [RedditPost] {
        let key = "top-\(subreddit)-\(window)-\(limit)-\(minimumScore)-\(allowNSFW)"
        lastFetchUsedRSS = false

        if refresh {
            RedditCache.clear()
        } else if let cached: [RedditPost] = RedditCache.load(key) {
            return cached
        }

        let posts: [RedditPost]
        do {
            let data = try await get("/r/\(subreddit)/top.json?t=\(window)&limit=\(limit)&raw_json=1")
            do {
                posts = try RedditListing.posts(from: data, minimumScore: minimumScore, allowNSFW: allowNSFW)
            } catch {
                throw Failure.malformed
            }
        } catch let failure as Failure where failure.isBlocked {
            let data = try await get("/r/\(subreddit)/top/.rss?t=\(window)")
            posts = RedditRSS.posts(from: data, subreddit: subreddit)
            lastFetchUsedRSS = true
        }

        guard !posts.isEmpty else { throw Failure.empty }
        RedditCache.save(posts, for: key)
        return posts
    }

    // MARK: - Транспорт

    private func get(_ path: String) async throws -> Data {
        var lastFailure = Failure.blocked

        for attempt in 0..<Self.attempts {
            let host = Self.hosts[min(attempt, Self.hosts.count - 1)]
            guard let url = URL(string: "https://\(host)\(path)") else { throw Failure.malformed }

            try await throttle()
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else { throw Failure.malformed }

            switch http.statusCode {
            case 200..<300:
                return data
            case 429:
                lastFailure = .rateLimited
            case 403, 404, 500...599:
                lastFailure = http.statusCode == 403 ? .blocked : .badStatus(http.statusCode)
            default:
                throw Failure.badStatus(http.statusCode)
            }

            if attempt < Self.attempts - 1 {
                try await Task.sleep(for: .seconds(pow(2, Double(attempt))))
            }
        }

        throw lastFailure
    }

    private func throttle() async throws {
        let elapsed = Date().timeIntervalSince(lastRequest)
        if elapsed < minimumInterval {
            try await Task.sleep(for: .seconds(minimumInterval - elapsed))
        }
        lastRequest = Date()
    }
}
