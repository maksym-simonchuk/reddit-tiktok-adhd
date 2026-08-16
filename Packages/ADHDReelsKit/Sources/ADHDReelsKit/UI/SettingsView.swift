import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @Environment(AppModel.self) private var model
    @State private var isImporting = false
    @State private var audition = VoiceAudition()
    @State private var elevenLabsKey = ""

    /// The speeds worth offering: below 0.9 narration drags, above 1.25 it swallows
    /// word endings.
    private static let voiceSpeeds: [Double] = [0.9, 1.0, 1.1, 1.25]

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                Section {
                    LabeledContent("Duration", value: Formatting.duration(model.settings.targetDuration))
                    Slider(value: $model.settings.targetDuration, in: 20...90, step: 5)
                        .tint(Theme.accent)

                    Stepper(
                        "Score from \(Formatting.compactCount(model.settings.minimumScore))",
                        value: $model.settings.minimumScore,
                        in: 0...20_000,
                        step: 250
                    )

                    Toggle("Safe content only", isOn: $model.settings.safeContentOnly)
                        .tint(Theme.accent)
                } header: {
                    Text("Video")
                } footer: {
                    Text("Safe mode hides NSFW posts and stories with content platforms demonetize.")
                }

                Section {
                    Picker("Language", selection: $model.settings.language) {
                        ForEach(ReelLanguage.allCases) { Text($0.title).tag($0) }
                    }

                    Toggle("ElevenLabs voice", isOn: $model.settings.useElevenLabs)
                        .tint(Theme.accent)
                        .disabled(elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if model.settings.useElevenLabs {
                        Picker("Narrator", selection: Binding(
                            get: { model.settings.elevenLabsVoiceID ?? ElevenLabsSpeechEngine.defaultVoice },
                            set: { model.settings.elevenLabsVoiceID = $0 }
                        )) {
                            ForEach(ElevenLabsSpeechEngine.voices) { voice in
                                Text(voice.title).tag(voice.id)
                            }
                        }
                    } else {
                        Picker("Voice", selection: $model.settings.voiceIdentifier) {
                            Text("Best available").tag(String?.none)
                            ForEach(neuralVoices) { voice in
                                Text(voice.title).tag(String?.some(voice.id))
                            }
                            ForEach(systemVoices, id: \.identifier) { voice in
                                Text("\(voice.name) · system").tag(String?.some(voice.identifier))
                            }
                        }
                    }

                    Picker("Speed", selection: $model.settings.voiceSpeed) {
                        ForEach(Self.voiceSpeeds, id: \.self) { speed in
                            Text(speed == 1 ? "Normal" : String(format: "%.2g×", speed)).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        Task {
                            do {
                                try await audition.play(settings: model.settings)
                            } catch {
                                model.error = error.localizedDescription
                            }
                        }
                    } label: {
                        if audition.isBusy {
                            LabeledContent("Preparing sample") { ProgressView() }
                        } else {
                            Label("Listen", systemImage: "play.circle")
                        }
                    }
                    .disabled(audition.isBusy)

                    SecureField("ElevenLabs API key", text: $elevenLabsKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: elevenLabsKey) {
                            // Пустое поле по ходу набора — это редактирование, а не
                            // решение расстаться с ключом: удаляет только кнопка ниже.
                            let trimmed = elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { model.saveElevenLabsKey(trimmed) }
                        }

                    if !elevenLabsKey.isEmpty {
                        Button("Remove key", role: .destructive) {
                            elevenLabsKey = ""
                            model.saveElevenLabsKey("")
                        }
                    }

                    if !model.settings.useElevenLabs, neuralVoices.isEmpty, systemVoices.isEmpty {
                        Text("No voices for this language. Settings → Accessibility → Spoken Content → Voices.")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.danger)
                    }
                } header: {
                    Text("Narration")
                } footer: {
                    Text(narrationFooter)
                }

                Section("Captions") {
                    Picker("Style", selection: $model.settings.caption.preset) {
                        ForEach(CaptionTheme.Preset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(model.settings.caption.preset.subtitle)
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.secondaryText)

                    // Classic and Minimal render the active word in white — a color
                    // picker there would change nothing, so it only shows when it works.
                    if model.settings.caption.preset.usesHighlightColor {
                        Picker("Highlight", selection: $model.settings.caption.highlight) {
                            ForEach(CaptionTheme.Highlight.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    LabeledContent("Font size", value: "\(Int(model.settings.caption.fontSize))")
                    Slider(value: $model.settings.caption.fontSize, in: 72...136, step: 4)
                        .tint(Theme.accent)
                    Toggle("Uppercase", isOn: $model.settings.caption.uppercase)
                        .tint(Theme.accent)
                }

                Section {
                    ForEach(model.clips) { clip in
                        LabeledContent(clip.id) {
                            Text("\(Formatting.duration(clip.duration)) · \(Formatting.fileSize(clip.bytes))")
                                .font(Theme.numeric(12))
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                Task { await model.deleteGameplay(clip) }
                            }
                        }
                    }

                    Button("Add video", systemImage: "plus") { isImporting = true }
                } header: {
                    Text("Background gameplay")
                } footer: {
                    Text(model.clips.isEmpty
                         ? "A Short needs background footage. Copy vertical mp4 files into the app folder via Files, or add them here. Use only footage you have the rights to."
                         : "Footage \(Formatting.fileSize(model.clips.reduce(0) { $0 + $1.bytes })), videos \(Formatting.fileSize(model.store.diskUsage())). Use only footage you have the rights to.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
        }
        .tint(Theme.accent)
        .task {
            elevenLabsKey = model.elevenLabsKey()
            // Ключ могли стереть в обход приложения (сброс связки ключей) —
            // включённый тумблер без ключа обещает то, чего движок не сделает.
            if elevenLabsKey.isEmpty { model.settings.useElevenLabs = false }
            await model.refreshGameplay()
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            Task { await model.importGameplay(urls) }
        }
    }

    /// The ElevenLabs path sends the story to their cloud — that data flow is stated
    /// where the switch lives, not buried in a manual.
    private var narrationFooter: String {
        if model.settings.useElevenLabs {
            return "Narration is generated by ElevenLabs — the story text is sent to their servers."
        }
        return model.settings.language == .english
            ? "English narrates the post as written — no translation step."
            : "The story is translated to the selected language on this phone."
    }

    /// Нейросетевой диктор у нас только русский: на других языках список пустой,
    /// и в выборе остаются системные голоса.
    private var neuralVoices: [VoskSpeechEngine.Voice] {
        model.settings.language == .russian ? VoskSpeechEngine.voices() : []
    }

    private var systemVoices: [AVSpeechSynthesisVoice] {
        SystemSpeechEngine.voices(for: model.settings.language)
    }
}

#Preview {
    SettingsView().environment(AppModel())
}
