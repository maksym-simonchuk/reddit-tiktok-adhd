import AVFoundation
import CSherpaOnnx
import Foundation

/// Нейросетевая озвучка: модели Piper (VITS) через sherpa-onnx, целиком на устройстве.
/// Системный синтезатор даёт на телефоне только super-compact Milena — склейку кусков
/// записи восьмидесятых, и ролик с ней звучит как автоответчик.
///
/// Таймингов слов движок не сообщает, поэтому синтезируем по предложению: длину каждого
/// знаем точно, а внутри него слова раскладываются по слогам. Ошибка копится в пределах
/// фразы, а не всего ролика.
public struct PiperSpeechEngine: SpeechEngine {

    public struct Voice: Identifiable, Hashable, Sendable {
        public let id: String
        public let title: String
        let model: URL
        let tokens: URL
    }

    public enum Failure: LocalizedError, Equatable {
        case emptyScript
        case engineUnavailable
        case silence

        public var errorDescription: String? {
            switch self {
            case .emptyScript:
                "Сценарий пуст — озвучивать нечего."
            case .engineUnavailable:
                "Нейросетевой голос не загрузился. Переустановите приложение."
            case .silence:
                "Модель не выдала звук."
            }
        }
    }

    /// Пауза на стыке фраз в секундах.
    static let gap = 0.18

    private let voice: Voice
    private let speed: Float

    public init(voice: Voice, speed: Float = 1) {
        self.voice = voice
        self.speed = speed
    }

    public func synthesize(_ script: Script, to url: URL) async throws -> SpeechTake {
        let sentences = script.segments.flatMap { Sentences.of($0.text) }
        guard !sentences.isEmpty else { throw Failure.emptyScript }

        return try await withCheckedThrowingContinuation { continuation in
            // Модель считает на процессоре десятки секунд. Кооперативному пулу такой
            // блок отдавать нельзя: потоков в нём по числу ядер, и один займём целиком.
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try self.render(sentences, to: url) })
            }
        }
    }

    // MARK: - Синтез

    private func render(_ sentences: [String], to url: URL) throws -> SpeechTake {
        // Движок держит сырые указатели, а Swift-строка живёт только до конца выражения.
        let model = strdup(voice.model.path(percentEncoded: false))
        let tokens = strdup(voice.tokens.path(percentEncoded: false))
        let data = strdup(Self.espeakData?.path(percentEncoded: false) ?? "")
        let provider = strdup("cpu")
        defer { for path in [model, tokens, data, provider] { free(path) } }

        var config = SherpaOnnxOfflineTtsConfig()
        config.model.vits.model = UnsafePointer(model)
        config.model.vits.tokens = UnsafePointer(tokens)
        config.model.vits.data_dir = UnsafePointer(data)
        // Значения из ru_RU-*.onnx.json: с ними голос звучит так, как его обучали.
        config.model.vits.noise_scale = 0.667
        config.model.vits.noise_scale_w = 0.8
        config.model.vits.length_scale = 1
        config.model.num_threads = 2
        config.model.provider = UnsafePointer(provider)
        // Разбиение на фразы своё — движку отдаём по одной.
        config.max_num_sentences = 1

        guard let tts = SherpaOnnxCreateOfflineTts(&config) else { throw Failure.engineUnavailable }
        defer { SherpaOnnxDestroyOfflineTts(tts) }

        let rate = Double(SherpaOnnxOfflineTtsSampleRate(tts))
        guard rate > 0 else { throw Failure.engineUnavailable }

        var samples: [Float] = []
        var words: [WordTiming] = []

        for (index, sentence) in sentences.enumerated() {
            let start = Double(samples.count) / rate

            guard let audio = sentence.withCString({ SherpaOnnxOfflineTtsGenerate(tts, $0, 0, speed) }) else {
                throw Failure.silence
            }
            defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }

            if audio.pointee.n > 0, let chunk = audio.pointee.samples {
                samples.append(contentsOf: UnsafeBufferPointer(start: chunk, count: Int(audio.pointee.n)))
            }

            let end = Double(samples.count) / rate
            words += CaptionTimeline.distribute(sentence, over: end - start).map {
                WordTiming(text: $0.text, start: $0.start + start, end: $0.end + start)
            }

            // Модель не знает, что за этой фразой будет следующая, и обрывает её впритык.
            // Без вдоха на стыке два предложения слышны как одно длинное.
            if index + 1 < sentences.count {
                samples.append(contentsOf: repeatElement(0, count: Int(Self.gap * rate)))
            }
        }

        guard !samples.isEmpty else { throw Failure.silence }
        try Self.write(samples, rate: rate, to: url)

        return SpeechTake(audioURL: url, duration: Double(samples.count) / rate, words: words)
    }

    private static func write(_ samples: [Float], rate: Double, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData
        else { throw Failure.silence }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel[0].update(from: source.baseAddress!, count: samples.count)
        }

        // 16-битный PCM: монтаж читает такой файл без конвертации.
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: rate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        try file.write(from: buffer)
    }

    // MARK: - Модели

    /// Пусто, если модели не положили в бандл: тогда озвучивает системный голос.
    public static func voices() -> [Voice] {
        guard let root, espeakData != nil else { return [] }

        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { $0.lastPathComponent.hasPrefix("vits-piper-") }
            .compactMap(Voice.init(folder:))
            .sorted { $0.id < $1.id }
    }

    static var root: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        return Self.existing(resources.appending(path: "Models"))
    }

    /// Общая на все голоса фонетика espeak-ng: без неё Piper не превратит русский
    /// текст в фонемы и синтезирует тишину.
    static var espeakData: URL? {
        root.flatMap { Self.existing($0.appending(path: "espeak-ng-data")) }
    }

    private static func existing(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }
}

extension PiperSpeechEngine.Voice {

    /// Папка вида `vits-piper-ru_RU-irina-medium`: имя диктора — четвёртый кусок.
    init?(folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        guard let model = files.first(where: { $0.pathExtension == "onnx" }) else { return nil }

        let tokens = folder.appending(path: "tokens.txt")
        guard FileManager.default.fileExists(atPath: tokens.path(percentEncoded: false)) else { return nil }

        let name = folder.lastPathComponent
        self.init(
            id: name,
            title: (name.split(separator: "-").dropFirst(3).first.map(String.init) ?? name).capitalized,
            model: model,
            tokens: tokens
        )
    }
}
