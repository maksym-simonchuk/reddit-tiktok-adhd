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
