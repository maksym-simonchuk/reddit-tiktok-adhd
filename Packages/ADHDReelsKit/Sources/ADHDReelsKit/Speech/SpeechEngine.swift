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

    public static func make(voiceIdentifier: String?, language: ReelLanguage = .russian) -> SpeechEngine {
        if let voiceIdentifier, let engine = engine(for: voiceIdentifier, language: language) { return engine }

        // Выбора нет или он протух. Русский читает vosk: он знает ударения и ведёт
        // интонацию по смыслу фразы. Других языков он не знает — там системный голос.
        if language == .russian, let voice = defaultNeural() { return VoskSpeechEngine(voice: voice) }

        return SystemSpeechEngine(language: language)
    }

    private static func engine(for identifier: String, language: ReelLanguage) -> SpeechEngine? {
        if language == .russian, let voice = VoskSpeechEngine.voices().first(where: { $0.id == identifier }) {
            return VoskSpeechEngine(voice: voice)
        }
        if SystemSpeechEngine.voices(for: language).contains(where: { $0.identifier == identifier }) {
            return SystemSpeechEngine(language: language, voiceIdentifier: identifier)
        }

        return nil
    }

    private static func defaultNeural() -> VoskSpeechEngine.Voice? {
        let voices = VoskSpeechEngine.voices()
        return voices.first { $0.id == VoskSpeechEngine.defaultVoice } ?? voices.first
    }
}
