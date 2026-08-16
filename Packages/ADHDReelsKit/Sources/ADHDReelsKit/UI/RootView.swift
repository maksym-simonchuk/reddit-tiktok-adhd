import SwiftUI
import Translation

public struct RootView: View {

    /// Модель приходит снаружи: её же держит `@main`, потому что фоновую сборку
    /// система приносит в приложение, а не в экран.
    private let model: AppModel

    @State private var selection: AppTab = .feed

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        @Bindable var model = model

        return TabView(selection: $selection) {
            Tab("Треды", systemImage: "text.bubble.fill", value: AppTab.feed) {
                FeedView(onShowReel: { selection = .reels })
            }
            Tab("Ролики", systemImage: "play.rectangle.fill", value: AppTab.reels) {
                ReelsView()
            }
            Tab("Настройка", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .environment(model)
        .overlay(alignment: .bottom) {
            ToastView(text: model.toast)
                .padding(.bottom, Theme.spacing * 10)
        }
        .alert("Не получилось", isPresented: .constant(model.error != nil)) {
            Button("Понятно") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .alert("Нужен языковой пакет", isPresented: $model.needsTranslationPack) {
            Button("Скачать") { model.downloadTranslationPack() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("""
                Перевод идёт на устройстве и качается отдельно от языка системы \
                и клавиатуры. Ставится один раз, около 300 МБ.
                """)
        }
        .translationTask(model.translationRequest) { session in
            // Скачивание показывает системный лист, своего прогресса не нужно.
            // SwiftUI отдаёт сессию на главном акторе, а качает она nonisolated-методом,
            // и сессия не Sendable. За пределы замыкания она не уходит — этого хватает.
            nonisolated(unsafe) let download = session
            let failure: String?
            do {
                try await download.prepareTranslation()
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
            await model.finishTranslationPack(failure)
        }
        .task(id: model.toast) {
            guard model.toast != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            model.toast = nil
        }
    }
}

#Preview {
    RootView(model: AppModel())
}
