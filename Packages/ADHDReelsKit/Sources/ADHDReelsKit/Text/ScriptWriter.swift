import Foundation

/// Собирает сценарий в два приёма: `draft` даёт вычищенный английский,
/// между ними работает `Translator`, `finish` нормализует русский и режет под длительность.
public struct ScriptWriter: Sendable {

    public struct Options: Sendable {
        /// Целевая длительность озвучки в секундах.
        public var targetDuration: Double = 45
        public var includeSelftext = true
        public var maxComments = 4
        /// Ограничение на сегмент до перевода — переводить то, что всё равно обрежется, незачем.
        public var maxSourceCharacters = 1200

        public init() {}
    }

    private let options: Options
    private let normalizer = RussianNormalizer()

    public init(options: Options = Options()) {
        self.options = options
    }

    /// Английский черновик: чистка markdown и грубая обрезка с запасом.
    public func draft(from post: RedditPost) -> [ScriptSegment] {
        var segments: [ScriptSegment] = []

        let hook = EnglishCleaner.clean(post.title)
        if !hook.isEmpty {
            segments.append(ScriptSegment(kind: .hook, text: hook))
        }

        if options.includeSelftext {
            let body = EnglishCleaner.clean(post.selftext)
            if body.count > 20 {
                segments.append(ScriptSegment(kind: .body, text: cut(body, to: options.maxSourceCharacters)))
            }
        }

        for comment in post.comments.prefix(options.maxComments) {
            let text = EnglishCleaner.clean(comment.body)
            guard text.count > 15 else { continue }
            segments.append(ScriptSegment(kind: .comment, text: cut(text, to: options.maxSourceCharacters)))
        }

        // Запас 1.4 — русский перевод обычно чуть длиннее, точная обрезка будет в `finish`.
        return trim(segments, toDuration: options.targetDuration * 1.4)
    }

    /// Русский финал: нормализация каждого сегмента и обрезка под целевую длительность.
    public func finish(_ segments: [ScriptSegment]) -> Script {
        let normalized = segments
            .map { ScriptSegment(kind: $0.kind, text: normalizer.normalize($0.text)) }
            .filter { !$0.text.isEmpty }

        return Script(segments: trim(normalized, toDuration: options.targetDuration))
    }

    // MARK: - Обрезка

    private func trim(_ segments: [ScriptSegment], toDuration limit: Double) -> [ScriptSegment] {
        var segments = segments

        // Хук выкидывать нельзя — без него ролик не за что зацепить.
        while segments.count > 1, Script(segments: segments).estimatedDuration > limit {
            segments.removeLast()
        }

        if let first = segments.first,
           segments.count == 1,
           Script(segments: segments).estimatedDuration > limit {
            let words = Int(limit * Script.wordsPerSecond)
            segments[0] = ScriptSegment(kind: first.kind, text: cut(first.text, toWords: words))
        }

        return segments
    }

    /// Обрезка по границе предложения: оборванная на полуслове фраза звучит как сбой.
    private func cut(_ text: String, to characters: Int) -> String {
        guard text.count > characters else { return text }
        return accumulateSentences(of: text) { $0.count + $1.count + 1 <= characters }
    }

    private func cut(_ text: String, toWords words: Int) -> String {
        guard text.split(whereSeparator: \.isWhitespace).count > words else { return text }
        return accumulateSentences(of: text) { current, sentence in
            let used = current.split(whereSeparator: \.isWhitespace).count
            return used + sentence.split(whereSeparator: \.isWhitespace).count <= words
        }
    }

    /// Набирает предложения, пока `fits` разрешает. Если не влезло даже первое —
    /// отдаёт его целиком: длинный сегмент лучше пустого.
    private func accumulateSentences(of text: String, fits: (String, String) -> Bool) -> String {
        let sentences = Self.sentences(of: text)
        var result = ""

        for sentence in sentences {
            guard fits(result, sentence) else { break }
            result = result.isEmpty ? sentence : result + " " + sentence
        }

        if !result.isEmpty { return result }
        return sentences.first ?? text
    }

    private static func sentences(of text: String) -> [String] {
        var sentences: [String] = []

        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { sentence, _, _, _ in
            guard let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty else { return }
            sentences.append(sentence)
        }

        return sentences
    }
}
