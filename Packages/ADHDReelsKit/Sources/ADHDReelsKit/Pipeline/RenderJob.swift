import Foundation

/// Начатая, но не законченная сборка. Лежит на диске, потому что телефон забирает
/// процессор у свёрнутого приложения, а иногда и убивает его целиком: без файла
/// нажатие «Сделать ролик» пропало бы вместе с процессом.
///
/// Промежуточных шагов внутри нет — озвучку и монтаж не докрутить с середины,
/// поэтому возобновление всегда начинается сначала.
public struct RenderJob: Codable, Sendable {

    public let post: RedditPost
    public let approved: [ScriptSegment]?
    public let settings: ReelSettings

    public init(post: RedditPost, approved: [ScriptSegment]?, settings: ReelSettings) {
        self.post = post
        self.approved = approved
        self.settings = settings
    }

    static let url = URL.documentsDirectory.appending(path: "pending-render.json")

    public static func saved() -> RenderJob? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RenderJob.self, from: data)
    }

    func keep() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
