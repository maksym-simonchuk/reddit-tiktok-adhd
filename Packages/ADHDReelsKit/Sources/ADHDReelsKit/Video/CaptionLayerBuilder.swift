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
        let style = Style(of: theme)
        let font = font(size: theme.fontSize * style.fontScale, weight: style.weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineHeightMultiple = 0.92

        let result = NSMutableAttributedString()
        for (index, word) in group.words.enumerated() {
            let text = theme.uppercase ? word.text.uppercased() : word.text
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: index == active ? style.activeColor : style.inactiveColor,
                .paragraphStyle: paragraph,
            ]
            if style.strokes {
                // Отрицательная ширина рисует и заливку, и обводку: без неё
                // белый текст теряется на светлом фоне.
                attributes[.strokeColor] = UIColor.black
                attributes[.strokeWidth] = -9.0
            }
            result.append(NSAttributedString(string: index == 0 ? text : " " + text, attributes: attributes))
        }

        return result
    }

    /// Everything a preset controls, resolved once. Word-level sync itself is identical
    /// in every preset — only how the active word stands out differs.
    struct Style {
        let weight: UIFont.Weight
        let fontScale: CGFloat
        let strokes: Bool
        let activeColor: UIColor
        let inactiveColor: UIColor
        let shadowOpacity: Float
        let pulses: Bool

        init(of theme: CaptionTheme) {
            let highlight = UIColor(theme.highlight.color)
            switch theme.preset {
            case .classic:
                // No color pop: the active word reads as the only fully lit one.
                weight = .black; fontScale = 1; strokes = true; pulses = false
                activeColor = .white; inactiveColor = UIColor(white: 1, alpha: 0.75)
                shadowOpacity = 0.55
            case .viral:
                weight = .black; fontScale = 1; strokes = true; pulses = false
                activeColor = highlight; inactiveColor = .white
                shadowOpacity = 0.55
            case .minimal:
                weight = .semibold; fontScale = 0.8; strokes = false; pulses = false
                activeColor = .white; inactiveColor = UIColor(white: 1, alpha: 0.6)
                shadowOpacity = 0.35
            case .bold:
                weight = .black; fontScale = 1.08; strokes = true; pulses = true
                activeColor = highlight; inactiveColor = .white
                shadowOpacity = 0.7
            }
        }
    }

    private static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
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

        let style = Style(of: theme)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = style.shadowOpacity
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        layer.opacity = 0
        layer.add(switchOpacity(to: 1, at: word.start), forKey: "in")
        layer.add(switchOpacity(to: 0, at: word.end), forKey: "out")
        if style.pulses { layer.add(pulse(at: word.start), forKey: "pulse") }

        return layer
    }

    /// Bold preset: the block lands a touch larger on each word and settles — the
    /// hit is per word because each word owns its layer.
    private static func pulse(at time: Double) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.06
        animation.toValue = 1.0
        animation.beginTime = time <= 0 ? AVCoreAnimationBeginTimeAtZero : time
        animation.duration = 0.12
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        return animation
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
