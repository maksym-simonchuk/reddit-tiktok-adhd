import SwiftUI

/// Строка списка готовых роликов: кадр, заголовок из описания и длительность.
struct ReelRow: View {

    let reel: Reel

    var body: some View {
        HStack(spacing: Theme.spacing * 1.5) {
            ReelThumbnail(reel: reel)
                .frame(width: 54, height: 96)

            VStack(alignment: .leading, spacing: Theme.spacing / 2) {
                Text(reel.title)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)

                Text("r/\(reel.subreddit) · \(Formatting.duration(reel.duration))")
                    .font(Theme.numeric(13))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.vertical, Theme.spacing)
    }
}

#Preview {
    ReelRow(
        reel: Reel(
            title: "Двенадцать лет молчания",
            subreddit: "TrueOffMyChest",
            permalink: "/r/x/1/",
            fileName: "a.mp4",
            duration: 47,
            description: ReelDescription(title: "Двенадцать лет молчания", body: "", tags: [])
        )
    )
    .padding()
    .background(Theme.background)
}
