import Foundation

/// Три вкладки — вся навигация приложения. Вложенных меню нет.
/// Имя с префиксом, чтобы не затенять `SwiftUI.Tab`.
enum AppTab: Hashable {
    case feed
    case queue
    case settings
}
