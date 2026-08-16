import Foundation

/// Четыре вкладки — вся навигация приложения. Вложенных меню нет.
/// Имя с префиксом, чтобы не затенять `SwiftUI.Tab`.
enum AppTab: Hashable {
    case discover
    case projects
    case create
    case settings
}
