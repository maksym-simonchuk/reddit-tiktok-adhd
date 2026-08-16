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

/// Один идентификатор голоса на оба движка: у vosk это диктор модели, у системного —
/// идентификатор `AVSpeechSynthesisVoice`. Хранить два поля незачем: выбор всё равно один.
public enum SpeechEngines {

    /// Полный выбор движка по настройкам: облако ElevenLabs, когда оно включено
    /// и ключ на месте, иначе локальные движки. Ключ пропал — молча падаем на
    /// локальный голос: ролик важнее строгости.
    public static func make(settings: ReelSettings) -> SpeechEngine {
        if settings.useElevenLabs, let key = ElevenLabsSpeechEngine.storedKey() {
            return ElevenLabsSpeechEngine(
                apiKey: key,
                voiceID: settings.elevenLabsVoiceID ?? ElevenLabsSpeechEngine.defaultVoice,
                speed: settings.voiceSpeed
            )
        }

        return make(
            voiceIdentifier: settings.voiceIdentifier,
            language: settings.language,
            speed: settings.voiceSpeed
        )
    }

    public static func make(
        voiceIdentifier: String?,
        language: ReelLanguage = .russian,
        speed: Double = 1
    ) -> SpeechEngine {
        if let voiceIdentifier, let engine = engine(for: voiceIdentifier, language: language, speed: speed) {
            return engine
        }

        // Выбора нет или он протух. Русский читает vosk: он знает ударения и ведёт
        // интонацию по смыслу фразы. Других языков он не знает — там системный голос.
        if language == .russian, let voice = defaultNeural() {
            return VoskSpeechEngine(voice: voice, speed: Float(speed))
        }

        return SystemSpeechEngine(language: language, rate: SystemSpeechEngine.rate(for: language, speed: speed))
    }

    private static func engine(for identifier: String, language: ReelLanguage, speed: Double) -> SpeechEngine? {
        if language == .russian, let voice = VoskSpeechEngine.voices().first(where: { $0.id == identifier }) {
            return VoskSpeechEngine(voice: voice, speed: Float(speed))
        }
        if SystemSpeechEngine.voices(for: language).contains(where: { $0.identifier == identifier }) {
            return SystemSpeechEngine(
                language: language,
                voiceIdentifier: identifier,
                rate: SystemSpeechEngine.rate(for: language, speed: speed)
            )
        }

        return nil
    }

    private static func defaultNeural() -> VoskSpeechEngine.Voice? {
        let voices = VoskSpeechEngine.voices()
        return voices.first { $0.id == VoskSpeechEngine.defaultVoice } ?? voices.first
    }
}
