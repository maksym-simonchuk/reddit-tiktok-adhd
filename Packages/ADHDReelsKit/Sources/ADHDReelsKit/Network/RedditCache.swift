import Foundation

/// Ответы Reddit на диске. Анонимный трафик режут жёстко, поэтому один и тот же список
/// тредов тянется один раз, а обновляет его только кнопка в ленте.
enum RedditCache {

    static let folder = URL.cachesDirectory.appending(path: "Reddit")

    static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = try? Data(contentsOf: file(key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save(_ value: some Encodable, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file(key), options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: folder)
    }

    private static func file(_ key: String) -> URL {
        folder.appending(path: key + ".json")
    }
}
