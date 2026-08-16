import AVFoundation
import UIKit

/// Собирает готовый вертикальный ролик: геймплей в кадре, озвучка в звуке,
/// караоке-субтитры поверх.
public actor VideoRenderer {

    public enum Failure: LocalizedError, Equatable {
        case emptySegments
        case noVideoTrack(String)
        case noAudioTrack
        case export(String)
        case wrongSize(String)

        public var errorDescription: String? {
            switch self {
            case .emptySegments:
                "No gameplay footage to compose."
            case .noVideoTrack(let name):
                "File \"\(name)\" has no video track."
            case .noAudioTrack:
                "The narration has no audio track."
            case .export(let reason):
                "Export failed: \(reason)"
            case .wrongSize(let size):
                "Export produced \(size) instead of 1080x1920."
            }
        }
    }

    public static let renderSize = CGSize(width: 1080, height: 1920)
    private static let timescale: CMTimeScale = 600

    public init() {}

    public func render(
        segments: [GameplaySegment],
        audio: URL,
        groups: [CaptionGroup],
        theme: CaptionTheme = CaptionTheme(),
        to output: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> Double {
        guard !segments.isEmpty else { throw Failure.emptySegments }

        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw Failure.export("не удалось создать дорожки") }

        let voiceDuration = try await insertVoice(from: audio, into: audioTrack)
        let instructions = try await insertGameplay(segments, into: videoTrack, of: composition)

        // Длину задаёт озвучка: лишний геймплей в конце — это тишина под картинкой.
        // Геймплей может оказаться на миллисекунду короче — тогда правит он, иначе
        // в конце останется чёрный кадр без инструкции, и композиция станет невалидной.
        let limit = min(videoTrack.timeRange.end, voiceDuration)
        if composition.duration > limit {
            composition.removeTimeRange(CMTimeRange(start: limit, end: composition.duration))
        }

        // Обрезка идёт по сэмплам, поэтому длину берём фактическую, а не заказанную.
        let total = composition.duration

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = Self.renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = Self.clamp(instructions, to: total)
        videoComposition.animationTool = captions(groups, theme: theme)

        try? FileManager.default.removeItem(at: output)
        try await export(composition, videoComposition, to: output, progress: progress)
        try await verifySize(of: output)

        return total.seconds
    }

    // MARK: - Дорожки

    private func insertVoice(from url: URL, into track: AVMutableCompositionTrack) async throws -> CMTime {
        let asset = AVURLAsset(url: url)
        guard let source = try await asset.loadTracks(withMediaType: .audio).first else { throw Failure.noAudioTrack }

        let duration = try await asset.load(.duration)
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)

        return duration
    }

    private func insertGameplay(
        _ segments: [GameplaySegment],
        into track: AVMutableCompositionTrack,
        of composition: AVMutableComposition
    ) async throws -> [AVMutableVideoCompositionInstruction] {
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero

        for segment in segments {
            let asset = AVURLAsset(url: segment.url)
            guard let source = try await asset.loadTracks(withMediaType: .video).first else {
                throw Failure.noVideoTrack(segment.url.lastPathComponent)
            }

            let range = CMTimeRange(
                start: CMTime(seconds: segment.start, preferredTimescale: Self.timescale),
                duration: CMTime(seconds: segment.duration, preferredTimescale: Self.timescale)
            )
            try track.insertTimeRange(range, of: source, at: cursor)

            let (naturalSize, preferred) = try await source.load(.naturalSize, .preferredTransform)
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layer.setTransform(Self.transform(for: naturalSize, preferred: preferred, target: Self.renderSize), at: cursor)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: range.duration)
            instruction.layerInstructions = [layer]
            instructions.append(instruction)

            cursor = cursor + range.duration
        }

        return instructions
    }

    /// Вписывает кадр источника в вертикаль по короткой стороне и центрирует.
    /// Свои ролики уже 1080x1920, но импортированные пользователем — какие угодно.
    static func transform(for naturalSize: CGSize, preferred: CGAffineTransform, target: CGSize) -> CGAffineTransform {
        let oriented = CGRect(origin: .zero, size: naturalSize).applying(preferred)
        guard oriented.width > 0, oriented.height > 0 else { return preferred }

        let scale = max(target.width / oriented.width, target.height / oriented.height)

        return preferred
            .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (target.width - oriented.width * scale) / 2,
                y: (target.height - oriented.height * scale) / 2
            ))
    }

    /// Инструкции обязаны покрывать таймлайн без дыр и без хвоста за его концом,
    /// иначе экспорт падает на проверке видеокомпозиции (-11841). Последняя тянется
    /// до конца ролика: даже миллисекунда без инструкции считается дырой.
    static func clamp(
        _ instructions: [AVMutableVideoCompositionInstruction],
        to total: CMTime
    ) -> [AVMutableVideoCompositionInstruction] {
        let kept: [AVMutableVideoCompositionInstruction] = instructions.compactMap { instruction in
            guard instruction.timeRange.start < total else { return nil }

            let end = min(instruction.timeRange.end, total)
            instruction.timeRange = CMTimeRange(start: instruction.timeRange.start, end: end)
            return instruction
        }

        if let last = kept.last, last.timeRange.end < total {
            last.timeRange = CMTimeRange(start: last.timeRange.start, end: total)
        }

        return kept
    }

    // MARK: - Субтитры

    private func captions(_ groups: [CaptionGroup], theme: CaptionTheme) -> AVVideoCompositionCoreAnimationTool? {
        guard !groups.isEmpty else { return nil }

        // Экспорт с CoreAnimationTool на симуляторе падает внутри системы:
        // FigCoreAnimationRendererCopyPixelBufferAtTime → CA::OGL → IOSurfaceCreate
        // → xpc_api_misuse, известный баг симулятора. Здесь ролик собирается без
        // субтитров; на устройстве рендерит Metal — там субтитры на месте.
        #if targetEnvironment(simulator)
        return nil
        #else
        let frame = CGRect(origin: .zero, size: Self.renderSize)

        let videoLayer = CALayer()
        videoLayer.frame = frame

        let parent = CALayer()
        parent.frame = frame
        parent.addSublayer(videoLayer)
        parent.addSublayer(CaptionLayerBuilder.layer(groups: groups, size: Self.renderSize, theme: theme))

        return AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
        #endif
    }

    // MARK: - Экспорт

    private func export(
        _ composition: AVComposition,
        _ videoComposition: AVVideoComposition,
        to output: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Failure.export("нет пресета для экспорта")
        }

        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        // Прогресс читается параллельно с экспортом, а сессия не Sendable. Читать
        // её состояние из другой задачи безопасно — это и есть штатный сценарий
        // states(updateInterval:), просто компилятор о нём не знает.
        let handle = Handle(session: session)
        let monitor = Task {
            for await state in handle.session.states(updateInterval: 0.25) {
                if case .exporting(let fraction) = state { progress?(fraction.fractionCompleted) }
            }
        }
        defer { monitor.cancel() }

        do {
            try await session.export(to: output, as: .mp4)
        } catch is CancellationError {
            session.cancelExport()
            throw CancellationError()
        } catch {
            throw Failure.export(error.localizedDescription)
        }
    }

    private struct Handle: @unchecked Sendable {
        let session: AVAssetExportSession
    }

    /// Пресет договаривается о размере сам, поэтому результат проверяем, а не верим.
    private func verifySize(of output: URL) async throws {
        guard let track = try await AVURLAsset(url: output).loadTracks(withMediaType: .video).first else {
            throw Failure.noVideoTrack(output.lastPathComponent)
        }

        let size = try await track.load(.naturalSize)
        guard size == Self.renderSize else {
            throw Failure.wrongSize("\(Int(size.width))x\(Int(size.height))")
        }
    }
}
