import Testing
import UIKit
@testable import ADHDReelsKit

/// Слои субтитров в готовый ролик попадают через CoreAnimation, а его в симуляторе
/// не проверить. Зато сами слои рисуются обычным контекстом — это и проверяем:
/// текст есть, стоит в своей полосе, активное слово другого цвета.
@Suite("Слой субтитров")
struct CaptionLayerTests {

    private static let size = CGSize(width: 1080, height: 1920)

    private static let group = CaptionGroup(words: [
        WordTiming(text: "молчал", start: 0, end: 0.5),
        WordTiming(text: "двенадцать", start: 0.5, end: 1),
    ])

    /// Пиксели слоя: RGBA по строкам сверху вниз.
    private static func pixels(of layer: CALayer) -> [UInt8] {
        let width = Int(size.width)
        let height = Int(size.height)
        var buffer = [UInt8](repeating: 0, count: width * height * 4)

        buffer.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }

            // CGContext считает от низа, CALayer — от верха.
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            layer.render(in: context)
        }

        return buffer
    }

    private static func firstWordLayer(theme: CaptionTheme = CaptionTheme()) -> CALayer {
        let root = CaptionLayerBuilder.layer(groups: [group], size: size, theme: theme)
        // Слои спрятаны до своего момента — для снимка показываем первый.
        root.sublayers?.first?.opacity = 1
        return root
    }

    @Test("На каждое слово приходится свой слой")
    func buildsLayerPerWord() {
        let root = CaptionLayerBuilder.layer(groups: [Self.group], size: Self.size, theme: CaptionTheme())
        #expect(root.sublayers?.count == 2)
    }

    @Test("Текст рисуется и не выходит за свою полосу")
    func drawsTextInsideBand() throws {
        let root = Self.firstWordLayer()
        let band = try #require(root.sublayers?.first).frame
        let data = Self.pixels(of: root)

        var inked: [Int] = []
        for row in 0..<Int(Self.size.height) {
            let start = row * Int(Self.size.width) * 4
            let hasInk = stride(from: start + 3, to: start + Int(Self.size.width) * 4, by: 4)
                .contains { data[$0] > 32 }
            if hasInk { inked.append(row) }
        }

        #expect(!inked.isEmpty, "субтитры не нарисовались")
        // Тень выходит за рамку слоя, поэтому полосу берём с запасом.
        #expect(inked.allSatisfy { Double($0) > band.minY - 40 && Double($0) < band.maxY + 40 })
    }

    @Test("Активное слово подсвечено цветом темы")
    func highlightsActiveWord() {
        let data = Self.pixels(of: Self.firstWordLayer())

        // Жёлтый темы: красный и зелёный высокие, синий низкий.
        let yellow = stride(from: 0, to: data.count, by: 4).count { index in
            data[index] > 200 && data[index + 1] > 150 && data[index + 2] < 120 && data[index + 3] > 200
        }

        #expect(yellow > 500, "подсветки активного слова не видно")
    }
}
