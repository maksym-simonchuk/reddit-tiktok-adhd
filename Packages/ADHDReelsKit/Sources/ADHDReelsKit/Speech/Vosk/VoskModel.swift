import Foundation

/// Разложенная на диске модель vosk-tts: акустика (VITS), ruBERT для просодии, словарь
/// токенизатора и словарь ударений. Кладёт её `Scripts/fetch_tts.sh` — в репозитории
/// её нет, это почти гигабайт.
struct VoskModel: Sendable {

    struct Config: Decodable, Sendable {

        struct Audio: Decodable, Sendable {
            let sampleRate: Int

            enum CodingKeys: String, CodingKey {
                case sampleRate = "sample_rate"
            }
        }

        /// Настройки синтеза из обучения: шум в потоке, темп и разброс длительностей.
        struct Inference: Decodable, Sendable {
            let noiseLevel: Float
            let speechRate: Float
            let durationNoiseLevel: Float

            enum CodingKeys: String, CodingKey {
                case noiseLevel = "noise_level"
                case speechRate = "speech_rate"
                case durationNoiseLevel = "duration_noise_level"
            }
        }

        let audio: Audio
        let inference: Inference
        /// Фонемы и знаки препинания в одном словаре: у модели это один алфавит.
        let phonemes: [String: Int32]
        let speakers: [String: Int64]

        enum CodingKeys: String, CodingKey {
            case audio
            case inference
            case phonemes = "phoneme_id_map"
            case speakers = "speaker_id_map"
        }
    }

    static let folderName = "vosk-model-tts-ru-0.10-multi"

    /// Пусто, если модели не положили в бандл: тогда озвучит системный голос.
    static let shared: VoskModel? = load()

    let folder: URL
    let config: Config

    var acoustic: URL { folder.appending(path: "model.onnx") }
    var encoder: URL { folder.appending(path: "bert/model.onnx") }
    var vocabulary: URL { folder.appending(path: "bert/vocab.txt") }
    /// Отсортированный и отфильтрованный при сборке `dictionary`: см. `StressDictionary`.
    var dictionary: URL { folder.appending(path: "dictionary.sorted") }

    private static func load() -> VoskModel? {
        guard
            let resources = Bundle.main.resourceURL,
            case let folder = resources.appending(path: "Models/\(folderName)"),
            let data = try? Data(contentsOf: folder.appending(path: "config.json")),
            let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return nil }

        return VoskModel(folder: folder, config: config)
    }
}
