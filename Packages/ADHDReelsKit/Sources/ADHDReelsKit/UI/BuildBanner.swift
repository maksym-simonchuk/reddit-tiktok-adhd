import SwiftUI

/// Что сейчас происходит со сборкой. Шаг словами важнее процентов: перевод и синтез
/// идут молча по полминуты, и без подписи это выглядит как зависание.
struct BuildBanner: View {

    let progress: ReelProgress
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing * 2) {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                Text(progress.title)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.primaryText)

                ProgressView(value: progress.fraction)
                    .tint(Theme.accent)
                    .animation(Theme.motion, value: progress.fraction)
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: Theme.minimumHitTarget, height: Theme.minimumHitTarget)
            }
        }
        .padding(.leading, Theme.spacing * 2)
        .panel()
    }
}

#Preview {
    BuildBanner(progress: ReelProgress(stage: .rendering, within: 0.4), onCancel: {})
        .padding()
        .background(Theme.background)
}
