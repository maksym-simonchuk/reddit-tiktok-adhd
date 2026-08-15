import AVFoundation
import Foundation
import Testing
import UIKit
@testable import ADHDReelsKit

/// Условие живёт снаружи набора: ссылка на сам набор в его же атрибуте — циклическая.
enum RenderLiveReadiness {

    static var isReady: Bool {
        guard !SystemSpeechEngine.russianVoices().isEmpty else { return false }

        let folder = URL.documentsDirectory.appending(path: GameplayLibrary.folderName)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return files.contains { $0.hasSuffix(".mp4") }
    }
}

/// Сквозная проверка монтажа: сценарий → озвучка → геймплей → mp4.
/// Требует и русского голоса, и хотя бы одного файла в `Documents/Gameplay`,
/// поэтому без них пропускается: это состояние машины, а не дефект кода.
@Suite(
    "Монтаж целиком",
    .enabled(if: RenderLiveReadiness.isReady, "нет русского голоса или геймплея")
)
struct RenderLiveTests {

    private static let script = Script(segments: [
        ScriptSegment(kind: .hook, text: "Я двенадцать лет молчал об этом."),
        ScriptSegment(kind: .body, text: "Вчера всё вышло наружу за одним ужином, и назад уже не отыграть."),
    ])

    @Test("Собирается mp4 1080 на 1920 длиной с озвучку", .timeLimit(.minutes(5)))
    func rendersReel() async throws {
        try await Self.render(captions: false)
    }

    // Симулятор роняет QuartzCore на AVVideoCompositionCoreAnimationTool: IOSurface
    // для слоёв там не создаётся. Субтитры в готовом ролике проверяются на устройстве.
    #if !targetEnvironment(simulator)
    @Test("Субтитры доезжают до готового ролика", .timeLimit(.minutes(5)))
    func rendersReelWithCaptions() async throws {
        try await Self.render(captions: true)
    }
    #endif

    private static func render(captions: Bool) async throws {
        let folder = URL.temporaryDirectory.appending(path: "render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let audio = folder.appending(path: "voice.wav")
        let take = try await SystemSpeechEngine().synthesize(script, to: audio)
        #expect(take.duration > 3)

        let groups = CaptionGrouper.groups(from: CaptionTimeline.words(for: take, script: script))
        #expect(!groups.isEmpty)

        let library = GameplayLibrary()
        let clips = try await library.refresh()
        #expect(!clips.isEmpty)

        let segments = try await library.segments(for: take.duration)
        let planned = segments.reduce(0) { $0 + $1.duration }
        #expect(abs(planned - take.duration) < 0.1, "геймплей не покрыл озвучку")

        let output = folder.appending(path: "reel.mp4")
        let duration = try await VideoRenderer().render(
            segments: segments,
            audio: audio,
            groups: captions ? groups : [],
            to: output
        )

        #expect(abs(duration - take.duration) < 0.2)
        #expect(FileManager.default.fileExists(atPath: output.path(percentEncoded: false)))

        let asset = AVURLAsset(url: output)
        let video = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let sound = try await asset.loadTracks(withMediaType: .audio).first

        #expect(try await video.load(.naturalSize) == VideoRenderer.renderSize)
        #expect(sound != nil, "в готовом ролике нет звука")
        #expect(abs(CMTimeGetSeconds(try await asset.load(.duration)) - take.duration) < 0.3)

        // Кадр забираем наружу: субтитры проверяются глазами, а не утверждением.
        let frame = await Thumbnailer.image(for: output, height: 1920)
        #expect(frame != nil)
        if let data = frame?.pngData() {
            try? data.write(to: URL.documentsDirectory.appending(path: "render-check.png"))
        }
    }
}
