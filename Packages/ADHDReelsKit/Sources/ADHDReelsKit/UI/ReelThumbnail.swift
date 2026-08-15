import SwiftUI

/// Кадр из ролика. Пока кадр достаётся — панель того же размера, чтобы список
/// не прыгал при прокрутке.
struct ReelThumbnail: View {

    let url: URL

    @State private var frame: UIImage?

    var body: some View {
        Group {
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Theme.panel
            }
        }
        .clipShape(.rect(cornerRadius: Theme.spacing))
        .task(id: url) { frame = await Thumbnailer.image(for: url) }
    }
}
