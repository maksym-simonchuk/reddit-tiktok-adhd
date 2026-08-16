import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Разбор ответов Reddit и сборка сценария")
struct ScriptWriterTests {

    // MARK: - Разбор

    @Test("Закреплённые, слабые и NSFW посты отсеиваются")
    func listingFilters() throws {
        let data = Data(RedditFixtures.listing.utf8)
        let posts = try RedditListing.posts(from: data, minimumScore: 500, allowNSFW: false)

        #expect(posts.map(\.id) == ["a1"])
        #expect(posts[0].score == 8400)
        #expect(posts[0].url?.absoluteString == "https://www.reddit.com/r/AskReddit/comments/a1/x/")
    }

    @Test("NSFW возвращается, когда его разрешили")
    func listingAllowsNSFW() throws {
        let data = Data(RedditFixtures.listing.utf8)
        let posts = try RedditListing.posts(from: data, minimumScore: 500, allowNSFW: true)

        #expect(posts.map(\.id) == ["a1", "a4"])
    }

    // MARK: - Черновик

    @Test("Golden: тред из фикстуры превращается в английский черновик")
    func goldenDraft() throws {
        let posts = try RedditListing.posts(from: Data(RedditFixtures.listing.utf8), minimumScore: 500)
        let post = try #require(posts.first)

        let segments = ScriptWriter().draft(from: post)

        // Комментарии в рассказ не идут: это чужие реплики, а ролик — одна история.
        #expect(segments.map(\.kind) == [.hook, .body])
        #expect(segments[0].text == "Am I the asshole for leaving early?")
        #expect(segments[1].text == "My wife, a 28-year-old woman, got mad. I left the party at 9.")
    }

    // MARK: - Финал

    @Test("Golden: русские сегменты нормализуются и укладываются в длительность")
    func goldenFinish() {
        let segments = [
            ScriptSegment(kind: .hook, text: "Я не прав, что ушёл в 21 час?"),
            ScriptSegment(kind: .body, text: "Жена разозлилась, т.к. я ушёл раньше всех 😤"),
            ScriptSegment(kind: .body, text: "90% гостей сделали бы так же"),
        ]

        let script = ScriptWriter().finish(segments)

        #expect(script.segments.map(\.text) == [
            "Я не прав, что ушёл в двадцать один час?",
            "Жена разозлилась, так как я ушёл раньше всех",
            "девяносто процентов гостей сделали бы так же",
        ])
    }

    @Test("Крючок заменяет заголовок треда, а не встаёт перед ним")
    func writtenHook() {
        let segments = [
            ScriptSegment(kind: .hook, text: "Я не прав, что ушёл?"),
            ScriptSegment(kind: .body, text: "Жена разозлилась."),
        ]
        let script = ScriptWriter().finish(segments, hook: "Она молчала об этом 12 лет")

        #expect(script.segments.map(\.kind) == [.hook, .body])
        #expect(script.segments[0].text == "Она молчала об этом двенадцать лет")
    }

    @Test("Без крючка сценарий начинается с заголовка треда")
    func withoutHook() {
        let script = ScriptWriter().finish([ScriptSegment(kind: .hook, text: "Я не прав, что ушёл?")])
        #expect(script.segments.map(\.text) == ["Я не прав, что ушёл?"])
    }

    @Test("Сценарий режется до целевой длительности, а тело урезается, а не выбрасывается")
    func trimming() {
        var options = ScriptWriter.Options()
        options.targetDuration = 5

        let long = Array(repeating: "слово", count: 30).joined(separator: " ")
        let segments = [
            ScriptSegment(kind: .hook, text: "Короткий хук"),
            ScriptSegment(kind: .body, text: long),
            ScriptSegment(kind: .body, text: long),
        ]

        let script = ScriptWriter(options: options).finish(segments)

        #expect(script.segments.map(\.kind) == [.hook, .body])
        #expect(script.estimatedDuration <= 5)
    }

    @Test("Длинное тело занимает почти весь бюджет, а не пропадает")
    func keepsBodyWhenItAloneExceedsBudget() {
        var options = ScriptWriter.Options()
        options.targetDuration = 45

        let body = Array(repeating: "слово", count: 300).joined(separator: " ")
        let script = ScriptWriter(options: options).finish([
            ScriptSegment(kind: .hook, text: "Короткий хук"),
            ScriptSegment(kind: .body, text: body),
        ])

        #expect(script.segments.count == 2)
        #expect(script.estimatedDuration > 40)
        #expect(script.estimatedDuration <= 45)
    }

    @Test("Слишком длинный хук режется по границе предложения")
    func trimsHookOnSentenceBoundary() {
        var options = ScriptWriter.Options()
        // Бюджета хватает ровно на одно предложение.
        options.targetDuration = 1

        let hook = "Первое предложение тут. Второе предложение тоже тут. Третье лишнее."
        let script = ScriptWriter(options: options).finish([ScriptSegment(kind: .hook, text: hook)])

        #expect(script.segments.count == 1)
        #expect(script.segments[0].text == "Первое предложение тут.")
    }

    @Test("Вопрос зрителю встаёт последним и переживает обрезку")
    func writtenOutro() {
        var options = ScriptWriter.Options()
        options.targetDuration = 5

        let long = Array(repeating: "слово", count: 30).joined(separator: " ")
        let script = ScriptWriter(options: options).finish(
            [ScriptSegment(kind: .hook, text: "Короткий хук"), ScriptSegment(kind: .body, text: long)],
            outro: "А ты на чьей стороне?"
        )

        #expect(script.segments.map(\.kind) == [.hook, .body, .outro])
        #expect(script.segments.last?.text == "А ты на чьей стороне?")
        #expect(script.estimatedDuration <= 5)
    }

    @Test("Вопрос из вычитанного текста остаётся последним, а не режется вместе с телом")
    func keepsApprovedOutro() {
        var options = ScriptWriter.Options()
        options.targetDuration = 5

        let long = Array(repeating: "слово", count: 30).joined(separator: " ")
        let script = ScriptWriter(options: options).finish([
            ScriptSegment(kind: .body, text: long),
            ScriptSegment(kind: .outro, text: "А ты бы простил?"),
        ])

        #expect(script.segments.map(\.kind) == [.body, .outro])
        #expect(script.segments.last?.text == "А ты бы простил?")
    }

    @Test("Пустой тред даёт пустой сценарий, а не падение")
    func emptyPost() {
        let post = RedditPost(
            id: "x", subreddit: "s", title: "🔥", selftext: "",
            score: 1, isNSFW: false, permalink: "/x/"
        )

        #expect(ScriptWriter().draft(from: post).isEmpty)
        #expect(ScriptWriter().finish([]).segments.isEmpty)
    }
}
