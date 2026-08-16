import BackgroundTasks

/// Сборка, которая продолжается после того, как приложение свернули. Свёрнутому
/// приложению система даёт секунды, а `BGProcessingTask` — минуты, но по своему
/// расписанию: чаще всего ночью, на зарядке и по Wi-Fi.
///
/// Дать время — не значит дать всё: задачу забирают в любой момент, а видео и
/// перевод считает видеокарта, к которой фоновому процессу доступа может не быть.
/// Поэтому неудача здесь ничего не ломает: работа остаётся в `RenderJob`, и её
/// доделает либо следующее пробуждение, либо открытое приложение.
public enum BackgroundRender {

    public static let identifier = "com.local.adhdreels.render"

    /// Регистрировать обязательно до конца запуска: если система принесёт задачу,
    /// а обработчика нет, она уронит приложение.
    @MainActor
    public static func register(_ model: AppModel) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            // BGTask не Sendable, но живёт ровно столько, сколько выполняется задача,
            // и трогаем мы его только отсюда.
            nonisolated(unsafe) let task = task

            let work = Task { @MainActor in
                await model.renderInBackground()
                // Не успели — работа осталась в файле, просим разбудить ещё раз.
                schedule()
                task.setTaskCompleted(success: RenderJob.saved() == nil)
            }

            task.expirationHandler = { work.cancel() }
        }
    }

    /// Просить систему заранее незачем: пока приложение на экране, оно и так считает.
    public static func schedule() {
        guard RenderJob.saved() != nil else { return }

        // Сеть не нужна: тред уже скачан, а перевод, озвучка и монтаж считают на
        // устройстве. Такую задачу система даёт раньше.
        try? BGTaskScheduler.shared.submit(BGProcessingTaskRequest(identifier: identifier))
    }
}
