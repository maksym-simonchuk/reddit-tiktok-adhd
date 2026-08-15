import AVFoundation
import Foundation

/// Хранилище фонового геймплея. Держит курсор по каждому файлу, чтобы два ролика
/// подряд не показывали один и тот же кусок паркура.
public actor GameplayLibrary {

    public enum Failure: LocalizedError, Equatable {
        case empty
        case unreadable(String)

        public var errorDescription: String? {
            switch self {
            case .empty:
                "Нет геймплея. Положите вертикальные видео в папку ADHDReels через «Файлы»."
            case .unreadable(let name):
                "Не читается файл «\(name)». Скорее всего он ещё копируется."
            }
        }
    }

    public static let folderName = "Gameplay"

    /// Файл короче — это обрезок, а не фон: на нём курсор мгновенно упирается в конец.
    static let minimumDuration = 10.0

    private let root: URL
    private var cache: [GameplayClip] = []

    public init(root: URL? = nil) {
        self.root = root ?? URL.documentsDirectory.appending(path: Self.folderName)
    }

    // MARK: - Содержимое

    public func refresh() async throws -> [GameplayClip] {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var clips: [GameplayClip] = []
        for file in files where Self.videoExtensions.contains(file.pathExtension.lowercased()) {
            let duration = try await CMTimeGetSeconds(AVURLAsset(url: file).load(.duration))
            guard duration >= Self.minimumDuration else { continue }

            let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap(Int64.init) ?? 0
            clips.append(GameplayClip(url: file, duration: duration, bytes: bytes))
        }

        cache = clips.sorted { $0.id < $1.id }
        return cache
    }

    public func clips() -> [GameplayClip] { cache }

    public func diskUsage() -> Int64 { cache.reduce(0) { $0 + $1.bytes } }

    // MARK: - Раскладка под ролик

    public func segments(for duration: Double) throws -> [GameplaySegment] {
        guard !cache.isEmpty else { throw Failure.empty }

        var cursors = Self.cursors
        let segments = Self.plan(duration: duration, clips: cache, cursors: &cursors, startIndex: Self.rotation)
        Self.cursors = cursors
        Self.rotation = Self.rotation + 1

        return segments
    }

    /// Чистая функция, чтобы раскладку можно было проверить без видеофайлов.
    /// Один ролик на видео: режем только когда геймплей кончился, иначе фон дёргается.
    static func plan(
        duration: Double,
        clips: [GameplayClip],
        cursors: inout [String: Double],
        startIndex: Int
    ) -> [GameplaySegment] {
        guard duration > 0, !clips.isEmpty else { return [] }

        var segments: [GameplaySegment] = []
        var remaining = duration
        var index = startIndex

        // Предел на случай, если ролики окажутся короче остатка: без него цикл
        // крутится, пока не наберёт длительность из кусочков по миллисекунде.
        var attempts = clips.count * 4
        while remaining > 0.01, attempts > 0 {
            attempts -= 1

            let clip = clips[((index % clips.count) + clips.count) % clips.count]
            index += 1

            // Хвост короче секунды монтировать нечего — заходим на ролик заново.
            var start = cursors[clip.id] ?? 0
            if clip.duration - start < 1 { start = 0 }

            let take = min(clip.duration - start, remaining)
            guard take > 0 else { continue }

            segments.append(GameplaySegment(url: clip.url, start: start, duration: take))
            cursors[clip.id] = start + take
            remaining -= take
        }

        return segments
    }

    // MARK: - Импорт и удаление

    public func `import`(_ source: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        let target = Self.freeName(for: source.lastPathComponent, in: root)
        do {
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            throw Failure.unreadable(source.lastPathComponent)
        }
    }

    public func delete(_ clip: GameplayClip) throws {
        try FileManager.default.removeItem(at: clip.url)
        cache.removeAll { $0.id == clip.id }
        Self.cursors[clip.id] = nil
    }

    // MARK: - Детали

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    static func freeName(for name: String, in folder: URL) -> URL {
        let candidate = folder.appending(path: name)
        guard FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension

        for suffix in 2... {
            let next = folder.appending(path: "\(base)-\(suffix)").appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: next.path(percentEncoded: false)) { return next }
        }

        return candidate
    }

    /// Курсоры переживают перезапуск: иначе каждый сеанс начинается с одного кадра.
    private static var cursors: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: "gameplay.cursors") as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "gameplay.cursors") }
    }

    private static var rotation: Int {
        get { UserDefaults.standard.integer(forKey: "gameplay.rotation") }
        set { UserDefaults.standard.set(newValue, forKey: "gameplay.rotation") }
    }
}
