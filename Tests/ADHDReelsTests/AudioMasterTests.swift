import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Доводка звуковой дорожки")
struct AudioMasterTests {

    private let rate = 22050.0

    /// Синус на 200 Гц: голосовой диапазон, фильтр его пропускает.
    private func tone(_ frequency: Double, amplitude: Float, seconds: Double = 1) -> [Float] {
        (0..<Int(rate * seconds)).map {
            amplitude * Float(sin(2 * Double.pi * frequency * Double($0) / rate))
        }
    }

    private func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    @Test("Тихая дорожка выводится к рабочей громкости")
    func liftsQuiet() {
        let quiet = tone(200, amplitude: 0.02)
        let polished = AudioMaster.polish(quiet, rate: rate)

        #expect(polished.count == quiet.count)
        #expect(peak(polished) > peak(quiet) * 4)
    }

    @Test("Пик остаётся под потолком, клиппинга нет")
    func keepsHeadroom() {
        let loud = tone(200, amplitude: 0.95)
        let polished = AudioMaster.polish(loud, rate: rate)

        #expect(peak(polished) <= 0.9)
        #expect(polished.allSatisfy { abs($0) <= 1 })
    }

    @Test("Гул ниже голоса срезается")
    func cutsRumble() {
        let rumble = tone(30, amplitude: 0.5)
        let polished = AudioMaster.polish(rumble, rate: rate)

        // Нормализация тянет остаток вверх, поэтому сравниваем не с входом,
        // а с тем, что выходит из голосового диапазона при той же громкости.
        let voice = AudioMaster.polish(tone(200, amplitude: 0.5), rate: rate)
        #expect(peak(polished) < peak(voice))
    }

    @Test("Пустая дорожка не роняет доводку")
    func empty() {
        #expect(AudioMaster.polish([], rate: rate).isEmpty)
    }
}
