import SwiftUI

/// Обложка ролика, а если её нет — кадр из видео. Пока картинка достаётся, панель
/// того же размера, чтобы список не прыгал при прокрутке.
struct ReelThumbnail: View {

    let reel: Reel

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Theme.panel
            }
        }
        .clipShape(.rect(cornerRadius: Theme.spacing))
        .task(id: reel.id) { image = await preview(of: reel) }
    }

    /// Ролики, собранные до появления обложек, остаются с кадром — пересобирать их
    /// ради картинки в списке незачем.
    private func preview(of reel: Reel) async -> UIImage? {
        if let data = try? Data(contentsOf: reel.coverURL), let cover = UIImage(data: data) {
            return cover
        }
        return await Thumbnailer.image(for: reel.url)
    }
}
