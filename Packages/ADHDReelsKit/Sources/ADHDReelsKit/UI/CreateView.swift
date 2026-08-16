import SwiftUI

/// The generation hub: whatever the pipeline is doing right now, full screen.
/// Building → step checklist; failed → retry card; done → open the result;
/// idle → the road starts in Discover, so the one button leads there.
struct CreateView: View {

    let onOpenDiscover: () -> Void
    let onShowReel: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(Theme.background)
                .navigationTitle("Create")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let progress = model.progress {
            VStack(spacing: Theme.spacing * 2) {
                Text("Making your Short")
                    .font(Theme.title(22))
                    .foregroundStyle(Theme.primaryText)

                BuildBanner(
                    progress: progress,
                    language: model.settings.language,
                    onCancel: model.cancelBuild
                )
            }
            .padding(Theme.spacing * 3)
        } else if model.failedJob != nil {
            failedCard
        } else if let reel = model.lastCreated {
            readyCard(reel)
        } else {
            EmptyStateView(
                icon: "wand.and.stars",
                title: "Create a Short",
                message: "Pick a trending story in Discover — it becomes a ready-to-post vertical video.",
                action: .init(title: "Open Discover", handler: onOpenDiscover)
            )
        }
    }

    private var failedCard: some View {
        VStack(spacing: Theme.spacing * 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.danger)

            Text("Generation failed")
                .font(Theme.title(20))
                .foregroundStyle(Theme.primaryText)

            Text(model.failedReason ?? "Something went wrong along the way.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: Theme.spacing * 1.5) {
                Button(action: model.retryFailed) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.background)
                        .padding(.horizontal, Theme.spacing * 3)
                        .frame(height: Theme.minimumHitTarget)
                        .background(Theme.accent, in: .capsule)
                }

                Button(action: model.dismissFailed) {
                    Text("Dismiss")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.horizontal, Theme.spacing * 3)
                        .frame(height: Theme.minimumHitTarget)
                        .background(Theme.panel, in: .capsule)
                        .overlay { Capsule().strokeBorder(Theme.separator, lineWidth: 1) }
                }
            }
        }
        .padding(Theme.spacing * 4)
    }

    private func readyCard(_ reel: Reel) -> some View {
        VStack(spacing: Theme.spacing * 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.success)

            Text("Your Short is ready")
                .font(Theme.title(20))
                .foregroundStyle(Theme.primaryText)

            Text("\(reel.title) · \(Formatting.duration(reel.duration))")
                .font(Theme.body(15))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: onShowReel) {
                Label("Watch", systemImage: "play.fill")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, Theme.spacing * 3)
                    .frame(height: Theme.minimumHitTarget)
                    .background(Theme.accent, in: .capsule)
            }
        }
        .padding(Theme.spacing * 4)
    }
}

#Preview {
    CreateView(onOpenDiscover: {}, onShowReel: {})
        .environment(AppModel())
}
