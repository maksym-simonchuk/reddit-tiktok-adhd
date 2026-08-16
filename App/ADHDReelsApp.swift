import SwiftUI
import ADHDReelsKit

@main
struct ADHDReelsApp: App {

    @Environment(\.scenePhase) private var phase
    @State private var model: AppModel

    /// Обработчик фоновой сборки регистрируется здесь, а не в экране: система
    /// требует его до конца запуска, когда никаких экранов ещё нет.
    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        BackgroundRender.register(model)
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .onChange(of: phase, initial: true) { _, phase in
            switch phase {
            case .active: model.resume()
            case .background: BackgroundRender.schedule()
            default: break
            }
        }
    }
}
