import SwiftUI

/// Что сейчас происходит со сборкой: чек-лист шагов с галочками и общая полоска.
/// Шаги словами важнее процентов: перевод и синтез идут молча по полминуты,
/// и без подписи это выглядит как зависание.
struct BuildBanner: View {

    let progress: ReelProgress
    let language: ReelLanguage
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacing * 2) {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                ForEach(ReelStage.visibleStages(for: language), id: \.self) { stage in
                    stageRow(stage)
                }

                ProgressView(value: progress.fraction)
                    .tint(Theme.accent)
                    .animation(Theme.motion, value: progress.fraction)
                    .padding(.top, Theme.spacing / 2)
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: Theme.minimumHitTarget, height: Theme.minimumHitTarget)
            }
            .accessibilityLabel("Cancel generation")
        }
        .padding([.leading, .vertical], Theme.spacing * 2)
        .panel()
    }

    private func stageRow(_ stage: ReelStage) -> some View {
        HStack(spacing: Theme.spacing) {
            if stage < progress.stage {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
            } else if stage == progress.stage {
                ProgressView().controlSize(.mini).tint(Theme.accent)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(stage.title)
                .font(Theme.body(14))
                .foregroundStyle(stage <= progress.stage ? Theme.primaryText : Theme.tertiaryText)
        }
        .font(.system(size: 14))
        .animation(Theme.motion, value: progress.stage)
    }
}

#Preview {
    BuildBanner(
        progress: ReelProgress(stage: .rendering, within: 0.4),
        language: .english,
        onCancel: {}
    )
    .padding()
    .background(Theme.background)
}
