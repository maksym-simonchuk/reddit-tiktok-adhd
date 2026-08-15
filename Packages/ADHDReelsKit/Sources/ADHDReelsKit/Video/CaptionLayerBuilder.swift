import AVFoundation
import UIKit

/// Собирает дерево слоёв для караоке-субтитров: на каждое слово свой слой с уже
/// подсвеченным вариантом строки, показанный ровно на его отрезке времени.
///
/// Слоёв получается по числу слов, а не по числу кадров, поэтому 45-секундный
/// ролик — это около сотни слоёв, и каждый рисуется один раз.
public enum CaptionLayerBuilder {

    public static func layer(groups: [CaptionGroup], size: CGSize, theme: CaptionTheme) -> CALayer {
        let root = CALayer()
        root.frame = CGRect(origin: .zero, size: size)
        root.isGeometryFlipped = false

        for group in groups {
            for (index, word) in group.words.enumerated() {
                let text = attributed(group: group, active: index, theme: theme)
                root.addSublayer(textLayer(text, at: word, in: size, theme: theme))
            }
        }

        return root
    }

    // MARK: - Текст

    static func attributed(group: CaptionGroup, active: Int, theme: CaptionTheme) -> NSAttributedString {
        let font = font(size: theme.fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineHeightMultiple = 0.92

        let result = NSMutableAttributedString()
        for (index, word) in group.words.enumerated() {
            let text = theme.uppercase ? word.text.uppercased() : word.text
            result.append(NSAttributedString(
                string: index == 0 ? text : " " + text,
                attributes: [
                    .font: font,
                    .foregroundColor: index == active ? UIColor(theme.highlight.color) : UIColor.white,
                    // Отрицательная ширина рисует и заливку, и обводку: без неё
                    // белый текст теряется на светлом фоне.
                    .strokeColor: UIColor.black,
                    .strokeWidth: -9.0,
                    .paragraphStyle: paragraph,
                ]
            ))
        }

        return result
    }

    private static func font(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .black)
        // Скруглённый вариант системного шрифта покрывает кириллицу — сторонний
        // шрифт под это не нужен.
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Слои

    private static func textLayer(
        _ text: NSAttributedString,
        at word: WordTiming,
        in size: CGSize,
        theme: CaptionTheme
    ) -> CALayer {
        let inset = size.width * 0.08
        let width = size.width - inset * 2
        let height = ceil(text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).height) + theme.fontSize * 0.4

        let layer = CATextLayer()
        layer.string = text
        layer.isWrapped = true
        layer.alignmentMode = .center
        layer.contentsScale = 1
        layer.frame = CGRect(
            x: inset,
            y: size.height * (1 - theme.verticalPosition) - height / 2,
            width: width,
            height: height
        )

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        layer.opacity = 0
        layer.add(switchOpacity(to: 1, at: word.start), forKey: "in")
        layer.add(switchOpacity(to: 0, at: word.end), forKey: "out")

        return layer
    }

    /// В Core Animation `beginTime == 0` означает «сейчас», поэтому нулевой момент
    /// подменяется константой AVFoundation — иначе первое слово мигает не вовремя.
    private static func switchOpacity(to value: Float, at time: Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.toValue = value
        animation.beginTime = time <= 0 ? AVCoreAnimationBeginTimeAtZero : time
        animation.duration = 0.01
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
    }
}
