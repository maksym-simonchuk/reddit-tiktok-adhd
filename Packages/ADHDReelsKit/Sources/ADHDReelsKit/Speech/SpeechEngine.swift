import Foundation

/// Результат синтеза. `words` заполняет только тот движок, который знает тайминги
/// сам; остальным их достроит `CaptionTimeline`.
public struct SpeechTake: Sendable {

    public let audioURL: URL
    public let duration: Double
    public let words: [WordTiming]?

    public init(audioURL: URL, duration: Double, words: [WordTiming]?) {
        self.audioURL = audioURL
        self.duration = duration
        self.words = words
    }
}

public protocol SpeechEngine: Sendable {
    func synthesize(_ script: Script, to url: URL) async throws -> SpeechTake
}

/// Один идентификатор голоса на оба движка: у Piper это папка модели, у системного —
/// идентификатор `AVSpeechSynthesisVoice`. Хранить два поля незачем — выбор всё равно один.
public enum SpeechEngines {

    public static func make(voiceIdentifier: String?) -> SpeechEngine {
        let neural = PiperSpeechEngine.voices()

        if let voiceIdentifier {
            if let voice = neural.first(where: { $0.id == voiceIdentifier }) {
                return PiperSpeechEngine(voice: voice)
            }
            if SystemSpeechEngine.russianVoices().contains(where: { $0.identifier == voiceIdentifier }) {
                return SystemSpeechEngine(voiceIdentifier: voiceIdentifier)
            }
        }

        // Выбора нет или он протух: нейросеть звучит лучше любого системного голоса.
        guard let best = neural.first else { return SystemSpeechEngine() }
        return PiperSpeechEngine(voice: best)
    }
}
