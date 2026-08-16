import Foundation

/// Что человек забраковал при вычитке и что модель выдала взамен, копится в markdown-файле:
/// по нему правится системная подсказка `LLMTranslator`. Файл лежит в Documents — он виден
/// в «Файлах», и забрать его можно с телефона, не подключая Xcode.
public enum TranslationReport {

    public static let url = URL.documentsDirectory.appending(path: "Ошибки перевода.md")

    public static func add(_ line: TranslatedLine, wrong: String, fixed: String, thread: String) throws {
        let entry = """

            ## \(thread)

            - EN: \(line.source)
            - было: \(line.translation)
            - не так: \(wrong)
            - стало: \(fixed)

            """

        guard let data = entry.data(using: .utf8) else { return }
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            try ("# Ошибки перевода\n" + entry).write(to: url, atomically: true, encoding: .utf8)
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}
