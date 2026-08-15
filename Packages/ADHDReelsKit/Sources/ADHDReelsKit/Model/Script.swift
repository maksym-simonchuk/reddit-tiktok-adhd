import Foundation

/// Один произносимый кусок. `kind` управляет стилем субтитра: хук крупнее и висит дольше.
public struct ScriptSegment: Hashable, Sendable {

    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case hook
        case body
        case comment
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

    /// Замер на устройстве: 101 слово голосом Piper — 3.36 сл/с, плюс паузы между фразами.
    /// Системная Милена медленнее (2.35 сл/с), но она запасной путь: с ней ролик выходит
    /// длиннее целевого, а не короче, и это лучше обрыва на полуслове.
    public static let wordsPerSecond = 3.2

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
