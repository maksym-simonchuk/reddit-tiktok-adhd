import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Formatting")
struct FormattingTests {

    @Test("длительность в секундах")
    func secondsOnly() {
        #expect(Formatting.duration(0) == "0s")
        #expect(Formatting.duration(45) == "45s")
        #expect(Formatting.duration(59.4) == "59s")
    }

    @Test("длительность в минутах")
    func minutes() {
        #expect(Formatting.duration(60) == "1m 0s")
        #expect(Formatting.duration(134) == "2m 14s")
    }

    @Test("длительность в часах")
    func hours() {
        #expect(Formatting.duration(3725) == "1h 2m")
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
        #expect(Formatting.compactCount(24_100) == "24.1k")
        #expect(Formatting.compactCount(1_500_000) == "1.5M")
    }

    @Test("объём файла не бывает отрицательным")
    func fileSizeClampsNegatives() {
        #expect(Formatting.fileSize(-100) == Formatting.fileSize(0))
    }

    @Test("post age reads in hours, days and months")
    func age() {
        let now = Date(timeIntervalSince1970: 1_755_300_000)
        #expect(Formatting.age(of: now.addingTimeInterval(-60), now: now) == "just now")
        #expect(Formatting.age(of: now.addingTimeInterval(-3600 * 5), now: now) == "5h ago")
        #expect(Formatting.age(of: now.addingTimeInterval(-86_400 * 2), now: now) == "2d ago")
        #expect(Formatting.age(of: now.addingTimeInterval(-86_400 * 65), now: now) == "2mo ago")
    }

    @Test("the months-to-years boundary never prints 0y")
    func ageYearBoundary() {
        let now = Date(timeIntervalSince1970: 1_755_300_000)
        // 362 days used to fall between the buckets and print "0y ago"; it is
        // 12 thirty-day months, so it reads as a year now.
        #expect(Formatting.age(of: now.addingTimeInterval(-86_400 * 362), now: now) == "1y ago")
        #expect(Formatting.age(of: now.addingTimeInterval(-86_400 * 350), now: now) == "11mo ago")
        #expect(Formatting.age(of: now.addingTimeInterval(-86_400 * 800), now: now) == "2y ago")
    }
}
