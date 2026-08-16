import Testing
@testable import ADHDReelsKit

@Suite("Чистка английского текста")
struct EnglishCleanerTests {

    @Test("Markdown-ссылка сжимается до текста")
    func markdownLink() {
        #expect(EnglishCleaner.clean("See [this thread](https://reddit.com/x) now") == "See this thread now")
    }

    @Test("Голая ссылка вырезается целиком")
    func bareLink() {
        #expect(EnglishCleaner.clean("proof: https://imgur.com/a/xY9 ok") == "proof: ok")
    }

    @Test("Подреддит и ник теряют префикс, но не режут слова со слэшем")
    func subredditAndUser() {
        #expect(EnglishCleaner.clean("r/AskReddit and u/bob") == "AskReddit and bob")
        #expect(EnglishCleaner.clean("sour/sweet mix") == "sour sweet mix")
    }

    @Test("Цитата чужого сообщения выбрасывается")
    func quotedBlock() {
        let raw = """
        &gt; you are wrong
        No I am not
        """
        #expect(EnglishCleaner.clean(raw) == "No I am not")
    }

    @Test("Приписка Edit: обрезает хвост")
    func editFooter() {
        let raw = """
        The story ends here.
        Edit 2: thanks for the gold everyone
        """
        #expect(EnglishCleaner.clean(raw) == "The story ends here.")
    }

    @Test("Акронимы раскрываются только как отдельные слова")
    func acronyms() {
        #expect(EnglishCleaner.clean("AITA for this") == "Am I the asshole for this")
        #expect(EnglishCleaner.clean("NTA at all") == "not the asshole at all")
        #expect(EnglishCleaner.clean("AITAH") == "Am I the asshole")
    }

    @Test("Слово, начинающееся с акронима, не трогаем")
    func acronymInsideWord() {
        #expect(EnglishCleaner.clean("SOFT drink") == "SOFT drink")
        #expect(EnglishCleaner.clean("OPEN the door") == "OPEN the door")
    }

    @Test("Типографский апостроф сохраняет слово целиком")
    func typographicApostrophe() {
        #expect(EnglishCleaner.clean("I don\u{2019}t know") == "I don't know")
    }

    @Test("Эмодзи выбрасываются")
    func emoji() {
        #expect(EnglishCleaner.clean("that was wild 😳🔥") == "that was wild")
    }

    @Test("Возраст и пол разворачиваются словами, а не выбрасываются")
    func ageTag() {
        #expect(EnglishCleaner.clean("My wife (28F) said no") == "My wife, a 28-year-old woman, said no")
        #expect(EnglishCleaner.clean("I (M32) left") == "I, a 32-year-old man, left")
        #expect(EnglishCleaner.clean("Me 32M and her 30F") == "Me, a 32-year-old man, and her, a 30-year-old woman")
    }

    @Test("Метку возраста не видят там, где её нет")
    func ageTagFalsePositives() {
        #expect(EnglishCleaner.clean("He owes me $32M now") == "He owes me 32M now")
        #expect(EnglishCleaner.clean("The room was 30 m long") == "The room was 30 m long")
    }

    @Test("Выделения и заголовки не читаются вслух")
    func emphasis() {
        #expect(EnglishCleaner.clean("## **bold** and _italic_ and ~~gone~~") == "bold and italic and gone")
    }

    @Test("Абзац становится концом предложения, а не двойной точкой")
    func paragraphs() {
        #expect(EnglishCleaner.clean("First part.\n\nSecond part") == "First part. Second part")
    }

    @Test("Повторная пунктуация схлопывается")
    func repeatedPunctuation() {
        #expect(EnglishCleaner.clean("what?!?! really...") == "what? really.")
    }

    @Test("Пустой ввод не ломает чистку")
    func empty() {
        #expect(EnglishCleaner.clean("") == "")
        #expect(EnglishCleaner.clean("   \n\n  ") == "")
    }
}
