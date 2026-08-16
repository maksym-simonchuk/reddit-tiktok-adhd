import Testing
import UIKit
@testable import ADHDReelsKit

@Suite("Обложка ролика")
@MainActor
struct CoverMakerTests {

    /// Белый кадр: на нём видно и затемнение, и то, что кадр вообще не потерялся.
    private var white: CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 1080, height: 1920)

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }.cgImage!
    }

    private func brightness(of image: UIImage, x: Int, y: Int) -> UInt8 {
        let pixel = image.cgImage!.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))!
        return (pixel.dataProvider!.data! as Data).first!
    }

    @Test("Обложка выходит в размер кадра")
    func size() {
        let cover = CoverMaker.draw(frame: white, title: "Она узнала об этом на свадьбе")
        #expect(cover.size == CGSize(width: 1080, height: 1920))
    }

    @Test("Верх затемнён под текст, низ остаётся геймплеем")
    func shade() {
        let cover = CoverMaker.draw(frame: white, title: "Она узнала об этом на свадьбе")

        // Слева от текста: проверяем именно градиент, а не буквы.
        #expect(brightness(of: cover, x: 10, y: 10) < 120)
        #expect(brightness(of: cover, x: 10, y: 1800) > 230)
    }

    @Test("Длинный заголовок ужимается, короткий остаётся крупным")
    func fontFits() {
        let short = CoverMaker.font(fitting: "Он ушёл")
        let long = CoverMaker.font(
            fitting: "Она узнала об этом на свадьбе своей сестры и молчала ещё три года"
        )

        #expect(short.pointSize > long.pointSize)
        #expect(long.pointSize >= 78)
    }

    @Test("Нет видео — нет обложки, а не падение")
    func missingVideo() async {
        let missing = URL.temporaryDirectory.appending(path: "нет-такого.mp4")
        let cover = await CoverMaker.make(
            from: missing,
            title: "Заголовок",
            to: URL.temporaryDirectory.appending(path: "cover.jpg")
        )

        #expect(cover == nil)
    }
}
