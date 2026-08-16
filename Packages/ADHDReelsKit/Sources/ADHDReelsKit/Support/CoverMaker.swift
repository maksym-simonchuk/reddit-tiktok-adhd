import AVFoundation
import UIKit

/// Обложка ролика: кадр из видео, затемнение и заголовок поверх. В ленте её видят
/// раньше самого видео — по ней и решают, смотреть ли, поэтому текст крупный и
/// стоит в верхней трети: низ кадра закрывает интерфейс TikTok.
public enum CoverMaker {

    /// Тот же кадр, что и у рендера: обложка не должна отличаться от первого кадра
    /// по цвету и обрезке.
    private static let size = CGSize(width: 1080, height: 1920)
    private static let inset: CGFloat = 90

    /// `nil` — не ошибка: без обложки список показывает обычный кадр из видео.
    @discardableResult
    public static func make(from video: URL, title: String, to url: URL) async -> URL? {
        guard let frame = await frame(of: video) else { return nil }
        guard let data = draw(frame: frame, title: title).jpegData(compressionQuality: 0.9) else { return nil }

        try? data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Кадр

    /// Вторая секунда: на нулевой ещё нет субтитров, и все обложки выходят одинаковыми.
    private static func frame(of video: URL) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size

        return try? await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600)).image
    }

    // MARK: - Рисование

    static func draw(frame: CGImage, title: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIImage(cgImage: frame).draw(in: CGRect(origin: .zero, size: size))
            shade(in: context.cgContext)

            let text = attributed(title)
            let width = size.width - inset * 2
            let height = ceil(text.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height)

            text.draw(with: CGRect(x: inset, y: size.height * 0.24 - height / 2, width: width, height: height),
                      options: [.usesLineFragmentOrigin, .usesFontLeading],
                      context: nil)
        }
    }

    /// Градиент сверху, а не сплошная заливка: геймплей должен остаться узнаваемым,
    /// иначе обложка не обещает то, что внутри.
    private static func shade(in context: CGContext) {
        let colors = [UIColor.black.withAlphaComponent(0.72).cgColor, UIColor.clear.cgColor]
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: [0, 1]
        ) else { return }

        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: 0, y: size.height * 0.55),
            options: []
        )
    }

    // MARK: - Текст

    private static func attributed(_ title: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineHeightMultiple = 0.94

        return NSAttributedString(string: title.uppercased(), attributes: [
            .font: font(fitting: title),
            .foregroundColor: UIColor.white,
            // Как в субтитрах: отрицательная ширина рисует и заливку, и обводку,
            // иначе белый текст пропадает на светлом кадре.
            .strokeColor: UIColor.black,
            .strokeWidth: -8.0,
            .paragraphStyle: paragraph,
        ])
    }

    /// Кегль подбирается под длину: короткий крючок должен быть огромным, длинный —
    /// влезть в три строки, а не уехать за край кадра.
    static func font(fitting title: String) -> UIFont {
        let width = size.width - inset * 2
        let limit = size.height * 0.3

        for points in stride(from: CGFloat(150), through: 78, by: -6) {
            let font = rounded(points)
            let height = NSAttributedString(string: title.uppercased(), attributes: [.font: font])
                .boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height

            if height <= limit { return font }
        }

        return rounded(78)
    }

    private static func rounded(_ points: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: points, weight: .black)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: points)
    }
}
