import Foundation

/// Готовая подпись к ролику. Копируется в буфер одной кнопкой, поэтому хранится
/// уже собранной строкой, а не тремя полями, которые надо склеивать в вёрстке.
public struct ReelDescription: Hashable, Sendable, Codable {

    public let title: String
    public let body: String
    public let tags: [String]

    public init(title: String, body: String, tags: [String]) {
        self.title = title
        self.body = body
        self.tags = tags
    }

    public var forClipboard: String {
        let hashtags = tags.map { "#" + $0 }.joined(separator: " ")
        return "\(title)\n\n\(body)\n\n\(hashtags)"
    }
}

/// Готовый ролик на диске.
public struct Reel: Identifiable, Hashable, Sendable, Codable {

    public let id: UUID
    public let title: String
    public let subreddit: String
    public let permalink: String
    public let fileName: String
    public let duration: Double
    public let createdAt: Date
    public let description: ReelDescription

    public init(
        id: UUID = UUID(),
        title: String,
        subreddit: String,
        permalink: String,
        fileName: String,
        duration: Double,
        createdAt: Date = Date(),
        description: ReelDescription
    ) {
        self.id = id
        self.title = title
        self.subreddit = subreddit
        self.permalink = permalink
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.description = description
    }

    /// Путь пересобирается от Documents, а не хранится: контейнер приложения
    /// меняет адрес после каждой переустановки, и сохранённый URL протухает.
    public var url: URL {
        URL.documentsDirectory.appending(path: Reel.folderName).appending(path: fileName)
    }

    /// Обложка лежит рядом с видео под тем же именем: второй путь хранить незачем,
    /// а старые ролики просто остаются без файла.
    public var coverURL: URL {
        url.deletingPathExtension().appendingPathExtension("jpg")
    }

    public static let folderName = "Reels"
}
