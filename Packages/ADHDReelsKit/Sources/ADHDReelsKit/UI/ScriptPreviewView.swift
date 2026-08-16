import SwiftUI

/// Вычитка перевода до сборки: русский текст по словам, английский оригинал под ним.
/// Ткнуть в слова, которые переведены неверно, и нажать «Исправить» — модель перепишет
/// предложение, зная, где ошиблась, а пара «было — стало» уедет в отчёт. Карандаш
/// открывает ту же строку в поле ввода: букву проще поправить самому, чем объяснять.
struct ScriptPreviewView: View {

    let thread: String
    let lines: [TranslatedLine]
    let markedLine: Int?
    let markedWords: Set<Int>
    let fixingLine: Int?
    let onMark: (TranslatedLine, Int) -> Void
    let onFix: () -> Void
    let onEdit: (TranslatedLine, String) -> Void
    let onClose: () -> Void

    @State private var editingLine: Int?
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Group {
                if lines.isEmpty {
                    VStack(spacing: Theme.spacing * 2) {
                        ProgressView().tint(Theme.accent)
                        Text("Перевожу")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(lines) { line in
                        VStack(alignment: .leading, spacing: Theme.spacing) {
                            if editingLine == line.id {
                                TextField("Перевод", text: $draft, axis: .vertical)
                                    .font(Theme.body(17))
                                    .foregroundStyle(Theme.primaryText)
                                    .textInputAutocapitalization(.sentences)

                                Text(line.caption)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.tertiaryText)

                                HStack(spacing: Theme.spacing * 2) {
                                    Button("Сохранить") {
                                        onEdit(line, draft)
                                        editingLine = nil
                                    }
                                    .foregroundStyle(Theme.accent)

                                    Button("Отмена") { editingLine = nil }
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
                                .opacity(fixingLine == line.id ? 0.4 : 1)

                                Text(line.caption)
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.tertiaryText)

                                HStack(spacing: Theme.spacing * 2) {
                                    if fixingLine == line.id {
                                        Label { Text("Переписываю") } icon: { ProgressView().controlSize(.small) }
                                            .font(Theme.body(14))
                                            .foregroundStyle(Theme.secondaryText)
                                    } else if markedLine == line.id {
                                        Button(action: onFix) {
                                            Label("Исправить", systemImage: "arrow.trianglehead.counterclockwise")
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
                                    .accessibilityLabel("Поправить руками")
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
                }
            }
            .background(Theme.background)
            .navigationTitle(thread)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть", action: onClose)
                }
            }
        }
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
                source: "AITA for refusing to pay my brother's rent?",
                translation: "Нарушал ли я правила, отказавшись платить аренду брату?"
            ),
            TranslatedLine(
                id: 1,
                kind: .body,
                source: "He is a grown man and made his own choices.",
                translation: "Он взрослый мужик и сам сделал свой выбор."
            ),
        ],
        markedLine: 0,
        markedWords: [4, 5],
        fixingLine: nil,
        onMark: { _, _ in },
        onFix: {},
        onEdit: { _, _ in },
        onClose: {}
    )
}
