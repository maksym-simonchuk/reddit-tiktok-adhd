import CVoskTTS
import Foundation

/// Озвучка моделью vosk-tts: VITS плюс ruBERT, который читает фразу целиком и говорит
/// акустике, где в ней смысловой центр — от этого интонация у разных фраз разная,
/// а не одна на всё.
///
/// Ударения берутся из словаря на два миллиона форм, а не угадываются правилами.
public struct VoskSpeechEngine: SpeechEngine {

    public struct Voice: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        let speaker: Int64
    }

    public enum Failure: LocalizedError, Equatable {
        case emptyScript
        case engineUnavailable
        case silence

        public var errorDescription: String? {
            switch self {
            case .emptyScript:
                "The script is empty — nothing to narrate."
            case .engineUnavailable:
                "The neural voice failed to load. Reinstall the app."
            case .silence:
                "The model produced no audio."
            }
        }
    }

    /// Голос по умолчанию, пока человек не выбрал свой.
    public static let defaultVoice = "vosk-kyznetsov_vsevolod"

    /// Считает процессор: производительных ядер на телефоне столько же.
    private static let threads: Int32 = 4

    private let voice: Voice
    private let speed: Float

    public init(voice: Voice, speed: Float = 1) {
        self.voice = voice
        self.speed = speed
    }

    public func synthesize(_ script: Script, to url: URL) async throws -> SpeechTake {
        let phrases = SpeechDelivery.phrases(of: script)
        guard !phrases.isEmpty else { throw Failure.emptyScript }

        return try await withCheckedThrowingContinuation { continuation in
            // Модель считает на процессоре десятки секунд. Кооперативному пулу такой
            // блок отдавать нельзя: потоков в нём по числу ядер, и один займём целиком.
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try self.render(phrases, to: url) })
            }
        }
    }

    // MARK: - Синтез

    private func render(_ phrases: [SpeechDelivery.Phrase], to url: URL) throws -> SpeechTake {
        guard
            let model = VoskModel.shared,
            let tokenizer = WordPiece(contentsOf: model.vocabulary),
            let dictionary = StressDictionary(contentsOf: model.dictionary)
        else { throw Failure.engineUnavailable }

        let encoder = vosk_session_create(model.encoder.path(percentEncoded: false), Self.threads)
        defer { vosk_session_destroy(encoder) }
        let acoustic = vosk_session_create(model.acoustic.path(percentEncoded: false), Self.threads)
        defer { vosk_session_destroy(acoustic) }

        guard let encoder, let acoustic else { throw Failure.engineUnavailable }

        let session = Session(
            tokenizer: tokenizer,
            phonemes: VoskPhonemes(identifiers: model.config.phonemes) { dictionary.phonemes(for: $0) },
            encoder: encoder,
            acoustic: acoustic
        )

        let rate = Double(model.config.audio.sampleRate)
        var samples: [Float] = []
        var words: [WordTiming] = []

        for (index, phrase) in phrases.enumerated() {
            let start = Double(samples.count) / rate
            let pace = model.config.inference.speechRate * speed * SpeechDelivery.pace
                * SpeechDelivery.tempo(of: phrase.kind) * SpeechDelivery.jitter(of: phrase)
            let expression = SpeechDelivery.expression(of: phrase.kind)
            // Порядок жёсткий, модель читает вектор по местам: шум в потоке, обратный
            // темп, разброс длительностей.
            let scales = [
                model.config.inference.noiseLevel * expression.noise,
                1 / pace,
                model.config.inference.durationNoiseLevel * expression.duration,
            ]
            samples += try session.samples(of: phrase.text, speaker: voice.speaker, scales: scales)

            let end = Double(samples.count) / rate
            words += CaptionTimeline.distribute(phrase.text, over: end - start).map {
                WordTiming(text: $0.text, start: $0.start + start, end: $0.end + start)
            }

            // Модель не знает, что за этой фразой будет следующая, и обрывает её впритык.
            let next = index + 1 < phrases.count ? phrases[index + 1] : nil
            let pause = SpeechDelivery.pause(after: phrase, before: next)
            samples += repeatElement(0, count: Int(pause * rate))
        }

        guard !samples.isEmpty else { throw Failure.silence }
        try SpeechDelivery.write(AudioMaster.polish(samples, rate: rate), rate: rate, to: url)

        return SpeechTake(audioURL: url, duration: Double(samples.count) / rate, words: words)
    }

    // MARK: - Голоса

    /// Пятьдесят семь дикторов одной модели: веса общие, различается только вектор
    /// говорящего. Имена — как в config.json, придумывать им русские подписи не за что.
    public static func voices() -> [Voice] {
        guard let model = VoskModel.shared else { return [] }

        return model.config.speakers
            .map { Voice(id: "vosk-\($0.key)", title: title(of: $0.key), speaker: $0.value) }
            .sorted { $0.title < $1.title }
    }

    private static func title(of name: String) -> String {
        name.split(separator: "_").map(\.capitalized).joined(separator: " ")
    }
}

/// Загруженная модель со всем, что нужно одной фразе. Живёт ровно на время сборки
/// ролика: два графа занимают под девятьсот мегабайт, и держать их дольше незачем.
private struct Session {

    let tokenizer: WordPiece
    let phonemes: VoskPhonemes
    let encoder: OpaquePointer
    let acoustic: OpaquePointer

    func samples(of text: String, speaker: Int64, scales: [Float]) throws -> [Float] {
        // Тире модель не знает: в vosk-tts его заменяют дефисом до всякого разбора.
        let prepared = text.replacingOccurrences(of: "—", with: "-")
        let tokens = tokenizer.encode(prepared)
        let frames = phonemes.frames(of: prepared)

        var identifiers = tokens.map { Int64($0.id) }
        var width: Int32 = 0
        guard
            let embeddings = vosk_bert_run(encoder, &identifiers, Int32(identifiers.count), &width),
            width > 0
        else { throw VoskSpeechEngine.Failure.silence }
        defer { free(embeddings) }

        // Просодию берём по словам: продолжения слова (`##…`) и знаки препинания
        // выкидываем, иначе фонемы разъедутся со своими эмбеддингами.
        let rows = tokens.indices.filter { !tokens[$0].text.hasPrefix("#") && !Self.isPunctuation(tokens[$0].text) }
        guard !rows.isEmpty, !frames.isEmpty else { throw VoskSpeechEngine.Failure.silence }

        let count = frames.count
        let stride = Int(width)
        var input = [Int64](repeating: 0, count: 5 * count)
        var bert = [Float](repeating: 0, count: stride * count)

        for (position, frame) in frames.enumerated() {
            input[position] = Int64(frame.phoneme)
            input[count + position] = Int64(frame.punctuation)
            input[2 * count + position] = Int64(frame.quoted)
            input[3 * count + position] = Int64(frame.lastPunctuation)
            input[4 * count + position] = Int64(frame.lastSentence)

            // Слов в разборе и слов у токенизатора обычно поровну, но текст может
            // разойтись — тогда лучше повторить последний эмбеддинг, чем упасть.
            let row = rows[min(frame.word, rows.count - 1)]
            for dimension in 0..<stride {
                bert[dimension * count + position] = embeddings[row * stride + dimension]
            }
        }

        var scales = scales
        var produced: Int32 = 0
        guard
            let audio = vosk_tts_run(acoustic, &input, Int32(count), &bert, width, &scales, speaker, &produced),
            produced > 0
        else { throw VoskSpeechEngine.Failure.silence }
        defer { free(audio) }

        return Array(UnsafeBufferPointer(start: audio, count: Int(produced)))
    }

    /// Знаки препинания приезжают из токенизатора отдельными токенами, а в разборе
    /// фразы они словами не считаются — иначе нумерация слов разъедется.
    private static func isPunctuation(_ token: String) -> Bool {
        guard let first = token.first else { return false }
        return "-,.?!;:\"".contains(first)
    }
}
