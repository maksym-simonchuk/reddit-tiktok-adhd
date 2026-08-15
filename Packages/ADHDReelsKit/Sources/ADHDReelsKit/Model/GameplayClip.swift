import Foundation

/// Файл фонового геймплея, лежащий в `Documents/Gameplay`.
public struct GameplayClip: Identifiable, Hashable, Sendable {

    /// Имя файла — оно же ключ курсора, поэтому переименование сбрасывает позицию.
    public var id: String { url.lastPathComponent }

    public let url: URL
    public let duration: Double
    public let bytes: Int64

    public init(url: URL, duration: Double, bytes: Int64) {
        self.url = url
        self.duration = duration
        self.bytes = bytes
    }
}

/// Кусок геймплея под конкретный отрезок ролика.
public struct GameplaySegment: Hashable, Sendable {

    public let url: URL
    public let start: Double
    public let duration: Double

    public init(url: URL, start: Double, duration: Double) {
        self.url = url
        self.start = start
        self.duration = duration
    }
}
