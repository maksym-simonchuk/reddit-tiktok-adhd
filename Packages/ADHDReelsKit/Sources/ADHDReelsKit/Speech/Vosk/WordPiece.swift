import Foundation

/// Токенизатор ruBERT — тот же BertWordPieceTokenizer, каким его создаёт vosk-tts.
/// Регистр не понижаем и диакритику не снимаем: в vosk-tts стоит `lowercase=False`,
/// а вместе с регистром tokenizers снимает и «ё». Понизишь — модель получит другие
/// идентификаторы и построит просодию не для того текста.
struct WordPiece: Sendable {

    struct Token: Equatable, Sendable {
        let text: String
        let id: Int32
    }

    /// Длиннее — слово целиком уходит в `[UNK]`, как в оригинале.
    private static let maxScalars = 100
    private static let continuation = "##"

    private let vocabulary: [String: Int32]
    private let start: Token
    private let end: Token
    private let unknown: Token

    init?(vocabulary: [String: Int32]) {
        guard
            let start = vocabulary["[CLS]"],
            let end = vocabulary["[SEP]"],
            let unknown = vocabulary["[UNK]"]
        else { return nil }

        self.vocabulary = vocabulary
        self.start = Token(text: "[CLS]", id: start)
        self.end = Token(text: "[SEP]", id: end)
        self.unknown = Token(text: "[UNK]", id: unknown)
    }

    /// Словарь — построчный список, идентификатор равен номеру строки.
    init?(contentsOf url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var vocabulary: [String: Int32] = [:]
        vocabulary.reserveCapacity(130_000)
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            vocabulary[String(line)] = Int32(index)
        }

        self.init(vocabulary: vocabulary)
    }

    func encode(_ text: String) -> [Token] {
        var tokens = [start]
        for word in Self.words(in: text) {
            tokens += pieces(of: word)
        }
        tokens.append(end)

        return tokens
    }

    // MARK: - Разбиение

    /// BertPreTokenizer: пробелы выбрасываются, каждый знак препинания — своё слово.
    /// Перед этим чистка текста: управляющие символы прочь, любой пробельный — в обычный.
    private static func words(in text: String) -> [String] {
        var words: [String] = []
        var current = String.UnicodeScalarView()

        func flush() {
            guard !current.isEmpty else { return }
            words.append(String(current))
            current = String.UnicodeScalarView()
        }

        for scalar in text.unicodeScalars {
            if isWhitespace(scalar) {
                flush()
            } else if isDiscarded(scalar) {
                continue
            } else if isPunctuation(scalar) {
                flush()
                words.append(String(scalar))
            } else {
                current.append(scalar)
            }
        }
        flush()

        return words
    }

    private static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
            || scalar.properties.isWhitespace
    }

    private static func isDiscarded(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value == 0 || scalar.value == 0xFFFD
            || scalar.properties.generalCategory == .control
            || scalar.properties.generalCategory == .format
    }

    /// Вся ASCII-пунктуация плюс любой символ категории P. Так же считает и оригинал:
    /// `$`, `+`, `<`, `^` в Unicode не пунктуация, но BERT режет и по ним.
    private static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.isASCII {
            return (33...47).contains(scalar.value) || (58...64).contains(scalar.value)
                || (91...96).contains(scalar.value) || (123...126).contains(scalar.value)
        }

        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }

    // MARK: - WordPiece

    /// Жадно откусываем самый длинный кусок, который есть в словаре; продолжения
    /// помечаются `##`. Не собралось целиком — всё слово становится `[UNK]`.
    private func pieces(of word: String) -> [Token] {
        let scalars = Array(word.unicodeScalars)
        guard scalars.count <= Self.maxScalars else { return [unknown] }

        var pieces: [Token] = []
        var start = 0

        while start < scalars.count {
            var end = scalars.count
            var found: Token?

            while start < end {
                let body = String(String.UnicodeScalarView(scalars[start..<end]))
                let piece = start > 0 ? Self.continuation + body : body
                if let id = vocabulary[piece] {
                    found = Token(text: piece, id: id)
                    break
                }
                end -= 1
            }

            guard let found else { return [unknown] }
            pieces.append(found)
            start = end
        }

        return pieces
    }
}
