import Foundation

/// Одна фонема на входе VITS. Модель получает не только звук: рядом идут четыре
/// потока про пунктуацию — что стоит на этом месте, внутри ли кавычек, чем кончился
/// текущий кусок и чем кончится предложение. Из них она и берёт интонацию: с чего
/// поднять голос, где притормозить, куда вести фразу.
struct VoskFrame: Equatable, Sendable {

    let phoneme: Int32
    let punctuation: Int32
    let quoted: Int32
    let lastPunctuation: Int32
    let lastSentence: Int32
    /// Номер слова: по нему фонема забирает свой эмбеддинг из ruBERT.
    let word: Int
}

/// Разбор фразы на фонемы с потоками пунктуации — порт `g2p_multistream` из vosk-tts.
struct VoskPhonemes: Sendable {

    /// Разделители из оригинального регулярного выражения. Дефис в набор не входит:
    /// «тест-драйв» должен остаться одним словом, а тире отлавливается как «дефис плюс пробел».
    private static let separators: Set<String> = ["...", ",", ".", "?", "!", ";", ":", "(", ")"]
    private static let quote = "\""
    private static let space = " "

    /// `phoneme_id_map` из config.json: и фонемы, и знаки препинания живут в одном словаре.
    let identifiers: [String: Int32]
    let lookup: @Sendable (String) -> [String]?

    func frames(of text: String) -> [VoskFrame] {
        collect(from: Self.parts(of: text.replacingOccurrences(of: " -", with: "- ").lowercased()))
    }

    // MARK: - Разбиение

    /// Тот же результат, что у `re.split` с захватом: разделители остаются в списке.
    private static func parts(of text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var index = text.startIndex

        func flush() {
            guard !current.isEmpty else { return }
            parts.append(current)
            current = ""
        }

        while index < text.endIndex {
            let rest = text[index...]

            if rest.hasPrefix("...") {
                flush()
                parts.append("...")
                index = text.index(index, offsetBy: 3)
            } else if rest.hasPrefix("- ") {
                // Тире отделяет клаузу, а дефис внутри слова — нет.
                flush()
                parts.append("- ")
                index = text.index(index, offsetBy: 2)
            } else if separators.contains(String(text[index])) || text[index] == "\"" || text[index] == " " {
                flush()
                parts.append(String(text[index]))
                index = text.index(after: index)
            } else {
                current.append(text[index])
                index = text.index(after: index)
            }
        }
        flush()

        return parts
    }

    // MARK: - Сборка

    private struct Symbol {
        let text: String
        let punctuation: [String]
        let quoted: Int32
        let word: Int
    }

    private func collect(from parts: [String]) -> [VoskFrame] {
        var symbols = [Symbol(text: "^", punctuation: [], quoted: 0, word: 0)]
        var punctuation: [String] = []
        var quoted: Int32 = 0
        var word = 1

        for part in parts {
            switch part {
            case Self.quote:
                quoted = quoted == 0 ? 1 : 0
            case "- ", "-":
                punctuation.append("-")
            case Self.space:
                symbols.append(Symbol(text: Self.space, punctuation: punctuation, quoted: quoted, word: word))
                punctuation = []
            case let mark where Self.separators.contains(mark):
                punctuation.append(mark)
            default:
                for phoneme in lookup(part) ?? RussianG2P.phonemes(of: part) {
                    symbols.append(Symbol(text: phoneme, punctuation: [], quoted: quoted, word: word))
                }
                punctuation = []
                word += 1
            }
        }

        symbols.append(Symbol(text: Self.space, punctuation: punctuation, quoted: quoted, word: word))
        symbols.append(Symbol(text: "$", punctuation: [], quoted: 0, word: word))

        return resolve(symbols)
    }

    /// Идём с конца: фонема должна знать, чем кончится фраза, ещё до того как её произнесут —
    /// иначе вопрос звучал бы утверждением до самого знака.
    private func resolve(_ symbols: [Symbol]) -> [VoskFrame] {
        var frames: [VoskFrame] = []
        var lastPunctuation = Self.space
        var lastSentence = Self.space

        for symbol in symbols.reversed() {
            for mark in ["...", ".", "!", "?", "-"] where symbol.punctuation.contains(mark) {
                lastSentence = mark
                break
            }

            if let mark = symbol.punctuation.first { lastPunctuation = mark }

            frames.append(VoskFrame(
                phoneme: identifier(symbol.text),
                punctuation: identifier(symbol.punctuation.first ?? "_"),
                quoted: symbol.quoted,
                lastPunctuation: identifier(lastPunctuation),
                lastSentence: identifier(lastSentence),
                word: symbol.word
            ))
        }

        return frames.reversed()
    }

    private func identifier(_ symbol: String) -> Int32 {
        identifiers[symbol] ?? 0
    }
}
