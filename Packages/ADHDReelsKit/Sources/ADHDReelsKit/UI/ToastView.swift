import SwiftUI

/// Короткое подтверждение действия. Ничего не перекрывает и не требует нажатия —
/// «сохранено» и «скопировано» не стоят модального окна.
struct ToastView: View {

    let text: String?

    var body: some View {
        Group {
            if let text {
                Label(text, systemImage: "checkmark.circle.fill")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, Theme.spacing * 2)
                    .frame(height: Theme.minimumHitTarget)
                    .background(.ultraThinMaterial, in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.motion, value: text)
    }
}

#Preview {
    ToastView(text: "Описание скопировано")
}
