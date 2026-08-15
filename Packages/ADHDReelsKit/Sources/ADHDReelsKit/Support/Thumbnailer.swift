import AVFoundation
import UIKit

/// Кадр для превью в списке. Берётся не с нуля: в первую секунду ещё нет субтитров,
/// и все ролики выглядят одинаково.
public enum Thumbnailer {

    public static func image(for url: URL, height: CGFloat = 480) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: height * 9 / 16, height: height)

        let frame = try? await generator.image(at: CMTime(seconds: 2, preferredTimescale: 600))
        return frame.map { UIImage(cgImage: $0.image) }
    }
}
