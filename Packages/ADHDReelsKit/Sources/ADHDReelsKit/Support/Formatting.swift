import Foundation

/// Длительности и объёмы всегда показываются человеческим языком, а не голыми числами.
public enum Formatting {

    /// `134` → `"2 мин 14 с"`, `45` → `"45 с"`, `3725` → `"1 ч 2 мин"`.
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }

        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 { return "\(hours) ч \(minutes) мин" }
        if minutes > 0 { return "\(minutes) мин \(secs) с" }
        return "\(secs) с"
    }

    /// `438304768` → `"418 МБ"`.
    public static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: max(0, bytes))
    }

    /// `24100` → `"24,1k"`. Reddit-счётчики не читаются девятизначными числами.
    public static func compactCount(_ value: Int) -> String {
        switch abs(value) {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000).replacingOccurrences(of: ".", with: ",")
        case 1_000...:
            return String(format: "%.1fk", Double(value) / 1_000).replacingOccurrences(of: ".", with: ",")
        default:
            return "\(value)"
        }
    }
}
