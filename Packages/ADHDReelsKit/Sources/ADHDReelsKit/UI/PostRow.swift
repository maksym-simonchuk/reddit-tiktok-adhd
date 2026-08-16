import SwiftUI

/// Карточка треда в ленте: заголовок, метрики, оценка виральности и две кнопки —
/// собрать ролик или открыть историю на вычитку.
struct PostRow: View {

    let post: RedditPost
    let targetDuration: Double
    let language: ReelLanguage
    let isBuilding: Bool
    let isBlocked: Bool
    let onGenerate: () -> Void
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing * 1.5) {
            HStack(spacing: Theme.spacing) {
                Text("r/\(post.subreddit)")
                    .font(Theme.numeric(12))
                    .foregroundStyle(Theme.secondaryText)

                Spacer()

                viralityBadge
            }

            Text(post.title)
                .font(Theme.body(17))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(3)

            if !post.selftext.isEmpty {
                Text(post.selftext)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(2)
            }

            HStack(spacing: Theme.spacing * 2) {
                // В RSS-ленте рейтинга нет, и нуль вместо него сбивает с толку.
                if post.score > 0 {
                    Label(Formatting.compactCount(post.score), systemImage: "arrow.up")
                }
                if let comments = post.numComments {
                    Label(Formatting.compactCount(comments), systemImage: "bubble.right")
                }
                if let created = post.createdAt {
                    Label(Formatting.age(of: created), systemImage: "clock")
                }
                Label("~\(Formatting.duration(estimatedDuration))", systemImage: "timer")
            }
            .font(Theme.numeric(13))
            .foregroundStyle(Theme.secondaryText)

            HStack(spacing: Theme.spacing) {
                Button(action: onGenerate) {
                    HStack(spacing: Theme.spacing) {
                        if isBuilding {
                            ProgressView().controlSize(.small).tint(Theme.background)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text(isBuilding ? "Generating" : "Generate Video")
                    }
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.minimumHitTarget)
                    .background(isBlocked && !isBuilding ? Theme.tertiaryText : Theme.accent, in: .capsule)
                }
                // Без своего стиля List считает всю строку одной кнопкой: тап по лупе
                // запускал сборку ролика.
                .buttonStyle(.plain)
                .disabled(isBlocked)

                Button(action: onPreview) {
                    Image(systemName: "text.magnifyingglass")
                        .font(Theme.body(15))
                        .foregroundStyle(isBlocked ? Theme.tertiaryText : Theme.primaryText)
                        .frame(width: Theme.minimumHitTarget, height: Theme.minimumHitTarget)
                        .background(Theme.separator, in: .capsule)
                }
                .disabled(isBlocked)
                .accessibilityLabel("Preview story")
            }
        }
        .padding(Theme.spacing * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }

    /// Сколько будет длиться ролик из этого поста — до обрезки под целевую длительность.
    private var estimatedDuration: Double {
        min(targetDuration, Double(post.wordCount) / Script.wordsPerSecond(for: language))
    }

    @ViewBuilder
    private var viralityBadge: some View {
        // RSS-ленте нечем оценивать виральность: без рейтинга и комментариев любой
        // пост навсегда «Low signal», и такая оценка только вводит в заблуждение.
        if post.score > 0 || post.numComments != nil {
            let score = ViralityScore.score(for: post, targetDuration: targetDuration, language: language)
            HStack(spacing: 4) {
                Image(systemName: ViralityScore.isRecommended(score) ? "flame.fill" : "flame")
                Text("\(score)")
            }
            .font(Theme.numeric(12))
            .foregroundStyle(ViralityScore.isRecommended(score) ? Theme.accent : Theme.tertiaryText)
            .accessibilityLabel("Virality \(score): \(ViralityScore.label(score))")
        }
    }
}

#Preview {
    PostRow(
        post: RedditPost(
            id: "1",
            subreddit: "TrueOffMyChest",
            title: "I kept quiet for twelve years, then told everything over one dinner",
            selftext: String(repeating: "words ", count: 200),
            score: 24100,
            isNSFW: false,
            permalink: "/r/TrueOffMyChest/comments/1/",
            numComments: 1830,
            createdAt: Date(timeIntervalSinceNow: -3600 * 18)
        ),
        targetDuration: 45,
        language: .english,
        isBuilding: false,
        isBlocked: false,
        onGenerate: {},
        onPreview: {}
    )
    .padding()
    .background(Theme.background)
}
