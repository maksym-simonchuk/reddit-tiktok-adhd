import SwiftUI

/// Ролик собран. Единственное разумное следующее действие — посмотреть его,
/// поэтому кнопка одна и она ведёт прямо в превью.
struct ReadyBanner: View {

    let reel: Reel
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: Theme.spacing * 1.5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ролик готов")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.primaryText)
                    Text(Formatting.duration(reel.duration))
                        .font(Theme.numeric(13))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Text("Смотреть")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, Theme.spacing * 2)
                    .frame(height: 36)
                    .background(Theme.accent, in: .capsule)
            }
            .padding(Theme.spacing * 1.5)
            .panel()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReadyBanner(
        reel: Reel(
            title: "Двенадцать лет молчания",
            subreddit: "TrueOffMyChest",
            permalink: "/r/x/1/",
            fileName: "a.mp4",
            duration: 47,
            description: ReelDescription(title: "Двенадцать лет молчания", body: "", tags: [])
        ),
        onOpen: {}
    )
    .padding()
    .background(Theme.background)
}
