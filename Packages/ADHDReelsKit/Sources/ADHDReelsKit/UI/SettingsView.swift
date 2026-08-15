import SwiftUI

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "slider.horizontal.3",
                title: "Настройка появится дальше",
                message: "Источники, голос, стиль субтитров и футаж.",
                action: nil
            )
            .background(Theme.background)
            .navigationTitle("Настройка")
        }
    }
}

#Preview {
    SettingsView()
}
