import Foundation

/// Перевод одного треда занимает секунды, поэтому кэшируем по исходному тексту:
/// один и тот же комментарий в разных подборках переводится один раз.
public struct TranslationCache: Sendable {

    public static var defaultURL: URL? {
        try? FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "cache/translations.json")
    }

    /// Хранилище не должно расти бесконечно — оставляем последние переводы.
    private static let limit = 500

    private let url: URL?
    private var entries: [Entry]
    private var index: [String: String]

    public init(url: URL?) {
        self.url = url
        let loaded = Self.load(from: url)
        self.entries = loaded
        self.index = Dictionary(loaded.map { ($0.source, $0.target) }, uniquingKeysWith: { _, last in last })
    }

    public subscript(source: String) -> String? {
        get { index[source] }
        set {
            guard let newValue else { return }
            if index.updateValue(newValue, forKey: source) != nil {
                entries.removeAll { $0.source == source }
            }
            entries.append(Entry(source: source, target: newValue))
        }
    }

    public mutating func save() {
        guard let url else { return }
        if entries.count > Self.limit {
            entries.removeFirst(entries.count - Self.limit)
            index = Dictionary(entries.map { ($0.source, $0.target) }, uniquingKeysWith: { _, last in last })
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func load(from url: URL?) -> [Entry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private struct Entry: Codable, Sendable {
        let source: String
        let target: String
    }
}
