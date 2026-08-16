import Foundation

/// Строка вычитки: перевод рядом с оригиналом. По одному русскому ошибку не видно —
/// «отказался платить аренду брату» читается гладко, пока не увидишь «my brother's rent».
public struct TranslatedLine: Identifiable, Hashable, Codable, Sendable {

    public let id: Int
    public let kind: ScriptSegment.Kind
    public let source: String
    public let translation: String

    public init(id: Int, kind: ScriptSegment.Kind, source: String, translation: String) {
        self.id = id
        self.kind = kind
        self.source = source
        self.translation = translation
    }

    /// Подпись под строкой. У крючка и вопроса оригинала нет — они сочинены по рассказу,
    /// а не переведены, и вместо пустого места объясняем, что это за фраза.
    public var caption: String {
        if !source.isEmpty { return source }

        return switch kind {
        case .outro: "Question to the viewer — the last line of the video"
        default: "Hook — the first line of the video"
        }
    }

    /// Разбиение на слова одно на всех: вид рисует их по индексам, а модель по тем же
    /// индексам собирает фрагмент, в который ткнули.
    public var words: [String] {
        translation.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public func fragment(_ indexes: Set<Int>) -> String {
        indexes.sorted().map { words[$0] }.joined(separator: " ")
    }
}
