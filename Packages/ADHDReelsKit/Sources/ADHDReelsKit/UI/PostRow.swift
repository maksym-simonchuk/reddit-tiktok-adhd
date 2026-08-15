import SwiftUI

/// Строка ленты: заголовок треда и одна кнопка, которая делает из него ролик.
struct PostRow: View {

    let post: RedditPost
    let isBuilding: Bool
    let isBlocked: Bool
    let onGenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing * 1.5) {
            Text(post.title)
                .font(Theme.body(17))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(3)

            HStack(spacing: Theme.spacing * 2) {
                // В RSS-ленте рейтинга нет, и нуль вместо него сбивает с толку.
                if post.score > 0 {
                    Label(Formatting.compactCount(post.score), systemImage: "arrow.up")
                }
                Label("\(post.wordCount) слов", systemImage: "text.alignleft")
            }
            .font(Theme.numeric(13))
            .foregroundStyle(Theme.secondaryText)

            Button(action: onGenerate) {
                HStack(spacing: Theme.spacing) {
                    if isBuilding {
                        ProgressView().controlSize(.small).tint(Theme.background)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isBuilding ? "Собираю" : "Сделать ролик")
                }
                .font(Theme.body(15))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.minimumHitTarget)
                .background(isBlocked && !isBuilding ? Theme.tertiaryText : Theme.accent, in: .capsule)
            }
            .disabled(isBlocked)
        }
        .padding(Theme.spacing * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

#Preview {
    PostRow(
        post: RedditPost(
            id: "1",
            subreddit: "TrueOffMyChest",
            title: "Я двенадцать лет молчал, а вчера всё рассказал за одним ужином",
            selftext: String(repeating: "текст ", count: 200),
            score: 24100,
            isNSFW: false,
            permalink: "/r/TrueOffMyChest/comments/1/"
        ),
        isBuilding: false,
        isBlocked: false,
        onGenerate: {}
    )
    .padding()
    .background(Theme.background)
}
