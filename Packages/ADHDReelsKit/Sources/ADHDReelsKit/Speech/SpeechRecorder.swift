import AVFoundation
import Foundation

/// Пишет речь синтезатора в WAV и запоминает, на каком сэмпле начиналось каждое слово.
/// Колбэк буферов и делегат приходят с разных потоков — состояние под замком.
final class SpeechRecorder: NSObject, @unchecked Sendable {

    struct Mark {
        let range: NSRange
        let time: Double
    }

    struct Recording {
        let marks: [Mark]
        let duration: Double
    }

    private let lock = NSLock()
    private let synthesizer = AVSpeechSynthesizer()

    private var file: AVAudioFile?
    private var sampleRate: Double = 0
    private var frames: AVAudioFramePosition = 0
    private var marks: [Mark] = []
    private var continuation: CheckedContinuation<Recording, Error>?

    func record(_ utterance: AVSpeechUtterance, to url: URL) async throws -> Recording {
        synthesizer.delegate = self
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { self.continuation = continuation }
            synthesizer.write(utterance) { [weak self] buffer in
                self?.append(buffer, to: url)
            }
        }
    }

    private func append(_ buffer: AVAudioBuffer, to url: URL) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }

        // Пустой буфер — сигнал конца синтеза.
        guard pcm.frameLength > 0 else {
            finish(with: nil)
            return
        }

        do {
            try lock.withLock {
                if file == nil {
                    file = try AVAudioFile(forWriting: url, settings: Self.wavSettings(for: pcm.format))
                    sampleRate = pcm.format.sampleRate
                }
                try file?.write(from: pcm)
                frames += AVAudioFramePosition(pcm.frameLength)
            }
        } catch {
            finish(with: error)
        }
    }

    private func finish(with error: Error?) {
        let result: (CheckedContinuation<Recording, Error>, Recording)? = lock.withLock {
            guard let continuation else { return nil }
            self.continuation = nil
            file = nil
            let duration = sampleRate > 0 ? Double(frames) / sampleRate : 0
            return (continuation, Recording(marks: marks, duration: duration))
        }

        guard let (continuation, recording) = result else { return }
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: recording)
        }
    }

    /// 16-битный PCM: AVFoundation читает такой файл без конвертации на этапе монтажа.
    private static func wavSettings(for format: AVAudioFormat) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
    }
}

extension SpeechRecorder: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        lock.withLock {
            guard sampleRate > 0 else {
                marks.append(Mark(range: characterRange, time: 0))
                return
            }
            marks.append(Mark(range: characterRange, time: Double(frames) / sampleRate))
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish(with: CancellationError())
    }
}
