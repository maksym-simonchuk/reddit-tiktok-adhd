import Foundation
import Observation

/// Список готовых роликов и их файлы. Индекс лежит в JSON рядом с видео, потому что
/// восстановить его из папки нельзя: описание и ссылка на тред в mp4 не помещаются.
@MainActor
@Observable
public final class ReelStore {

    public private(set) var reels: [Reel] = []

    public static var folder: URL {
        URL.documentsDirectory.appending(path: Reel.folderName)
    }

    private static var indexURL: URL {
        folder.appending(path: "index.json")
    }

    public init() {
        load()
    }

    public func add(_ reel: Reel) {
        reels.insert(reel, at: 0)
        save()
    }

    public func delete(_ reel: Reel) {
        try? FileManager.default.removeItem(at: reel.url)
        reels.removeAll { $0.id == reel.id }
        save()
    }

    public func diskUsage() -> Int64 {
        reels.reduce(0) { total, reel in
            let bytes = (try? reel.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(bytes)
        }
    }

    // MARK: - Диск

    /// Записи без файла выбрасываем сразу: строка в списке, которая ничего не открывает,
    /// хуже отсутствующей строки.
    private func load() {
        guard
            let data = try? Data(contentsOf: Self.indexURL),
            let stored = try? JSONDecoder().decode([Reel].self, from: data)
        else { return }

        reels = stored.filter { FileManager.default.fileExists(atPath: $0.url.path(percentEncoded: false)) }
        if reels.count != stored.count { save() }
    }

    private func save() {
        try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(reels) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }
}
