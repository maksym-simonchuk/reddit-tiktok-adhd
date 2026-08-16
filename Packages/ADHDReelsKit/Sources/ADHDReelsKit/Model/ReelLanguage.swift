import Foundation

/// Язык озвучки. От него зависит вся середина конвейера: переводить ли тред вообще,
/// чем переводить, кто читает и на каком языке пишется подпись.
public enum ReelLanguage: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {

    case russian = "ru"
    case english = "en"
    case spanish = "es"
    case portuguese = "pt"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .russian: "Russian"
        case .english: "English"
        case .spanish: "Spanish"
        case .portuguese: "Portuguese"
        }
    }

    /// Треды приходят с англоязычного Reddit: на английском озвучиваем исходник как есть.
    public var needsTranslation: Bool { self != .english }

    public var locale: Locale.Language { Locale.Language(identifier: rawValue) }
}
