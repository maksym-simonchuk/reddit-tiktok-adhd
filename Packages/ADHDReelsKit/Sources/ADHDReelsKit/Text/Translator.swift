import Foundation
import Translation

/// EN → RU на устройстве. Сессию с iOS 26 можно создать напрямую, без SwiftUI-модификатора,
/// но только для уже скачанного языкового пакета — отсюда явная ошибка вместо молчания.
public actor Translator {

    public enum Failure: LocalizedError {
        case packMissing
        case unsupported
        case engine(String)

        public var errorDescription: String? {
            switch self {
            case .packMissing:
                "Не скачан языковой пакет. Настройки → Основные → Язык и регион → Языки перевода."
            case .unsupported:
                "Устройство не поддерживает перевод с английского на русский."
            case .engine(let reason):
                "Переводчик не справился: \(reason)"
            }
        }
    }

    private let source = Locale.Language(identifier: "en")
    private let target = Locale.Language(identifier: "ru")
    private var cache: TranslationCache

    public init(cacheURL: URL? = TranslationCache.defaultURL) {
        self.cache = TranslationCache(url: cacheURL)
    }

    /// Возвращает сегменты с русским текстом, сохраняя порядок и `kind`.
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
        case .supported: throw Failure.packMissing
        case .unsupported: throw Failure.unsupported
        @unknown default: throw Failure.unsupported
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
            throw Failure.packMissing
        } catch {
            throw Failure.engine(error.localizedDescription)
        }

        cache.save()
    }
}
