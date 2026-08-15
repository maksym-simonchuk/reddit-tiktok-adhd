import SwiftUI

/// Единственный источник визуальных токенов. Ни один экран не задаёт цвет или радиус сам.
public enum Theme {

    // MARK: Цвет

    public static let background = Color(red: 0.043, green: 0.043, blue: 0.059)   // #0B0B0F
    public static let panel = Color(red: 0.086, green: 0.086, blue: 0.110)        // #16161C
    public static let separator = Color(red: 0.149, green: 0.149, blue: 0.180)    // #26262E
    public static let accent = Color(red: 1.000, green: 0.302, blue: 0.180)       // #FF4D2E
    public static let success = Color(red: 0.239, green: 0.863, blue: 0.518)      // #3DDC84
    public static let danger = Color(red: 1.000, green: 0.361, blue: 0.361)       // #FF5C5C

    public static let primaryText = Color.white
    public static let secondaryText = Color.white.opacity(0.56)
    public static let tertiaryText = Color.white.opacity(0.32)

    // MARK: Геометрия

    /// Все отступы кратны восьми.
    public static let spacing: CGFloat = 8
    public static let cornerRadius: CGFloat = 16
    /// Минимальная тач-цель по HIG.
    public static let minimumHitTarget: CGFloat = 44

    // MARK: Типографика

    public static func title(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    public static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Для чисел: моноширинные цифры не дёргают вёрстку при обновлении прогресса.
    public static func numeric(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }

    // MARK: Движение

    /// Единственная анимация в приложении.
    public static let motion: Animation = .spring(response: 0.35, dampingFraction: 0.85)
}
