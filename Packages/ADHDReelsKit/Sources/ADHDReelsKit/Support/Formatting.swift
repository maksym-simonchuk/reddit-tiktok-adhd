import Foundation

/// Длительности и объёмы всегда показываются человеческим языком, а не голыми числами.
public enum Formatting {

    /// `134` → `"2m 14s"`, `45` → `"45s"`, `3725` → `"1h 2m"`.
    public static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }

        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }

    /// `438304768` → `"418 MB"`.
    public static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: max(0, bytes))
    }

    /// `24100` → `"24.1k"`. Reddit-счётчики не читаются девятизначными числами.
    public static func compactCount(_ value: Int) -> String {
        switch abs(value) {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fk", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    /// Post age for feed cards: `"5h ago"`, `"2d ago"`. Below an hour everything is
    /// `"just now"` — top-of-week posts are never that fresh, minute precision is noise.
    public static func age(of date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds.isFinite, seconds >= 3600 else { return "just now" }

        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 30 { return "\(days)d ago" }
        // Years derive from the same 30-day months, otherwise ages of 360–364 days
        // land between the buckets and print "0y ago".
        let months = days / 30
        if months < 12 { return "\(months)mo ago" }
        return "\(months / 12)y ago"
    }
}
