import Testing
@testable import ADHDReelsKit

@Suite("Подпись к ролику")
struct DescriptionWriterTests {

    @Test("Короткий заголовок не трогаем")
    func keepsShort() {
        #expect(DescriptionWriter.shorten("Он ушёл с вечеринки в девять") == "Он ушёл с вечеринки в девять")
    }

    @Test("Длинный режется по слову и без хвостовых знаков")
    func cutsOnWord() {
        let title = DescriptionWriter.shorten(
            "Она узнала об этом на свадьбе своей сестры, и молчала ещё целых три года"
        )

        #expect(title.count <= 60)
        #expect(title == "Она узнала об этом на свадьбе своей сестры, и молчала ещё")
        #expect(!title.hasSuffix(" целых"))
    }

    @Test("Слово длиннее лимита всё равно даёт заголовок")
    func cutsUnbreakable() {
        let title = DescriptionWriter.shorten(String(repeating: "я", count: 80))
        #expect(title.count == 60)
    }

    @Test("Без модели подпись собирается из крючка сценария")
    func fallback() {
        let script = Script(segments: [
            ScriptSegment(kind: .hook, text: "Досмотри до конца, там поворот."),
            ScriptSegment(kind: .body, text: "Дальше история."),
        ])

        let description = DescriptionWriter.fallback(script: script, subreddit: "tifu")
        #expect(description.title == "Досмотри до конца, там поворот.")
        #expect(description.body.contains("r/tifu"))
        #expect(description.tags.count == 5)
    }
}
