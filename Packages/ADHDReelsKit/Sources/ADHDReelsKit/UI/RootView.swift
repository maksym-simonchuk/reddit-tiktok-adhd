import SwiftUI
import Translation

public struct RootView: View {

    /// Модель приходит снаружи: её же держит `@main`, потому что фоновую сборку
    /// система приносит в приложение, а не в экран.
    private let model: AppModel

    @State private var selection: AppTab = .discover

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        @Bindable var model = model

        return TabView(selection: $selection) {
            Tab("Discover", systemImage: "flame.fill", value: AppTab.discover) {
                FeedView(onShowReel: { selection = .projects })
            }
            Tab("Projects", systemImage: "play.rectangle.fill", value: AppTab.projects) {
                ReelsView()
            }
            Tab("Create", systemImage: "wand.and.stars", value: AppTab.create) {
                CreateView(
                    onOpenDiscover: { selection = .discover },
                    onShowReel: { selection = .projects }
                )
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) {
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
        .alert("Something went wrong", isPresented: .constant(model.error != nil)) {
            Button("OK") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
        .alert("Language pack needed", isPresented: $model.needsTranslationPack) {
            Button("Download") { model.downloadTranslationPack() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
                Translation runs on device and downloads separately from the system \
                language and keyboard. One-time install, about 300 MB.
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
