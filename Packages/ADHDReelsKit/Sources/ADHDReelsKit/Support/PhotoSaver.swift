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

    public static func save(_ url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw Failure.denied }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        } catch {
            throw Failure.save(error.localizedDescription)
        }
    }
}
