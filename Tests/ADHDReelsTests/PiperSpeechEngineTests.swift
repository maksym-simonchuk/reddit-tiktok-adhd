import AVFoundation
import Foundation
import Testing
@testable import ADHDReelsKit

@Suite(
    "Нейросетевая озвучка",
    .enabled(if: !PiperSpeechEngine.voices().isEmpty, "нет моделей Piper — Scripts/fetch_tts.sh"),
    .serialized
)
struct PiperSpeechEngineTests {

    private static let script = Script(segments: [
        ScriptSegment(kind: .hook, text: "Я двенадцать лет платил чужой долг."),
        ScriptSegment(kind: .body, text: "Каждый месяц треть зарплаты уходила в банк. Никто об этом не знал."),
    ])

    @Test("Модели лежат рядом с фонетикой espeak")
    func voices() throws {
        let voices = PiperSpeechEngine.voices()

        #expect(voices.contains { $0.id.hasPrefix("vits-piper-ru_RU-") })
        #expect(PiperSpeechEngine.espeakData != nil)
    }

    @Test("Сценарий превращается в звук с таймингами слов", .timeLimit(.minutes(2)))
    func synthesizes() async throws {
        let voice = try #require(PiperSpeechEngine.voices().first)
        let url = URL.temporaryDirectory.appending(path: "piper-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let take = try await PiperSpeechEngine(voice: voice).synthesize(Self.script, to: url)

        // Восемнадцать слов человеческой речью — это секунды, а не миллисекунды.
        #expect(take.duration > 4)
        #expect(take.words?.count == Self.script.wordCount)

        let asset = AVURLAsset(url: url)
        let seconds = try await CMTimeGetSeconds(asset.load(.duration))
        #expect(abs(seconds - take.duration) < 0.1)
    }

    @Test("Пустой сценарий озвучивать нечего")
    func emptyScript() async throws {
        let voice = try #require(PiperSpeechEngine.voices().first)
        let url = URL.temporaryDirectory.appending(path: "piper-empty.wav")

        await #expect(throws: PiperSpeechEngine.Failure.emptyScript) {
            try await PiperSpeechEngine(voice: voice).synthesize(Script(segments: []), to: url)
        }
    }
}
