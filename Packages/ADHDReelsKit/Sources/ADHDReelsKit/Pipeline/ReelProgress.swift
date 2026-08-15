import Foundation

/// Шаги сборки ролика в том порядке, в котором они идут.
public enum ReelStage: Int, CaseIterable, Comparable, Sendable {
    case reading
    case translating
    case voicing
    case mounting
    case rendering
    case describing

    public static func < (lhs: ReelStage, rhs: ReelStage) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .reading: "Читаю тред"
        case .translating: "Перевожу на русский"
        case .voicing: "Озвучиваю"
        case .mounting: "Подбираю геймплей"
        case .rendering: "Собираю видео"
        case .describing: "Пишу описание"
        }
    }

    /// Доля общего времени. Перевод и синтез идут по тексту, монтаж — по кадрам,
    /// поэтому вес у них разный. Числа с замеров на ролике в 45 секунд.
    var weight: Double {
        switch self {
        case .reading: 0.05
        case .translating: 0.15
        case .voicing: 0.25
        case .mounting: 0.05
        case .rendering: 0.45
        case .describing: 0.05
        }
    }
}

/// Состояние сборки для одной полоски прогресса: шаг словами и доля от всей работы.
public struct ReelProgress: Hashable, Sendable {

    public let stage: ReelStage
    public let fraction: Double

    public init(stage: ReelStage, within: Double = 0) {
        self.stage = stage
        self.fraction = Self.overall(stage: stage, within: within)
    }

    public var title: String { stage.title }

    /// Сумма весов пройденных шагов плюс доля текущего. Полоска не откатывается назад
    /// и не упирается в сто процентов раньше времени.
    static func overall(stage: ReelStage, within: Double) -> Double {
        let done = ReelStage.allCases
            .filter { $0 < stage }
            .reduce(0) { $0 + $1.weight }

        return min(1, done + stage.weight * min(max(within, 0), 1))
    }
}
