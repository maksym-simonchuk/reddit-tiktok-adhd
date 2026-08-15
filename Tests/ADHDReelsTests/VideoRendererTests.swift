import AVFoundation
import Testing
@testable import ADHDReelsKit

@Suite("Геометрия и таймлайн монтажа")
struct VideoRendererTests {

    private static let target = CGSize(width: 1080, height: 1920)

    private static func fit(_ size: CGSize, _ preferred: CGAffineTransform = .identity) -> CGRect {
        let transform = VideoRenderer.transform(for: size, preferred: preferred, target: target)
        return CGRect(origin: .zero, size: size).applying(transform)
    }

    @Test("Вертикальный кадр 1080x1920 ложится один в один")
    func nativeVerticalIsUntouched() {
        let result = Self.fit(Self.target)

        #expect(abs(result.minX) < 0.001)
        #expect(abs(result.minY) < 0.001)
        #expect(abs(result.width - 1080) < 0.001)
        #expect(abs(result.height - 1920) < 0.001)
    }

    @Test("Вертикальный 4K уменьшается ровно вдвое")
    func verticalFourKScalesDown() {
        let result = Self.fit(CGSize(width: 2160, height: 3840))

        #expect(abs(result.width - 1080) < 0.001)
        #expect(abs(result.height - 1920) < 0.001)
    }

    @Test("Горизонтальный кадр заполняет вертикаль и обрезается по бокам симметрично")
    func landscapeFillsAndCentres() {
        let result = Self.fit(CGSize(width: 1920, height: 1080))

        #expect(abs(result.height - 1920) < 0.001)
        #expect(result.width > 1080)
        #expect(abs(result.minX + (result.width - 1080) / 2) < 0.001)
        #expect(abs(result.minY) < 0.001)
    }

    @Test("Кадр, повёрнутый на 90 градусов, встаёт вертикально без чёрных полей")
    func rotatedSourceIsUpright() {
        let rotated = CGAffineTransform(rotationAngle: .pi / 2)
        let result = Self.fit(CGSize(width: 1920, height: 1080), rotated)

        #expect(abs(result.width - 1080) < 0.001)
        #expect(abs(result.height - 1920) < 0.001)
        #expect(abs(result.minX) < 0.001)
        #expect(abs(result.minY) < 0.001)
    }

    @Test("Нулевой размер не роняет расчёт")
    func zeroSizeIsSafe() {
        #expect(VideoRenderer.transform(for: .zero, preferred: .identity, target: Self.target) == .identity)
    }

    // MARK: - Инструкции

    private static func instruction(from start: Double, to end: Double) -> AVMutableVideoCompositionInstruction {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )
        return instruction
    }

    @Test("Инструкции за концом ролика выбрасываются, пограничная обрезается")
    func clampsInstructions() {
        let clamped = VideoRenderer.clamp(
            [Self.instruction(from: 0, to: 20), Self.instruction(from: 20, to: 40), Self.instruction(from: 40, to: 60)],
            to: CMTime(seconds: 30, preferredTimescale: 600)
        )

        #expect(clamped.count == 2)
        #expect(clamped[1].timeRange.end.seconds == 30)
    }

    @Test("Последняя инструкция дотягивается до конца ролика")
    func stretchesLastInstruction() {
        let clamped = VideoRenderer.clamp(
            [Self.instruction(from: 0, to: 20), Self.instruction(from: 20, to: 44.999)],
            to: CMTime(seconds: 45, preferredTimescale: 600)
        )

        #expect(clamped.count == 2)
        #expect(clamped.last?.timeRange.end.seconds == 45)
    }

    @Test("Инструкции покрывают таймлайн без дыр")
    func instructionsCoverTimeline() {
        let clamped = VideoRenderer.clamp(
            [Self.instruction(from: 0, to: 20), Self.instruction(from: 20, to: 45)],
            to: CMTime(seconds: 45, preferredTimescale: 600)
        )

        #expect(clamped.first?.timeRange.start == .zero)
        #expect(clamped.last?.timeRange.end.seconds == 45)
        for (previous, next) in zip(clamped, clamped.dropFirst()) {
            #expect(previous.timeRange.end == next.timeRange.start)
        }
    }
}
