import Foundation

/// Вычитанные вручную сценарии, ключ — тред и язык. Лежат на диске: из-за одной буквы
/// перечитывать весь тред заново незачем, а перевод модели идёт десяток секунд.
enum ScriptEdits {

    static let url = URL.documentsDirectory.appending(path: "script-edits.json")

    /// Язык в ключе обязателен: сборка берёт вычитанный текст вместо перевода, и без
    /// языка русская вычитка молча уезжала бы в английский ролик — выбор языка
    /// выглядел бы сломанным.
    static func key(_ postID: String, _ language: ReelLanguage) -> String {
        "\(postID)|\(language.rawValue)"
    }

    static func load() -> [String: [TranslatedLine]] {
        guard let data = try? Data(contentsOf: url),
              let edits = try? JSONDecoder().decode([String: [TranslatedLine]].self, from: data)
        else { return [:] }

        return edits
    }

    static func save(_ edits: [String: [TranslatedLine]]) {
        guard let data = try? JSONEncoder().encode(edits) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
