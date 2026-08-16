import Foundation

/// Один произносимый кусок. `kind` управляет подачей: хук читается медленнее и с большим
/// разбросом интонации, вопрос в конце — с паузой перед ним.
public struct ScriptSegment: Codable, Hashable, Sendable {

    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case hook
        case body
        /// Вопрос зрителю в самом конце — за ним идут комментарии.
        case outro
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Готовый русский сценарий. Английский черновик до перевода живёт как `[ScriptSegment]`.
public struct Script: Hashable, Sendable {

    /// Замер на устройстве: 101 слово нейроголосом — 3.36 сл/с, плюс паузы между фразами;
    /// с ускорением подачи в полтора раза (`SpeechDelivery.pace`) выходит 4.8. Системный
    /// голос медленнее, но он запасной путь: с ним ролик выходит длиннее целевого,
    /// а не короче, и это лучше обрыва на полуслове.
    public static let wordsPerSecond = 4.8

    /// Narration pace differs per language: the Russian path is the neural voice measured
    /// above; the others go through the system voice at its default delivery, where
    /// ~155 wpm keeps Shorts narration in the natural 130–170 wpm band.
    public static func wordsPerSecond(for language: ReelLanguage) -> Double {
        switch language {
        case .russian: wordsPerSecond
        case .english: 2.6
        case .spanish, .portuguese: 2.8
        }
    }

    public let segments: [ScriptSegment]

    public init(segments: [ScriptSegment]) {
        self.segments = segments
    }

    public var plainText: String {
        segments.map(\.text).joined(separator: " ")
    }

    public var wordCount: Int {
        plainText.split(whereSeparator: \.isWhitespace).count
    }

    /// Оценка до синтеза — нужна, чтобы обрезать сценарий под целевую длительность.
    public var estimatedDuration: Double {
        Double(wordCount) / Self.wordsPerSecond
    }
}
