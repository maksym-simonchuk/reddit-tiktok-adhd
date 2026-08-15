import Testing
@testable import ADHDReelsKit

@Suite("Formatting")
struct FormattingTests {

    @Test("длительность в секундах")
    func secondsOnly() {
        #expect(Formatting.duration(0) == "0 с")
        #expect(Formatting.duration(45) == "45 с")
        #expect(Formatting.duration(59.4) == "59 с")
    }

    @Test("длительность в минутах")
    func minutes() {
        #expect(Formatting.duration(60) == "1 мин 0 с")
        #expect(Formatting.duration(134) == "2 мин 14 с")
    }

    @Test("длительность в часах")
    func hours() {
        #expect(Formatting.duration(3725) == "1 ч 2 мин")
    }

    @Test("некорректная длительность не роняет вёрстку")
    func invalidDuration() {
        #expect(Formatting.duration(-1) == "—")
        #expect(Formatting.duration(.nan) == "—")
        #expect(Formatting.duration(.infinity) == "—")
    }

    @Test("компактные счётчики Reddit")
    func compactCounts() {
        #expect(Formatting.compactCount(999) == "999")
        #expect(Formatting.compactCount(24_100) == "24,1k")
        #expect(Formatting.compactCount(1_500_000) == "1,5M")
    }

    @Test("объём файла не бывает отрицательным")
    func fileSizeClampsNegatives() {
        #expect(Formatting.fileSize(-100) == Formatting.fileSize(0))
    }
}
