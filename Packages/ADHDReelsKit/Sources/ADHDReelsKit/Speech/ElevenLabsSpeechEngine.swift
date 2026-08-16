import AVFoundation
import Foundation

/// Облачная озвучка ElevenLabs — живой человеческий голос вместо синтезатора.
/// Тот же контракт, что у локальных движков: текст в файл плюс тайминги слов;
/// их отдаёт сам API посимвольно, склейка в слова — наша.
///
/// Сетевой движок включается явно в настройках и только при сохранённом ключе:
/// текст истории уходит на сервер ElevenLabs, и это должно быть осознанным выбором.
public struct ElevenLabsSpeechEngine: SpeechEngine {

    public struct Voice: Identifiable, Hashable, Sendable {
        /// ElevenLabs `voice_id` — стабильные идентификаторы готовых дикторов.
        public let id: String
        public let title: String
    }

    /// Проверенные дикторы-рассказчики из общей библиотеки: выбор из четырёх
    /// осмысленных лучше поиска по тысячам.
    public static let voices: [Voice] = [
        Voice(id: "pNInz6obpgDQGcFmaJgB", title: "Adam · deep"),
        Voice(id: "nPczCjzI2devNBz1zQrb", title: "Brian · narrator"),
        Voice(id: "21m00Tcm4TlvDq8ikWAM", title: "Rachel · calm"),
        Voice(id: "ErXwobaYiN019PkySvjV", title: "Antoni · warm"),
    ]

    public static let defaultVoice = voices[0].id

    public enum Failure: LocalizedError, Equatable {
        case emptyScript
        case badKey
        case rateLimited
        case badStatus(Int)
        case server(String)
        case malformed
        case silence

        public var errorDescription: String? {
            switch self {
            case .emptyScript: "The script is empty — nothing to narrate."
            case .badKey: "ElevenLabs rejected the API key. Check the key in Settings and the plan's character quota."
            case .rateLimited: "ElevenLabs is rate-limiting requests. Wait a minute and try again."
            case .badStatus(let code): "ElevenLabs responded with status \(code)."
            case .server(let message): "ElevenLabs: \(message)"
            case .malformed: "ElevenLabs sent a response in an unknown format."
            case .silence: "ElevenLabs returned no audio. Try another voice."
            }
        }
    }

    // MARK: - Ключ

    private static let account = "elevenlabs-api-key"

    public static func storedKey() -> String? {
        Keychain.string(for: account)
    }

    @discardableResult
    public static func setStoredKey(_ key: String?) -> Bool {
        Keychain.set(key?.trimmingCharacters(in: .whitespacesAndNewlines), for: account)
    }

    private let apiKey: String
    private let voiceID: String
    private let speed: Double

    public init(apiKey: String, voiceID: String = ElevenLabsSpeechEngine.defaultVoice, speed: Double = 1) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.speed = speed
    }

    // MARK: - Синтез

    public func synthesize(_ script: Script, to url: URL) async throws -> SpeechTake {
        let text = script.plainText
        guard !text.isEmpty else { throw Failure.emptyScript }

        let answer = try await request(text)
        guard let audio = Data(base64Encoded: answer.audioBase64), !audio.isEmpty else {
            throw Failure.malformed
        }

        // API отдаёт mp3, а расширение — не косметика: AVURLAsset выбирает по нему ридер.
        let target = url.deletingPathExtension().appendingPathExtension("mp3")
        try audio.write(to: target, options: .atomic)

        let alignment = answer.alignment ?? answer.normalizedAlignment
        let words = alignment.map {
            Self.words(
                characters: $0.characters,
                starts: $0.characterStartTimesSeconds,
                ends: $0.characterEndTimesSeconds
            )
        } ?? []

        let duration = await duration(of: target) ?? words.last?.end ?? 0
        guard duration > 0 else { throw Failure.silence }

        return SpeechTake(audioURL: target, duration: duration, words: words.isEmpty ? nil : words)
    }

    /// Посимвольные тайминги API складываются в слова: слово — это непрерывный кусок
    /// без пробелов, время — от первого его символа до последнего.
    static func words(characters: [String], starts: [Double], ends: [Double]) -> [WordTiming] {
        var words: [WordTiming] = []
        var text = ""
        var start = 0.0
        var end = 0.0

        func flush() {
            guard !text.isEmpty else { return }
            words.append(WordTiming(text: text, start: start, end: max(end, start + 0.01)))
            text = ""
        }

        for index in characters.indices {
            guard index < starts.count, index < ends.count else { break }

            let character = characters[index]
            if character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flush()
            } else {
                if text.isEmpty { start = starts[index] }
                text += character
                end = ends[index]
            }
        }
        flush()

        return words
    }

    // MARK: - Транспорт

    private struct Payload: Encodable {
        struct Settings: Encodable {
            let speed: Double
        }

        let text: String
        let modelId: String
        let voiceSettings: Settings?
    }

    private struct Answer: Decodable {
        struct Alignment: Decodable {
            let characters: [String]
            let characterStartTimesSeconds: [Double]
            let characterEndTimesSeconds: [Double]
        }

        let audioBase64: String
        let alignment: Alignment?
        let normalizedAlignment: Alignment?
    }

    private func request(_ text: String) async throws -> Answer {
        guard let url = URL(
            string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)/with-timestamps?output_format=mp3_44100_128"
        ) else { throw Failure.malformed }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(Payload(
            text: text,
            modelId: "eleven_multilingual_v2",
            // API принимает 0.7–1.2; наша шкала чуть шире, края прижимаются.
            voiceSettings: speed == 1 ? nil : Payload.Settings(speed: min(max(speed, 0.7), 1.2))
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.malformed }

        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw Failure.badKey
        case 429: throw Failure.rateLimited
        default: throw Self.serverMessage(in: data).map(Failure.server) ?? Failure.badStatus(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let answer = try? decoder.decode(Answer.self, from: data) else { throw Failure.malformed }
        return answer
    }

    /// Тело ошибки API приходит двумя формами — `{"detail": {"message": "…"}}`
    /// и `{"detail": "…"}`; человеку полезнее текст сервера, чем голый статус.
    static func serverMessage(in data: Data) -> String? {
        struct Nested: Decodable {
            struct Detail: Decodable { let message: String? }
            let detail: Detail?
        }
        struct Flat: Decodable { let detail: String? }

        if let message = (try? JSONDecoder().decode(Nested.self, from: data))?.detail?.message {
            return message
        }
        return (try? JSONDecoder().decode(Flat.self, from: data))?.detail
    }

    /// Длительность берётся из самого файла: монтаж режет геймплей ровно под неё,
    /// и доверять тут таймингам разметки, а не аудио, нельзя.
    private func duration(of url: URL) async -> Double? {
        guard let duration = try? await AVURLAsset(url: url).load(.duration) else { return nil }
        let seconds = duration.seconds
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }
}
