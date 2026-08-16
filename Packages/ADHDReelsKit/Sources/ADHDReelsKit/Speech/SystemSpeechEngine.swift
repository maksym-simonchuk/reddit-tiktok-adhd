import AVFoundation
import Foundation

/// Системный синтезатор. Единственный движок, который отдаёт тайминги слов бесплатно:
/// делегат сообщает диапазон ровно тогда, когда произносит его, а мы в этот момент
/// знаем, сколько сэмплов уже записали.
public struct SystemSpeechEngine: SpeechEngine {

    public enum Failure: LocalizedError, Equatable {
        case noVoice(ReelLanguage)
        case emptyScript
        case silence

        public var errorDescription: String? {
            switch self {
            case .noVoice(let language):
                "Нет голоса для языка «\(language.title)». Настройки → Универсальный доступ → Устный контент → Голоса."
            case .emptyScript:
                "Сценарий пуст — озвучивать нечего."
            case .silence:
                "Синтезатор не выдал звук. Попробуйте другой голос."
            }
        }
    }

    /// Голос-премиум звучит заметно живее, поэтому качество важнее алфавитного порядка.
    public static func voices(for language: ReelLanguage) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language.rawValue) }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    private let language: ReelLanguage
    private let voiceIdentifier: String?
    private let rate: Float

    /// `rate` по умолчанию быстрее системного: в ролике обычная диктовка звучит вяло.
    /// Шкала AVSpeech нелинейная — 0.5 это обычная речь, 1.0 примерно вчетверо быстрее,
    /// и полтора раза приходятся на 0.57.
    public init(
        language: ReelLanguage = .russian,
        voiceIdentifier: String? = nil,
        rate: Float = 0.57
    ) {
        self.language = language
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
    }

    public func synthesize(_ script: Script, to url: URL) async throws -> SpeechTake {
        let text = script.plainText
        guard !text.isEmpty else { throw Failure.emptyScript }

        let voices = Self.voices(for: language)
        guard let voice = voices.first(where: { $0.identifier == voiceIdentifier }) ?? voices.first else {
            throw Failure.noVoice(language)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate

        let recording = try await SpeechRecorder().record(utterance, to: url)
        guard recording.duration > 0 else { throw Failure.silence }

        let words = Self.words(from: recording, text: text)
        return SpeechTake(
            audioURL: url,
            duration: recording.duration,
            words: Self.isSane(words, duration: recording.duration, expected: script.wordCount) ? words : nil
        )
    }

    // MARK: - Тайминги

    private static func words(from recording: SpeechRecorder.Recording, text: String) -> [WordTiming] {
        let source = text as NSString

        return recording.marks.indices.compactMap { index in
            let mark = recording.marks[index]
            let word = source
                .substring(with: mark.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { return nil }

            let end = index + 1 < recording.marks.count
                ? recording.marks[index + 1].time
                : recording.duration

            return WordTiming(text: word, start: mark.time, end: max(end, mark.time + 0.01))
        }
    }

    /// Порядок делегата и буферов формально не гарантирован, поэтому результат проверяем.
    /// Провал — не ошибка: тайминги достроит `CaptionTimeline`.
    static func isSane(_ words: [WordTiming], duration: Double, expected: Int) -> Bool {
        guard duration > 0, !words.isEmpty else { return false }
        guard Double(words.count) >= Double(expected) * 0.8 else { return false }

        var previousStart = -1.0
        for word in words {
            guard word.start > previousStart, word.end > word.start, word.end <= duration + 0.05 else { return false }
            previousStart = word.start
        }

        // Все метки в нуле означают, что делегат отстрелялся до записи буферов.
        guard let first = words.first, let last = words.last else { return false }
        return first.start <= duration * 0.25 && last.start >= duration * 0.5
    }
}
