import Photos

/// Сохранение готового ролика в «Фото». Приложение только добавляет — читать чужие
/// фотографии ему незачем, поэтому и разрешение спрашивается частичное, `.addOnly`.
public enum PhotoSaver {

    public enum Failure: LocalizedError, Equatable {
        case denied
        case save(String)

        public var errorDescription: String? {
            switch self {
            case .denied:
                "Нет доступа к «Фото». Настройки → ADHDReels → Фото → Добавление фото."
            case .save(let reason):
                "Не удалось сохранить: \(reason)"
            }
        }
    }

    /// `cover` уезжает в галерею вместе с видео: обложку загружают отдельным файлом,
    /// и искать её потом в файлах приложения — лишний шаг перед публикацией.
    public static func save(_ url: URL, cover: URL? = nil) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }

        let cover = cover.flatMap { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) ? $0 : nil }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
                if let cover {
                    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: cover)
                }
            }
        } catch {
            throw Failure.save(error.localizedDescription)
        }
    }
}
