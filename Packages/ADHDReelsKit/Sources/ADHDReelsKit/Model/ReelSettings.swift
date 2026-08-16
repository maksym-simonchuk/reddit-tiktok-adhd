import Foundation

/// Всё, что пользователь может настроить. Одна структура — один ключ в UserDefaults:
/// добавить настройку значит добавить поле, а не ещё один ключ и ещё одну миграцию.
public struct ReelSettings: Codable, Hashable, Sendable {

    public var subreddit = "TrueOffMyChest"
    public var window = "week"
    public var targetDuration: Double = 45
    public var minimumScore = 500
    public var voiceIdentifier: String?
    /// Narration speed multiplier; 1.0 is each engine's tuned delivery.
    public var voiceSpeed: Double = 1
    /// Skips NSFW posts and stories that trip the profanity screen.
    public var safeContentOnly = true
    public var caption = CaptionTheme()

    /// Cloud narration via ElevenLabs. Only the choice and the narrator live here —
    /// the API key stays in the keychain, never in this blob.
    public var useElevenLabs = false
    public var elevenLabsVoiceID: String?

    /// Голоса привязаны к языку, поэтому смена языка сбрасывает выбор: сохранённый
    /// диктор чужого языка всё равно не нашёлся бы, а движок молча брал бы первый.
    public var language = ReelLanguage.english {
        didSet { if oldValue != language { voiceIdentifier = nil } }
    }

    public init() {}

    /// Окна Reddit, которые имеют смысл: за час постов слишком мало, за всё время
    /// они одни и те же.
    public static let windows = ["day", "week", "month", "year"]

    public static func windowTitle(_ window: String) -> String {
        switch window {
        case "day": "Today"
        case "week": "This week"
        case "month": "This month"
        default: "This year"
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
        "TrueOffMyChest": "Off My Chest",
        "AmItheAsshole": "Am I the A-hole?",
        "tifu": "Today I F'd Up",
        "confession": "Confessions",
        "relationship_advice": "Relationships",
        "pettyrevenge": "Petty Revenge",
    ]

    public var scriptOptions: ScriptWriter.Options {
        var options = ScriptWriter.Options()
        options.targetDuration = targetDuration
        options.language = language
        return options
    }

    // MARK: - Хранение

    private enum CodingKeys: String, CodingKey {
        case subreddit, window, targetDuration, minimumScore
        case voiceIdentifier, voiceSpeed, safeContentOnly, caption, language
        case useElevenLabs, elevenLabsVoiceID
    }

    /// Every field decodes as optional: a blob saved by an older build is missing the
    /// newer keys, and failing the whole decode would silently reset user settings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReelSettings()

        subreddit = try container.decodeIfPresent(String.self, forKey: .subreddit) ?? defaults.subreddit
        window = try container.decodeIfPresent(String.self, forKey: .window) ?? defaults.window
        targetDuration = try container.decodeIfPresent(Double.self, forKey: .targetDuration) ?? defaults.targetDuration
        minimumScore = try container.decodeIfPresent(Int.self, forKey: .minimumScore) ?? defaults.minimumScore
        voiceIdentifier = try container.decodeIfPresent(String.self, forKey: .voiceIdentifier)
        voiceSpeed = try container.decodeIfPresent(Double.self, forKey: .voiceSpeed) ?? defaults.voiceSpeed
        safeContentOnly = try container.decodeIfPresent(Bool.self, forKey: .safeContentOnly) ?? defaults.safeContentOnly
        caption = try container.decodeIfPresent(CaptionTheme.self, forKey: .caption) ?? defaults.caption
        useElevenLabs = try container.decodeIfPresent(Bool.self, forKey: .useElevenLabs) ?? defaults.useElevenLabs
        elevenLabsVoiceID = try container.decodeIfPresent(String.self, forKey: .elevenLabsVoiceID)
        language = try container.decodeIfPresent(ReelLanguage.self, forKey: .language) ?? defaults.language
    }

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
