import SwiftUI

/// Оформление субтитров. Значения по умолчанию — то, что читается на телефоне
/// с вытянутой руки: крупный жирный шрифт, чёрная обводка поверх любого фона.
public struct CaptionTheme: Hashable, Sendable, Codable {

    public enum Highlight: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
        case yellow, green, pink, white

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .yellow: "Yellow"
            case .green: "Green"
            case .pink: "Pink"
            case .white: "White"
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

    /// Look of the caption block; word-level sync stays on in every preset, the presets
    /// differ in how loudly the active word announces itself.
    public enum Preset: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
        case classic
        case viral
        case minimal
        case bold

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .classic: "Classic"
            case .viral: "Viral"
            case .minimal: "Minimal"
            case .bold: "Bold"
            }
        }

        public var subtitle: String {
            switch self {
            case .classic: "White with outline"
            case .viral: "Karaoke color pop"
            case .minimal: "Clean, no outline"
            case .bold: "Heavy with pulse"
            }
        }

        /// Classic and Minimal keep the active word white; the highlight color only
        /// exists in the presets that paint with it.
        public var usesHighlightColor: Bool {
            switch self {
            case .viral, .bold: true
            case .classic, .minimal: false
            }
        }
    }

    public var preset: Preset = .viral
    public var fontSize: CGFloat = 104
    public var highlight: Highlight = .yellow
    /// Доля высоты кадра до центра строки. Чуть выше середины: снизу интерфейс TikTok.
    public var verticalPosition: CGFloat = 0.46
    public var uppercase = true

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case preset, fontSize, highlight, verticalPosition, uppercase
    }

    /// Themes saved by older builds are missing `preset`; failing the decode would drag
    /// the whole settings blob down with it, so every field falls back to its default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = CaptionTheme()

        preset = try container.decodeIfPresent(Preset.self, forKey: .preset) ?? defaults.preset
        fontSize = try container.decodeIfPresent(CGFloat.self, forKey: .fontSize) ?? defaults.fontSize
        highlight = try container.decodeIfPresent(Highlight.self, forKey: .highlight) ?? defaults.highlight
        verticalPosition = try container.decodeIfPresent(CGFloat.self, forKey: .verticalPosition)
            ?? defaults.verticalPosition
        uppercase = try container.decodeIfPresent(Bool.self, forKey: .uppercase) ?? defaults.uppercase
    }
}
