import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Тайминги и группировка субтитров")
struct CaptionTests {

    // MARK: - Раскладка по длительности

    @Test("Запасная раскладка покрывает всю длительность без разрывов")
    func distributionCoversDuration() {
        let words = CaptionTimeline.distribute("привет как дела сегодня", over: 4)

        #expect(words.count == 4)
        #expect(words[0].start == 0)
        #expect(abs((words.last?.end ?? 0) - 4) < 0.001)

        for (previous, next) in zip(words, words.dropFirst()) {
            #expect(abs(next.start - previous.end) < 0.001)
            #expect(next.start > previous.start)
        }
    }

    @Test("Длинное слово занимает больше времени, чем короткое")
    func distributionWeightsBySyllables() {
        let words = CaptionTimeline.distribute("я неприкосновенность", over: 10)

        #expect(words.count == 2)
        #expect(words[1].duration > words[0].duration * 3)
    }

    @Test("Пустой текст и нулевая длительность не роняют раскладку")
    func distributionEdgeCases() {
        #expect(CaptionTimeline.distribute("", over: 10).isEmpty)
        #expect(CaptionTimeline.distribute("текст", over: 0).isEmpty)
    }

    @Test("Готовые тайминги движка используются как есть")
    func timelinePrefersEngineTimings() {
        let engine = [WordTiming(text: "раз", start: 0, end: 1)]
        let take = SpeechTake(audioURL: URL(filePath: "/dev/null"), duration: 2, words: engine)

        #expect(CaptionTimeline.words(for: take, script: Script(segments: [.init(kind: .hook, text: "раз два")])) == engine)
    }

    @Test("Без таймингов движка слова берутся из сценария")
    func timelineFallsBackToScript() {
        let take = SpeechTake(audioURL: URL(filePath: "/dev/null"), duration: 2, words: nil)
        let script = Script(segments: [ScriptSegment(kind: .hook, text: "раз два")])

        #expect(CaptionTimeline.words(for: take, script: script).map(\.text) == ["раз", "два"])
    }

    // MARK: - Проверка таймингов синтезатора

    @Test("Нормальные тайминги проходят проверку")
    func sanityAcceptsGoodTimings() {
        let words = (0..<10).map { WordTiming(text: "с", start: Double($0), end: Double($0) + 1) }

        #expect(SystemSpeechEngine.isSane(words, duration: 10, expected: 10))
    }

    @Test("Метки, слипшиеся в нуле, отбраковываются")
    func sanityRejectsCollapsedTimings() {
        let words = (0..<10).map { _ in WordTiming(text: "с", start: 0, end: 0.01) }

        #expect(!SystemSpeechEngine.isSane(words, duration: 10, expected: 10))
    }

    @Test("Потеря половины слов отбраковывается")
    func sanityRejectsMissingWords() {
        let words = (0..<4).map { WordTiming(text: "с", start: Double($0), end: Double($0) + 1) }

        #expect(!SystemSpeechEngine.isSane(words, duration: 10, expected: 10))
    }

    @Test("Тайминги за пределами аудио отбраковываются")
    func sanityRejectsOverrun() {
        let words = [
            WordTiming(text: "а", start: 0, end: 1),
            WordTiming(text: "б", start: 1, end: 99),
        ]

        #expect(!SystemSpeechEngine.isSane(words, duration: 10, expected: 2))
    }

    // MARK: - Группировка

    @Test("Группа не длиннее трёх слов")
    func groupsSplitByWordCount() {
        let words = (0..<7).map { WordTiming(text: "ок", start: Double($0) * 0.2, end: Double($0) * 0.2 + 0.2) }
        let groups = CaptionGrouper.groups(from: words)

        #expect(groups.map(\.words.count) == [3, 3, 1])
    }

    @Test("Длинные слова разъезжаются по группам раньше лимита в три слова")
    func groupsSplitByLength() {
        let words = ["неприкосновенность", "ответственность"].enumerated().map {
            WordTiming(text: $1, start: Double($0) * 0.2, end: Double($0) * 0.2 + 0.2)
        }

        #expect(CaptionGrouper.groups(from: words).count == 2)
    }

    @Test("Пауза рвёт группу")
    func groupsSplitByPause() {
        let words = [
            WordTiming(text: "да", start: 0, end: 0.3),
            WordTiming(text: "нет", start: 1.5, end: 1.8),
        ]

        #expect(CaptionGrouper.groups(from: words).count == 2)
    }

    @Test("Группы идут по порядку и покрывают все слова")
    func groupsKeepEveryWord() {
        let words = (0..<11).map { WordTiming(text: "сл\($0)", start: Double($0) * 0.2, end: Double($0) * 0.2 + 0.2) }
        let groups = CaptionGrouper.groups(from: words)

        #expect(groups.flatMap(\.words) == words)
        #expect(groups.first?.start == 0)
    }

    @Test("Пустой список слов даёт пустую разбивку")
    func groupsEmpty() {
        #expect(CaptionGrouper.groups(from: []).isEmpty)
    }
}
