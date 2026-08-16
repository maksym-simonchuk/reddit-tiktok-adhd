import SwiftUI

/// Story detail before the build: the exact narration text, editable line by line.
/// The pencil opens a line as a text field; on Russian narration, tapping wrong words
/// and hitting Fix makes the model retranslate the sentence. The wand retells the
/// whole story punchier, and Generate sends what's on screen straight to the pipeline.
struct ScriptPreviewView: View {

    let thread: String
    let lines: [TranslatedLine]
    let markedLine: Int?
    let markedWords: Set<Int>
    let fixingLine: Int?
    let isRewriting: Bool
    let onMark: (TranslatedLine, Int) -> Void
    let onFix: () -> Void
    let onEdit: (TranslatedLine, String) -> Void
    let onEngage: () -> Void
    let onGenerate: () -> Void
    let onClose: () -> Void

    @State private var editingLine: Int?
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Group {
                if lines.isEmpty {
                    VStack(spacing: Theme.spacing * 2) {
                        ProgressView().tint(Theme.accent)
                        Text("Preparing the script")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(lines) { line in
                        VStack(alignment: .leading, spacing: Theme.spacing) {
                            if editingLine == line.id {
                                TextField("Text", text: $draft, axis: .vertical)
                                    .font(Theme.body(17))
                                    .foregroundStyle(Theme.primaryText)
                                    .textInputAutocapitalization(.sentences)

                                Text(line.caption)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.tertiaryText)

                                HStack(spacing: Theme.spacing * 2) {
                                    Button("Save") {
                                        onEdit(line, draft)
                                        editingLine = nil
                                    }
                                    .foregroundStyle(Theme.accent)

                                    Button("Cancel") { editingLine = nil }
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                .font(Theme.body(14))
                                .buttonStyle(.plain)
                                .frame(height: Theme.minimumHitTarget)
                            } else {
                                FlowLayout(spacing: 4) {
                                    ForEach(Array(line.words.enumerated()), id: \.offset) { index, word in
                                        Button { onMark(line, index) } label: {
                                            Text(word)
                                                .font(Theme.body(17))
                                                .foregroundStyle(isMarked(line, index) ? Theme.background : Theme.primaryText)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(
                                                    isMarked(line, index) ? Theme.accent : .clear,
                                                    in: .rect(cornerRadius: 6)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .opacity(fixingLine == line.id || isRewriting ? 0.4 : 1)

                                Text(line.caption)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.tertiaryText)

                                HStack(spacing: Theme.spacing * 2) {
                                    if fixingLine == line.id {
                                        Label { Text("Rewriting") } icon: { ProgressView().controlSize(.small) }
                                            .font(Theme.body(14))
                                            .foregroundStyle(Theme.secondaryText)
                                    } else if markedLine == line.id {
                                        Button(action: onFix) {
                                            Label("Fix", systemImage: "arrow.trianglehead.counterclockwise")
                                                .font(Theme.body(14))
                                                .foregroundStyle(Theme.background)
                                                .padding(.horizontal, Theme.spacing * 2)
                                                .frame(height: Theme.minimumHitTarget)
                                                .background(Theme.accent, in: .capsule)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Spacer()

                                    Button {
                                        draft = line.translation
                                        editingLine = line.id
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(Theme.body(15))
                                            .foregroundStyle(Theme.primaryText)
                                            .frame(width: Theme.minimumHitTarget, height: Theme.minimumHitTarget)
                                            .background(Theme.separator, in: .capsule)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Edit by hand")
                                }
                                .frame(height: Theme.minimumHitTarget)
                            }
                        }
                        .padding(Theme.spacing * 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .panel()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: Theme.spacing / 2, leading: Theme.spacing * 2, bottom: Theme.spacing / 2, trailing: Theme.spacing * 2))
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .bottom) { generateBar }
                }
            }
            .background(Theme.background)
            .navigationTitle(thread)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onEngage()
                    } label: {
                        if isRewriting {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                    }
                    .disabled(lines.isEmpty || isRewriting)
                    .accessibilityLabel("Make this more engaging for Shorts")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                }
            }
        }
    }

    /// The reviewed text goes straight into the build — no second trip to the feed.
    private var generateBar: some View {
        Button(action: onGenerate) {
            Label("Generate Video", systemImage: "wand.and.stars")
                .font(Theme.body(16))
                .foregroundStyle(Theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.minimumHitTarget)
                .background(isRewriting ? Theme.tertiaryText : Theme.accent, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(isRewriting)
        .padding(Theme.spacing * 2)
        .background(Theme.background.opacity(0.94))
    }

    private func isMarked(_ line: TranslatedLine, _ word: Int) -> Bool {
        markedLine == line.id && markedWords.contains(word)
    }
}

#Preview {
    ScriptPreviewView(
        thread: "AITA for refusing to pay my brother's rent?",
        lines: [
            TranslatedLine(
                id: 0,
                kind: .hook,
                source: "",
                translation: "He begged me to cover his rent — I said one word."
            ),
            TranslatedLine(
                id: 1,
                kind: .body,
                source: "He is a grown man and made his own choices.",
                translation: "He is a grown man and made his own choices."
            ),
        ],
        markedLine: nil,
        markedWords: [],
        fixingLine: nil,
        isRewriting: false,
        onMark: { _, _ in },
        onFix: {},
        onEdit: { _, _ in },
        onEngage: {},
        onGenerate: {},
        onClose: {}
    )
}
