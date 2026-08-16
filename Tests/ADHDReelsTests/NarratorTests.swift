import Testing
@testable import ADHDReelsKit

@Suite("Пол рассказчика")
struct NarratorTests {

    @Test("Пометка о себе после чистки читается как пол рассказчика")
    func fromAgeTag() {
        #expect(Narrator.gender(of: EnglishCleaner.clean("I (28F) left him")) == .female)
        #expect(Narrator.gender(of: EnglishCleaner.clean("Me 34M and my dad")) == .male)
    }

    @Test("Пол называют и словами")
    func spelledOut() {
        #expect(Narrator.gender(of: "I am a 30 year old woman and I am tired") == .female)
        #expect(Narrator.gender(of: "I'm a 41-year-old male here") == .male)
    }

    /// Пол жены к рассказчику отношения не имеет: угадав по нему, ролик получил бы
    /// женский род на мужском рассказе.
    @Test("Чужая пометка полом рассказчика не считается")
    func ignoresOtherPeople() {
        #expect(Narrator.gender(of: EnglishCleaner.clean("My wife (28F) got mad")) == nil)
        #expect(Narrator.gender(of: "My husband and my sister were there") == nil)
    }
}
