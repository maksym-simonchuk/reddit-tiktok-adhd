import AVFoundation
import Observation

/// Проба голоса в настройках. Имя диктора в списке не говорит ничего: у vosk это
/// пятьдесят семь строк вида «Кузнецов Всеволод», и какой из них читает тред —
/// слышно только вслух.
///
/// Фраза идёт тем же движком и той же подачей, что и ролик: хук с паузой, потом тело.
/// Пробовать голос дорожкой, которая звучит иначе, чем итог, незачем.
@MainActor
@Observable
public final class VoiceAudition {

    /// Нейроголос считает секунды: сначала грузятся два графа, потом синтез. Без
    /// этого флага человек успевает решить, что кнопка сломана, и нажать ещё раз.
    public private(set) var isBusy = false

    @ObservationIgnored private var player: AVAudioPlayer?

    public init() {}

    public func play(voiceIdentifier: String?, language: ReelLanguage) async throws {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        stop()

        let url = URL.temporaryDirectory.appending(path: "voice-sample.wav")
        let engine = SpeechEngines.make(voiceIdentifier: voiceIdentifier, language: language)
        _ = try await engine.synthesize(Self.sample(for: language), to: url)

        // Категория по умолчанию молчит с выключенным звонком, а проба голоса — ровно
        // тот случай, когда звука ждут: человек нажал кнопку «Послушать».
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback)
        try? session.setActive(true)

        player = try AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    public func stop() {
        player?.stop()
        player = nil
    }

    /// Кусок треда, а не «раз-два-три»: голос выбирают под истории с Reddit, и судить
    /// его надо на той же интонации — вопрос в хуке, признание в теле.
    private static func sample(for language: ReelLanguage) -> Script {
        let (hook, body) = text(for: language)
        return Script(segments: [
            ScriptSegment(kind: .hook, text: hook),
            ScriptSegment(kind: .body, text: body),
        ])
    }

    private static func text(for language: ReelLanguage) -> (String, String) {
        switch language {
        case .russian:
            ("Я виноват, что сказал сестре правду на её свадьбе?",
             "Она просила не портить праздник, а я просто не смог промолчать.")
        case .english:
            ("Am I the asshole for telling my sister the truth at her wedding?",
             "She asked me not to ruin her day, and I just could not stay quiet.")
        case .spanish:
            ("¿Soy el malo por decirle la verdad a mi hermana en su boda?",
             "Me pidió que no arruinara su día, y simplemente no pude callarme.")
        case .portuguese:
            ("Eu sou o errado por contar a verdade para minha irmã no casamento dela?",
             "Ela pediu para eu não estragar o dia, e eu simplesmente não consegui ficar calado.")
        }
    }
}
