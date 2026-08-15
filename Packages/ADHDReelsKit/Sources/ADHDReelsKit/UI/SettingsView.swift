import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(AppModel.self) private var model
    @State private var isImporting = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section("Ролик") {
                    LabeledContent("Длительность", value: Formatting.duration(model.settings.targetDuration))
                    Slider(value: $model.settings.targetDuration, in: 20...90, step: 5)
                        .tint(Theme.accent)

                    Stepper(
                        "Рейтинг от \(Formatting.compactCount(model.settings.minimumScore))",
                        value: $model.settings.minimumScore,
                        in: 0...20_000,
                        step: 250
                    )
                }

                Section("Голос") {
                    Picker("Голос", selection: $model.settings.voiceIdentifier) {
                        Text("Лучший из доступных").tag(String?.none)
                        ForEach(PiperSpeechEngine.voices()) { voice in
                            Text("\(voice.title) · нейросеть").tag(String?.some(voice.id))
                        }
                        ForEach(SystemSpeechEngine.russianVoices(), id: \.identifier) { voice in
                            Text(voice.name).tag(String?.some(voice.identifier))
                        }
                    }
                    if PiperSpeechEngine.voices().isEmpty, SystemSpeechEngine.russianVoices().isEmpty {
                        Text("Русских голосов нет. Настройки → Универсальный доступ → Устный контент → Голоса.")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.danger)
                    }
                }

                Section("Субтитры") {
                    Picker("Подсветка", selection: $model.settings.caption.highlight) {
                        ForEach(CaptionTheme.Highlight.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Кегль", value: "\(Int(model.settings.caption.fontSize))")
                    Slider(value: $model.settings.caption.fontSize, in: 72...136, step: 4)
                        .tint(Theme.accent)
                    Toggle("Заглавными", isOn: $model.settings.caption.uppercase)
                        .tint(Theme.accent)
                }

                Section {
                    ForEach(model.clips) { clip in
                        LabeledContent(clip.id) {
                            Text("\(Formatting.duration(clip.duration)) · \(Formatting.fileSize(clip.bytes))")
                                .font(Theme.numeric(12))
                        }
                        .swipeActions {
                            Button("Удалить", role: .destructive) {
                                Task { await model.deleteGameplay(clip) }
                            }
                        }
                    }

                    Button("Добавить видео", systemImage: "plus") { isImporting = true }
                } header: {
                    Text("Геймплей")
                } footer: {
                    Text(model.clips.isEmpty
                         ? "Без фонового видео ролик собрать нельзя. Скопируйте вертикальные mp4 в папку ADHDReels через «Файлы» или добавьте здесь."
                         : "Занято \(Formatting.fileSize(model.clips.reduce(0) { $0 + $1.bytes })), ролики — \(Formatting.fileSize(model.store.diskUsage())).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Настройка")
        }
        .tint(Theme.accent)
        .task { await model.refreshGameplay() }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            Task { await model.importGameplay(urls) }
        }
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
