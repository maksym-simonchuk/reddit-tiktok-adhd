import Foundation

/// Доводка дорожки перед монтажом. Сырой синтез тише и площе любой записи из ленты,
/// и рядом с чужими роликами это слышно раньше, чем сам голос: срезаем гул, прижимаем
/// перепады и выводим громкость к той, к которой площадки приводят всё остальное.
enum AudioMaster {

    /// Компрессор: с какого уровня начинаем прижимать и во сколько раз. Мягко —
    /// задача не выровнять всё в кирпич, а убрать провалы между фразами.
    private static let threshold: Float = -18
    private static let ratio: Float = 3

    /// Средняя громкость и потолок пика в dBFS. −14 LUFS — то, к чему приводят дорожку
    /// TikTok и YouTube; громче они всё равно прижмут сами, а клиппинг останется.
    private static let target: Float = -14
    private static let ceiling: Float = -1

    static func polish(_ samples: [Float], rate: Double) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var output = highPass(samples, rate: rate, cutoff: 80)
        compress(&output, rate: rate)
        normalize(&output)
        return output
    }

    /// Ниже восьмидесяти герц голоса нет, а гул и дыхание модели есть.
    private static func highPass(_ samples: [Float], rate: Double, cutoff: Double) -> [Float] {
        let w = 2 * Double.pi * cutoff / rate
        let alpha = sin(w) / (2 * 0.707)
        let cosine = cos(w)
        let a0 = 1 + alpha

        let b0 = (1 + cosine) / 2 / a0
        let b1 = -(1 + cosine) / a0
        let a1 = -2 * cosine / a0
        let a2 = (1 - alpha) / a0

        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        return samples.map { sample in
            let x = Double(sample)
            let y = b0 * x + b1 * x1 + b0 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return Float(y)
        }
    }

    private static func compress(_ samples: inout [Float], rate: Double) {
        let attack = coefficient(seconds: 0.005, rate: rate)
        let release = coefficient(seconds: 0.12, rate: rate)
        var envelope: Float = 0

        for index in samples.indices {
            // Атака короткая, отпускание длинное: иначе компрессор дышит между словами.
            let level = abs(samples[index])
            let coefficient = level > envelope ? attack : release
            envelope = coefficient * envelope + (1 - coefficient) * level

            let loudness = decibels(envelope)
            guard loudness > threshold else { continue }
            samples[index] *= amplitude(-(loudness - threshold) * (1 - 1 / ratio))
        }
    }

    private static func normalize(_ samples: inout [Float]) {
        let square = samples.reduce(0.0) { $0 + Double($1) * Double($1) }
        let rms = Float((square / Double(samples.count)).squareRoot())
        let peak = samples.reduce(0) { max($0, abs($1)) }
        guard rms > 0, peak > 0 else { return }

        // Громкость ведём по среднему, но пик держим под потолком: клиппинг слышно
        // сразу, а недобор громкости площадка вытянет сама.
        let gain = min(amplitude(target) / rms, amplitude(ceiling) / peak)
        for index in samples.indices { samples[index] *= gain }
    }

    private static func coefficient(seconds: Double, rate: Double) -> Float {
        Float(exp(-1 / (seconds * rate)))
    }

    private static func decibels(_ value: Float) -> Float {
        20 * log10(max(value, 1e-6))
    }

    private static func amplitude(_ value: Float) -> Float {
        pow(10, value / 20)
    }
}
