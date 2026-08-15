import Foundation

/// Разбиение на предложения. Нужно в двух местах: обрезка сценария режет по границе
/// фразы, а нейросетевая озвучка синтезирует пофразно, чтобы знать длину каждой.
enum Sentences {

    static func of(_ text: String) -> [String] {
        var sentences: [String] = []

        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { sentence, _, _, _ in
            guard
                let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines),
                !sentence.isEmpty
            else { return }

            sentences.append(sentence)
        }

        return sentences
    }
}
