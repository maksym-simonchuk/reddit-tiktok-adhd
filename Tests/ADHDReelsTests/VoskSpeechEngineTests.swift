import AVFoundation
import Foundation
import Testing
@testable import ADHDReelsKit

/// Эталон снят с оригинального vosk-tts на Python: те же фразы прогнаны через
/// `BertWordPieceTokenizer` и `g2p_multistream`. Порт обязан выдавать байт в байт —
/// разъедется хоть один идентификатор, и модель озвучит не тот текст.
private struct Sentence {
    let text: String
    let tokens: [String]
    let ids: [Int32]
    /// Строки входа акустики: фонема, знак, кавычки, последний знак, конец предложения.
    let rows: String

    var prepared: String { text.replacingOccurrences(of: "—", with: "-") }

    var expected: [[Int32]] {
        rows.split(whereSeparator: \.isWhitespace).map {
            $0.split(separator: ",").compactMap { Int32($0) }
        }
    }
}

@Suite("Разбор текста для vosk")
struct VoskTextTests {

    /// Слова, которых в словаре ударений нет: тогда фонемы строятся правилами,
    /// и все гласные безударные.
    @Test("Правила дают те же фонемы, что и оригинальный g2p")
    func rules() {
        let golden = [
            "кракозябра": "k r a0 k o0 zj a0 b r a0",
            "съел": "s j e0 l",
            "юля": "j u0 lj a0",
            "подъезд": "p o0 d j e0 z d",
            "ёжик": "j o0 zh i0 k",
            "привет": "p rj i0 vj e0 t",
            "её": "j e0 j o0",
            "что": "ch t o0",
            "1с": "1 s",
            "тест-драйв": "tj e0 s t d r a0 j v",
        ]

        for (word, phonemes) in golden {
            #expect(RussianG2P.phonemes(of: word).joined(separator: " ") == phonemes, "\(word)")
        }
    }

    @Test("Токенизатор режет по знакам и продолжает слово через ##")
    func wordPiece() throws {
        let words = ["[UNK]", "[CLS]", "[SEP]", "кот", "у", "##сик", ".", "?", "\""]
        let vocabulary = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, Int32($0)) })
        let tokenizer = try #require(WordPiece(vocabulary: vocabulary))

        #expect(tokenizer.encode("кот.").map(\.text) == ["[CLS]", "кот", ".", "[SEP]"])
        #expect(tokenizer.encode("усик").map(\.text) == ["[CLS]", "у", "##сик", "[SEP]"])
        #expect(tokenizer.encode("кот?").map(\.id) == [1, 3, 7, 2])
        // Слово не собирается из кусков — целиком в [UNK], а не по частям.
        #expect(tokenizer.encode("кит").map(\.text) == ["[CLS]", "[UNK]", "[SEP]"])
    }

    @Test("Словарь ударений читается двоичным поиском прямо с диска")
    func dictionary() throws {
        let url = URL.temporaryDirectory.appending(path: "vosk-dict-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        // Порядок — побайтовый: именно так его пишет Scripts/fetch_tts.sh.
        let words = ["ёж": "j o1 zh", "кот": "k o1 t", "яма": "j a1 m a0"]
        let text = words.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
            .map { "\($0)\t\(words[$0]!)" }
            .joined(separator: "\n")
        try (text + "\n").write(to: url, atomically: true, encoding: .utf8)

        let dictionary = try #require(StressDictionary(contentsOf: url))

        for (word, phonemes) in words {
            #expect(dictionary.phonemes(for: word)?.joined(separator: " ") == phonemes, "\(word)")
        }
        #expect(dictionary.phonemes(for: "кракозябра") == nil)
    }
}

@Suite(
    "Озвучка vosk",
    .enabled(if: VoskModel.shared != nil, "нет модели vosk — Scripts/fetch_tts.sh"),
    .serialized
)
struct VoskSpeechEngineTests {

    private static let sentences = [
        Sentence(
            text: "Я двенадцать лет платил чужой долг.",
            tokens: ["[CLS]", "Я", "двенадцать", "лет", "платил", "чужой", "долг", ".", "[SEP]"],
            ids: [101, 186, 16675, 1049, 45916, 14539, 9832, 126, 102],
            rows: """
            1,0,0,10,10 33,0,0,10,10 16,0,0,10,10 3,0,0,10,10 21,0,0,10,10 57,0,0,10,10 23,0,0,10,10
            40,0,0,10,10 16,0,0,10,10 21,0,0,10,10 19,0,0,10,10 15,0,0,10,10 53,0,0,10,10 3,0,0,10,10
            37,0,0,10,10 24,0,0,10,10 52,0,0,10,10 3,0,0,10,10 44,0,0,10,10 36,0,0,10,10 15,0,0,10,10
            53,0,0,10,10 32,0,0,10,10 36,0,0,10,10 3,0,0,10,10 20,0,0,10,10 54,0,0,10,10 61,0,0,10,10
            43,0,0,10,10 33,0,0,10,10 3,0,0,10,10 21,0,0,10,10 43,0,0,10,10 36,0,0,10,10 27,0,0,10,10
            3,10,0,10,10 2,0,0,3,3
            """
        ),
        Sentence(
            text: "Он нашёл её письмо.",
            tokens: ["[CLS]", "Он", "нашёл", "её", "письмо", ".", "[SEP]"],
            ids: [101, 1026, 22582, 1959, 6117, 126, 102],
            rows: """
            1,0,0,10,10 43,0,0,10,10 40,0,0,10,10 3,0,0,10,10 40,0,0,10,10 15,0,0,10,10 50,0,0,10,10
            43,0,0,10,10 36,0,0,10,10 3,0,0,10,10 33,0,0,10,10 23,0,0,10,10 33,0,0,10,10 43,0,0,10,10
            3,0,0,10,10 45,0,0,10,10 31,0,0,10,10 51,0,0,10,10 38,0,0,10,10 43,0,0,10,10 3,10,0,10,10
            2,0,0,3,3
            """
        ),
        Sentence(
            text: "Он — мой отец.",
            tokens: ["[CLS]", "Он", "-", "мой", "отец", ".", "[SEP]"],
            ids: [101, 1026, 133, 2637, 4003, 126, 102],
            rows: """
            1,0,0,9,9 43,0,0,9,9 40,0,0,9,9 3,9,0,9,9 38,0,0,10,10 43,0,0,10,10 33,0,0,10,10
            3,0,0,10,10 42,0,0,10,10 53,0,0,10,10 24,0,0,10,10 19,0,0,10,10 3,10,0,10,10 2,0,0,3,3
            """
        ),
        Sentence(
            text: "Кракозябра? Да!",
            tokens: ["[CLS]", "Кра", "##коз", "##я", "##бра", "?", "Да", "!", "[SEP]"],
            ids: [101, 2091, 92015, 390, 1174, 161, 1041, 177, 102],
            rows: """
            1,0,0,14,14 34,0,0,14,14 46,0,0,14,14 16,0,0,14,14 34,0,0,14,14 42,0,0,14,14 62,0,0,14,14
            16,0,0,14,14 17,0,0,14,14 46,0,0,14,14 15,0,0,14,14 3,14,0,14,14 21,0,0,4,4 15,0,0,4,4
            3,4,0,4,4 2,0,0,3,3
            """
        ),
        Sentence(
            text: "Она сказала: \"нет\" — и ушла...",
            tokens: ["[CLS]", "Она", "сказала", ":", "\"", "нет", "\"", "-", "и", "ушла", ".", ".", ".", "[SEP]"],
            ids: [101, 1425, 2576, 162, 152, 1177, 152, 133, 107, 11522, 126, 126, 126, 102],
            rows: """
            1,0,0,12,9 42,0,0,12,9 40,0,0,12,9 16,0,0,12,9 3,0,0,12,9 48,0,0,12,9 34,0,0,12,9
            15,0,0,12,9 60,0,0,12,9 16,0,0,12,9 36,0,0,12,9 15,0,0,12,9 3,12,0,12,9 41,0,1,9,9
            24,0,1,9,9 52,0,1,9,9 3,9,0,9,9 31,0,0,11,11 3,0,0,11,11 54,0,0,11,11 50,0,0,11,11
            36,0,0,11,11 16,0,0,11,11 3,11,0,11,11 2,0,0,3,3
            """
        ),
    ]

    private static let script = Script(segments: [
        ScriptSegment(kind: .hook, text: "Я двенадцать лет платил чужой долг."),
        ScriptSegment(kind: .body, text: "Каждый месяц треть зарплаты уходила в банк. Никто об этом не знал."),
    ])

    @Test("Модель разложена, дикторов пятьдесят семь")
    func voices() throws {
        let model = try #require(VoskModel.shared)
        let files = FileManager.default

        #expect(files.fileExists(atPath: model.acoustic.path(percentEncoded: false)))
        #expect(files.fileExists(atPath: model.encoder.path(percentEncoded: false)))
        #expect(files.fileExists(atPath: model.dictionary.path(percentEncoded: false)))
        #expect(model.config.audio.sampleRate == 22050)
        #expect(VoskSpeechEngine.voices().count == model.config.speakers.count)
        #expect(VoskSpeechEngine.voices().contains { $0.id == VoskSpeechEngine.defaultVoice })
    }

    @Test("Токены совпадают с эталоном ruBERT")
    func tokens() throws {
        let model = try #require(VoskModel.shared)
        let tokenizer = try #require(WordPiece(contentsOf: model.vocabulary))

        for sentence in Self.sentences {
            let tokens = tokenizer.encode(sentence.prepared)
            #expect(tokens.map(\.text) == sentence.tokens, "\(sentence.text)")
            #expect(tokens.map(\.id) == sentence.ids, "\(sentence.text)")
        }
    }

    @Test("Словарь ударений даёт те же фонемы, что и оригинал")
    func stresses() throws {
        let model = try #require(VoskModel.shared)
        let dictionary = try #require(StressDictionary(contentsOf: model.dictionary))
        let golden = [
            "кракозябра": "k r a1 k o0 zj a1 b r a0",
            "съел": "s j e1 l",
            "юля": "j u0 lj a1",
            "подъезд": "p o0 d j e1 z d",
            "ёжик": "j o1 zh i0 k",
            "привет": "p rj i0 vj e1 t",
            "её": "j e0 j o1",
            "что": "sh t o1",
            "1с": "o0 dj i0 n e1 s",
            "тест-драйв": "tj e1 s t d r a0 j v",
        ]

        for (word, phonemes) in golden {
            #expect(dictionary.phonemes(for: word)?.joined(separator: " ") == phonemes, "\(word)")
        }
    }

    @Test("Потоки пунктуации собираются как в g2p_multistream")
    func frames() throws {
        let model = try #require(VoskModel.shared)
        let dictionary = try #require(StressDictionary(contentsOf: model.dictionary))
        let phonemes = VoskPhonemes(identifiers: model.config.phonemes) { dictionary.phonemes(for: $0) }

        for sentence in Self.sentences {
            let rows = phonemes.frames(of: sentence.prepared).map {
                [$0.phoneme, $0.punctuation, $0.quoted, $0.lastPunctuation, $0.lastSentence]
            }
            #expect(rows == sentence.expected, "\(sentence.text)")
        }
    }

    @Test("Сценарий превращается в звук с таймингами слов", .timeLimit(.minutes(5)))
    func synthesizes() async throws {
        let voice = try #require(VoskSpeechEngine.voices().first)
        let url = URL.temporaryDirectory.appending(path: "vosk-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let take = try await VoskSpeechEngine(voice: voice).synthesize(Self.script, to: url)

        #expect(take.duration > 4)
        #expect(take.words?.count == Self.script.wordCount)

        let asset = AVURLAsset(url: url)
        let seconds = try await CMTimeGetSeconds(asset.load(.duration))
        #expect(abs(seconds - take.duration) < 0.1)
    }

    @Test("Пустой сценарий озвучивать нечего")
    func emptyScript() async throws {
        let voice = try #require(VoskSpeechEngine.voices().first)
        let url = URL.temporaryDirectory.appending(path: "vosk-empty.wav")

        await #expect(throws: VoskSpeechEngine.Failure.emptyScript) {
            try await VoskSpeechEngine(voice: voice).synthesize(Script(segments: []), to: url)
        }
    }
}
