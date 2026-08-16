import AVFoundation
import Foundation

/// Подача: на какие куски резать сценарий, с каким темпом читать каждый и сколько
/// молчать на стыке. Внутрь фразы модель не пускает — ни темпом, ни паузой там
/// не поуправляешь, так что решать можно только здесь.
enum SpeechDelivery {

    enum Failure: LocalizedError, Equatable {
        case encoding

        var errorDescription: String? {
            "Не удалось записать звуковую дорожку."
        }
    }

    /// Фраза со своим темпом. Движок читает по одной: так известна длина каждой,
    /// и ошибка тайминга не копится на весь ролик.
    struct Phrase: Sendable {
        let kind: ScriptSegment.Kind
        let text: String
    }

    static func phrases(of script: Script) -> [Phrase] {
        script.segments.flatMap { segment in
            Sentences.of(segment.text).map { Phrase(kind: segment.kind, text: $0) }
        }
    }

    /// Общий темп читки. Дикторская скорость модели рассчитана на аудиокнигу, а в
    /// вертикальном ролике так звучит вяло: зритель уходит раньше, чем дослушает
    /// завязку. Полтора раза — граница, за которой русский синтез начинает глотать
    /// окончания. Тем же множителем ускоряется оценка длительности в `Script`.
    static let pace: Float = 1.5

    /// Множитель к скорости. Хук читаем медленнее: на первых двух секундах зритель
    /// решает, смотреть дальше или листать, и проглоченная скороговоркой завязка
    /// стоит ролика. Вопрос в конце — тоже: на скороговорке он звучит припиской,
    /// а отвечают на него, только если он прозвучал как вопрос.
    static func tempo(of kind: ScriptSegment.Kind) -> Float {
        switch kind {
        case .hook, .outro: 0.92
        case .body: 1
        }
    }

    /// Разброс, с которым модель рисует интонацию (`noise`) и длительности звуков
    /// (`duration`), множителем к обученным значениям. Ровные длительности — главная
    /// примета синтеза: живой человек тянет одни слоги и проглатывает другие.
    ///
    /// Тембр трогаем осторожнее: на большом `noise` голос начинает дрожать. Больше
    /// всего свободы у хука — он короткий, и там слышно подачу, а не артефакты.
    static func expression(of kind: ScriptSegment.Kind) -> (noise: Float, duration: Float) {
        switch kind {
        case .hook, .outro: (1.1, 1.35)
        case .body: (1, 1.15)
        }
    }

    /// Разброс темпа на конкретной фразе. Два предложения подряд с одной скоростью —
    /// это и есть та самая машинная читка; человек то торопится, то тянет.
    ///
    /// Считается от текста, а не случайно: пересборка того же треда даёт ту же дорожку,
    /// иначе не сверить, что поменяли.
    static func jitter(of phrase: Phrase) -> Float {
        let sum = phrase.text.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return 0.94 + Float(sum % 13) / 100
    }

    /// Тишина после фразы. После хука держим дольше всего — это та пауза, в которую
    /// зритель успевает задать себе вопрос. На вопросе и восклицании голос уходит
    /// вверх, и без паузы следующая фраза срезает интонацию на взлёте.
    /// Перед вопросом зрителю пауза такая же, как после хука: без неё он слипается
    /// с последней фразой истории и слышится её частью, а не обращением к смотрящему.
    static func pause(after phrase: Phrase, before next: Phrase?) -> Double {
        guard let next else { return 0 }

        let silence: Double
        if phrase.kind == .hook || next.kind == .outro {
            silence = 0.4
        } else {
            let last = phrase.text.last
            silence = last == "?" || last == "!" ? 0.3 : 0.18
        }

        // Паузы едут вместе с речью: на ускоренной читке прежние промежутки звучат
        // провалами, а от полутора раз остаётся один и три.
        return silence / Double(pace)
    }

    static func write(_ samples: [Float], rate: Double, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard
            let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData
        else { throw Failure.encoding }

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
}
