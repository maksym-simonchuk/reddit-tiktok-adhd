import SwiftUI

/// Оформление субтитров. Значения по умолчанию — то, что читается на телефоне
/// с вытянутой руки: крупный жирный шрифт, чёрная обводка поверх любого фона.
public struct CaptionTheme: Hashable, Sendable, Codable {

    public enum Highlight: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
        case yellow, green, pink, white

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .yellow: "Жёлтый"
            case .green: "Зелёный"
            case .pink: "Розовый"
            case .white: "Белый"
            }
        }

        public var color: Color {
            switch self {
            case .yellow: Color(red: 1.00, green: 0.84, blue: 0.20)
            case .green: Color(red: 0.35, green: 0.95, blue: 0.45)
            case .pink: Color(red: 1.00, green: 0.42, blue: 0.72)
            case .white: .white
            }
        }
    }

    public var fontSize: CGFloat = 104
    public var highlight: Highlight = .yellow
    /// Доля высоты кадра до центра строки. Чуть выше середины: снизу интерфейс TikTok.
    public var verticalPosition: CGFloat = 0.46
    public var uppercase = true

    public init() {}
}
