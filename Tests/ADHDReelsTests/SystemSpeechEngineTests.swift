import AVFoundation
import Foundation
import Testing
@testable import ADHDReelsKit

/// Синтез идёт через системный движок, поэтому набор голосов зависит от устройства.
/// Без русского голоса тест не падает, а не выполняется — это состояние системы,
/// а не дефект кода.
@Suite(
    "Системный синтезатор",
    .enabled(if: !SystemSpeechEngine.voices(for: .russian).isEmpty, "нет русского голоса")
)
struct SystemSpeechEngineTests {

    private static let script = Script(segments: [
        ScriptSegment(kind: .hook, text: Array(repeating: "мысль про случай", count: 20).joined(separator: ", ") + "."),
        ScriptSegment(kind: .body, text: Array(repeating: "потом стало ещё хуже", count: 15).joined(separator: ", ") + "."),
    ])

    @Test("Сценарий на сто двадцать слов даёт WAV и пригодные тайминги", .timeLimit(.minutes(3)))
    func synthesizesScript() async throws {
        #expect(Self.script.wordCount == 120)

        let url = URL.temporaryDirectory.appending(path: "speech-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let take = try await SystemSpeechEngine().synthesize(Self.script, to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate >= 16000)
        #expect(file.length > 0)

        let fileDuration = Double(file.length) / file.fileFormat.sampleRate
        #expect(abs(fileDuration - take.duration) < 0.2)
        #expect((30...90).contains(take.duration), "длительность \(take.duration) с вне разумных границ")

        let words = CaptionTimeline.words(for: take, script: Self.script)
        #expect(!words.isEmpty)
        for (previous, next) in zip(words, words.dropFirst()) {
            #expect(next.start >= previous.start)
            #expect(next.end > next.start)
        }
        #expect((words.last?.end ?? 0) <= take.duration + 0.05)
        #expect((words.last?.end ?? 0) >= take.duration * 0.9)

        // Видно в логе сборки: сработала ли первая ступень лестницы таймингов.
        let measured = Double(Self.script.wordCount) / take.duration
        print("тайминги: \(take.words == nil ? "достроены раскладкой" : "от синтезатора"), скорость \(measured) сл/с")
    }

    @Test("Пустой сценарий отваливается понятной ошибкой")
    func rejectsEmptyScript() async {
        let url = URL.temporaryDirectory.appending(path: "speech-empty.wav")

        await #expect(throws: SystemSpeechEngine.Failure.emptyScript) {
            try await SystemSpeechEngine().synthesize(Script(segments: []), to: url)
        }
    }
}
