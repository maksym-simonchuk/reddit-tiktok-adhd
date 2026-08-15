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

    /// Набирает сегменты по порядку, пока хватает бюджета слов, а первый не влезающий
    /// режет по предложениям. Выбрасывать его целиком нельзя: тело рассказа почти всегда
    /// длиннее бюджета, и от треда оставался один заголовок на три секунды.
    func trim(_ segments: [ScriptSegment], toDuration limit: Double) -> [ScriptSegment] {
        var budget = Int(limit * Script.wordsPerSecond)
        var kept: [ScriptSegment] = []

        for segment in segments {
            guard budget > 0 else { break }
            let words = segment.text.split(whereSeparator: \.isWhitespace).count

            if words <= budget {
                kept.append(segment)
                budget -= words
                continue
            }

            let text = cut(segment.text, toWords: budget)
            if !text.isEmpty { kept.append(ScriptSegment(kind: segment.kind, text: text)) }
            break
        }

        return kept
    }

    /// Обрезка по границе предложения: оборванная на полуслове фраза звучит как сбой.
    private func cut(_ text: String, to characters: Int) -> String {
        guard text.count > characters else { return text }
        return accumulateSentences(of: text) { $0.count + $1.count + 1 <= characters }
    }

    private func cut(_ text: String, toWords words: Int) -> String {
        let all = text.split(whereSeparator: \.isWhitespace)
        guard all.count > words else { return text }

        let bySentence = accumulateSentences(of: text) { current, sentence in
            let used = current.split(whereSeparator: \.isWhitespace).count
            return used + sentence.split(whereSeparator: \.isWhitespace).count <= words
        }

        // Первое предложение может само не влезть в бюджет. Тогда режем по словам:
        // перебор в три раза по длительности хуже оборванной фразы.
        guard bySentence.split(whereSeparator: \.isWhitespace).count <= words else {
            return all.prefix(words).joined(separator: " ")
        }

        return bySentence
    }

    /// Набирает предложения, пока `fits` разрешает. Если не влезло даже первое —
    /// отдаёт его целиком: длинный сегмент лучше пустого.
    private func accumulateSentences(of text: String, fits: (String, String) -> Bool) -> String {
        let sentences = Sentences.of(text)
        var result = ""

        for sentence in sentences {
            guard fits(result, sentence) else { break }
            result = result.isEmpty ? sentence : result + " " + sentence
        }

        if !result.isEmpty { return result }
        return sentences.first ?? text
    }
}
