import Foundation

/// Всё, что пользователь может настроить. Одна структура — один ключ в UserDefaults:
/// добавить настройку значит добавить поле, а не ещё один ключ и ещё одну миграцию.
public struct ReelSettings: Codable, Hashable, Sendable {

    public var subreddit = "TrueOffMyChest"
    public var window = "week"
    public var targetDuration: Double = 45
    public var minimumScore = 500
    public var voiceIdentifier: String?
    public var caption = CaptionTheme()

    /// Голоса привязаны к языку, поэтому смена языка сбрасывает выбор: сохранённый
    /// диктор чужого языка всё равно не нашёлся бы, а движок молча брал бы первый.
    public var language = ReelLanguage.russian {
        didSet { if oldValue != language { voiceIdentifier = nil } }
    }

    public init() {}

    /// Окна Reddit, которые имеют смысл: за час постов слишком мало, за всё время
    /// они одни и те же.
    public static let windows = ["day", "week", "month", "year"]

    public static func windowTitle(_ window: String) -> String {
        switch window {
        case "day": "За день"
        case "week": "За неделю"
        case "month": "За месяц"
        default: "За год"
        }
    }

    /// Подреддиты с историями от первого лица: их можно читать вслух как есть.
    public static let suggestedSubreddits = [
        "TrueOffMyChest",
        "AmItheAsshole",
        "tifu",
        "confession",
        "relationship_advice",
        "pettyrevenge"
    ]

    /// Название по-человечески: «r/tifu» ничего не говорит, пока не прочитаешь десяток
    /// тредов. Незнакомое имя показываем как есть — его мог вписать пользователь.
    public static func subredditTitle(_ subreddit: String) -> String {
        titles[subreddit] ?? subreddit
    }

    private static let titles = [
        "TrueOffMyChest": "Наболело",
        "AmItheAsshole": "Я не прав?",
        "tifu": "Я всё испортил",
        "confession": "Признания",
        "relationship_advice": "Отношения",
        "pettyrevenge": "Мелкая месть",
    ]

    public var scriptOptions: ScriptWriter.Options {
        var options = ScriptWriter.Options()
        options.targetDuration = targetDuration
        options.language = language
        return options
    }

    // MARK: - Хранение

    private static let key = "settings"

    public static func load() -> ReelSettings {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let settings = try? JSONDecoder().decode(ReelSettings.self, from: data)
        else { return ReelSettings() }

        return settings
    }

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
