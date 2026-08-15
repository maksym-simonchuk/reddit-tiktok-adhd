import SwiftUI

public struct RootView: View {

    @State private var model = AppModel()
    @State private var selection: AppTab = .feed

    public init() {}

    public var body: some View {
        TabView(selection: $selection) {
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
        .task(id: model.toast) {
            guard model.toast != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            model.toast = nil
        }
    }
}

#Preview {
    RootView()
}
