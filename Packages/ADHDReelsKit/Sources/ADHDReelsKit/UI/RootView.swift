import SwiftUI

public struct RootView: View {

    @State private var selection: AppTab = .feed

    public init() {}

    public var body: some View {
        TabView(selection: $selection) {
            Tab("Треды", systemImage: "text.bubble.fill", value: AppTab.feed) {
                FeedView(onOpenSettings: { selection = .settings })
            }
            Tab("Очередь", systemImage: "square.stack.3d.down.right.fill", value: AppTab.queue) {
                QueueView(onPickThread: { selection = .feed })
            }
            Tab("Настройка", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootView()
}
