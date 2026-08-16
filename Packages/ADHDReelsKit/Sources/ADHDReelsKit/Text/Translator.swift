import Foundation
import Translation

/// EN → язык озвучки на устройстве. Сессию с iOS 26 можно создать напрямую, без
/// SwiftUI-модификатора, но только для уже скачанного языкового пакета — отсюда явная
/// ошибка вместо молчания.
public actor Translator {

    public enum Failure: LocalizedError {
        case packMissing(ReelLanguage)
        case unsupported(ReelLanguage)
        case engine(String)

        public var errorDescription: String? {
            switch self {
            case .packMissing(let language):
                // Язык системы и клавиатуры к переводу отношения не имеет: пакеты
                // качаются отдельно. Качает их приложение, поэтому текст — на случай отказа.
                "The \(language.title) translation pack is not downloaded."
            case .unsupported(let language):
                "This device cannot translate from English to \(language.title)."
            case .engine(let reason):
                "Translation failed: \(reason)"
            }
        }
    }

    public static let source = Locale.Language(identifier: "en")

    private let source = Translator.source
    private let language: ReelLanguage
    private let target: Locale.Language
    private var cache: TranslationCache

    /// Кэш у каждого языка свой: он ключуется исходным текстом, и общий файл отдавал бы
    /// испанский перевод на русский запрос.
    public init(target language: ReelLanguage = .russian, cacheURL: URL? = nil) {
        self.language = language
        self.target = language.locale
        self.cache = TranslationCache(url: cacheURL ?? TranslationCache.defaultURL(for: language))
    }

    /// Возвращает переведённые сегменты, сохраняя порядок и `kind`.
    public func translate(_ segments: [ScriptSegment]) async throws -> [ScriptSegment] {
        let pending = segments.filter { cache[$0.text] == nil }

        if !pending.isEmpty {
            try await fill(pending.map(\.text))
        }

        return segments.compactMap { segment in
            guard let translated = cache[segment.text] else { return nil }
            return ScriptSegment(kind: segment.kind, text: translated)
        }
    }

    private func fill(_ texts: [String]) async throws {
        switch await LanguageAvailability().status(from: source, to: target) {
        case .installed: break
        case .supported: throw Failure.packMissing(language)
        case .unsupported: throw Failure.unsupported(language)
        @unknown default: throw Failure.unsupported(language)
        }

        let session = TranslationSession(installedSource: source, target: target)
        let requests = texts.enumerated().map {
            TranslationSession.Request(sourceText: $1, clientIdentifier: String($0))
        }

        do {
            for response in try await session.translations(from: requests) {
                cache[response.sourceText] = response.targetText
            }
        } catch TranslationError.notInstalled {
            throw Failure.packMissing(language)
        } catch {
            throw Failure.engine(error.localizedDescription)
        }

        cache.save()
    }
}
