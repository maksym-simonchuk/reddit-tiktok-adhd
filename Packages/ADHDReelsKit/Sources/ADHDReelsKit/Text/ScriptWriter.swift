import Foundation

/// Собирает сценарий в два приёма: `draft` даёт вычищенный английский,
/// между ними работает `Translator`, `finish` нормализует русский и режет под длительность.
public struct ScriptWriter: Sendable {

    public struct Options: Sendable {
        /// Целевая длительность озвучки в секундах.
        public var targetDuration: Double = 45
        public var includeSelftext = true
        /// Ограничение на сегмент до перевода — переводить то, что всё равно обрежется, незачем.
        public var maxSourceCharacters = 1200
        /// Язык готового сценария: на нём говорит обращение к зрителю и по нему
        /// решается, нормализовать ли текст по-русски.
        public var language = ReelLanguage.russian

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

        // Запас 1.4 — русский перевод обычно чуть длиннее, точная обрезка будет в `finish`.
        return trim(segments, toDuration: options.targetDuration * 1.4)
    }

    /// Финал: нормализация каждого сегмента и обрезка под целевую длительность.
    ///
    /// `hook` — крючок, написанный `HookWriter` по самой истории. Он встаёт первой
    /// строкой вместо заголовка треда и идёт в общий бюджет, а не сверх него: ролик
    /// должен остаться той же длины. Без него первой строкой остаётся заголовок.
    ///
    /// `outro` — вопрос зрителю от `OutroWriter`. Обрезка режет хвост, а он и есть хвост,
    /// поэтому его снимают до неё и возвращают после: ролик, оборванный на середине
    /// чужой ссоры, комментариев не собирает. Вычитанный текст приходит с ним внутри —
    /// оттуда его и берём, чтобы правка человека не потерялась.
    public func finish(_ segments: [ScriptSegment], hook: String? = nil, outro: String? = nil) -> Script {
        var all = segments
            .map { ScriptSegment(kind: $0.kind, text: normalize($0.text)) }
            .filter { !$0.text.isEmpty }

        guard !all.isEmpty else { return Script(segments: []) }

        var tail = all.last?.kind == .outro ? all.removeLast() : nil
        if let outro {
            let text = normalize(outro)
            if !text.isEmpty { tail = ScriptSegment(kind: .outro, text: text) }
        }

        if let hook {
            let text = normalize(hook)
            if !text.isEmpty {
                // Крючок заменяет заголовок треда, а не встаёт перед ним: заголовок
                // пересказывает ту же завязку, и подряд они звучат повтором — а дальше
                // ту же завязку в третий раз начинает сам рассказ.
                if all.first?.kind == .hook { all.removeFirst() }
                all.insert(ScriptSegment(kind: .hook, text: text), at: 0)
            }
        }

        let spent = tail.map { Double($0.text.split(whereSeparator: \.isWhitespace).count) / Script.wordsPerSecond(for: options.language) } ?? 0
        var kept = trim(all, toDuration: options.targetDuration - spent)
        if let tail { kept.append(tail) }

        return Script(segments: kept)
    }

    /// Нормализация написана под русский: цифры прописью, ё, транслитерация латиницы.
    /// Остальным языкам она бы только сломала текст — там хватает общей чистки.
    private func normalize(_ text: String) -> String {
        options.language == .russian ? normalizer.normalize(text) : TextTidy.tidy(text)
    }

    // MARK: - Обрезка

    /// Набирает сегменты по порядку, пока хватает бюджета слов, а первый не влезающий
    /// режет по предложениям. Выбрасывать его целиком нельзя: тело рассказа почти всегда
    /// длиннее бюджета, и от треда оставался один заголовок на три секунды.
    func trim(_ segments: [ScriptSegment], toDuration limit: Double) -> [ScriptSegment] {
        var budget = Int(limit * Script.wordsPerSecond(for: options.language))
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
