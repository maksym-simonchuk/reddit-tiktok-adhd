import Testing
@testable import ADHDReelsKit

@Suite("Полоска сборки")
struct ReelProgressTests {

    @Test("Веса шагов в сумме дают единицу")
    func weightsSumToOne() {
        let total = ReelStage.allCases.reduce(0) { $0 + $1.weight }
        #expect(abs(total - 1) < 0.0001)
    }

    @Test("Прогресс не убывает по ходу сборки")
    func progressNeverGoesBack() {
        let values = ReelStage.allCases.map { ReelProgress(stage: $0).fraction }

        for (previous, next) in zip(values, values.dropFirst()) {
            #expect(next > previous)
        }
    }

    @Test("Первый шаг стартует с нуля, последний доходит до единицы")
    func spansWholeRange() {
        #expect(ReelProgress(stage: .reading).fraction == 0)
        #expect(abs(ReelProgress(stage: .describing, within: 1).fraction - 1) < 0.0001)
    }

    @Test("Доля внутри шага не выходит за его вес")
    func staysInsideStageWeight() {
        let start = ReelProgress(stage: .rendering, within: 0).fraction
        let end = ReelProgress(stage: .rendering, within: 1).fraction

        #expect(abs(end - start - ReelStage.rendering.weight) < 0.0001)
        #expect(ReelProgress(stage: .rendering, within: 5).fraction == end)
        #expect(ReelProgress(stage: .rendering, within: -5).fraction == start)
    }
}
