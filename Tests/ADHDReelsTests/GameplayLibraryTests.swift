import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Раскладка фонового геймплея")
struct GameplayLibraryTests {

    private static func clip(_ name: String, _ duration: Double) -> GameplayClip {
        GameplayClip(url: URL(filePath: "/gameplay/\(name).mp4"), duration: duration, bytes: 1)
    }

    private static let library = [clip("a", 600), clip("b", 600)]

    @Test("Ролик длиннее сценария даёт один непрерывный кусок")
    func singleSegment() {
        var cursors: [String: Double] = [:]
        let segments = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)

        #expect(segments.count == 1)
        #expect(segments[0].start == 0)
        #expect(segments[0].duration == 45)
        #expect(cursors["a.mp4"] == 45)
    }

    @Test("Следующее видео продолжает с той же точки, а не с начала")
    func cursorAdvances() {
        var cursors: [String: Double] = [:]
        _ = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)
        let second = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)

        #expect(second[0].start == 45)
        #expect(cursors["a.mp4"] == 90)
    }

    @Test("Стартовый ролик чередуется")
    func rotationSwitchesClip() {
        var cursors: [String: Double] = [:]
        let first = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)
        let second = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 1)

        #expect(first[0].url != second[0].url)
    }

    @Test("Кончившийся ролик добирается следующим")
    func spillsToNextClip() {
        var cursors = ["a.mp4": 570.0]
        let segments = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)

        #expect(segments.count == 2)
        #expect(segments[0].duration == 30)
        #expect(segments[1].url.lastPathComponent == "b.mp4")
        #expect(segments[1].start == 0)
        #expect(abs(segments.reduce(0) { $0 + $1.duration } - 45) < 0.001)
    }

    @Test("Хвост короче секунды не монтируется — курсор сбрасывается")
    func restartsOnShortTail() {
        var cursors = ["a.mp4": 599.5]
        let segments = GameplayLibrary.plan(duration: 45, clips: Self.library, cursors: &cursors, startIndex: 0)

        #expect(segments[0].start == 0)
        #expect(segments[0].duration == 45)
    }

    @Test("Один короткий ролик закольцовывается, а не зацикливает раскладку")
    func loopsSingleShortClip() {
        var cursors: [String: Double] = [:]
        let segments = GameplayLibrary.plan(duration: 45, clips: [Self.clip("a", 20)], cursors: &cursors, startIndex: 0)

        #expect(segments.count >= 2)
        #expect(segments.allSatisfy { $0.url.lastPathComponent == "a.mp4" })
    }

    @Test("Сумма кусков равна запрошенной длительности")
    func coversRequestedDuration() {
        var cursors: [String: Double] = [:]
        let segments = GameplayLibrary.plan(duration: 137.5, clips: Self.library, cursors: &cursors, startIndex: 0)

        #expect(abs(segments.reduce(0) { $0 + $1.duration } - 137.5) < 0.001)
    }

    @Test("Без роликов и без длительности раскладка пуста")
    func emptyInputs() {
        var cursors: [String: Double] = [:]

        #expect(GameplayLibrary.plan(duration: 45, clips: [], cursors: &cursors, startIndex: 0).isEmpty)
        #expect(GameplayLibrary.plan(duration: 0, clips: Self.library, cursors: &cursors, startIndex: 0).isEmpty)
    }

    @Test("Импорт не затирает файл с тем же именем")
    func importPicksFreeName() throws {
        let folder = URL.temporaryDirectory.appending(path: "gameplay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        #expect(GameplayLibrary.freeName(for: "clip.mp4", in: folder).lastPathComponent == "clip.mp4")

        try Data().write(to: folder.appending(path: "clip.mp4"))
        #expect(GameplayLibrary.freeName(for: "clip.mp4", in: folder).lastPathComponent == "clip-2.mp4")
    }
}
