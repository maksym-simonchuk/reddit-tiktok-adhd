import Foundation

/// Два миллиона словоформ с ударениями — то, ради чего вообще стоит брать vosk-tts:
/// правила из `RussianG2P` ударение не ставят вовсе, а без него русская речь
/// разваливается («что» без словаря читается как «чтo», а не «штo»).
///
/// В память такой словарь не поднять: `[String: String]` на два миллиона пар — это
/// сотни мегабайт поверх девятисот, которые уже занимают сами модели. Файл отсортирован
/// при сборке, лежит в бандле и читается через mmap двоичным поиском — ОЗУ не тратится.
struct StressDictionary: Sendable {

    private static let newline: UInt8 = 0x0A
    private static let tab: UInt8 = 0x09

    private let data: Data

    init?(contentsOf url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), !data.isEmpty else { return nil }
        self.data = data
    }

    /// Строка файла — `слово\tфонемы через пробел`, порядок строк побайтовый.
    /// UTF-8 сохраняет порядок кодовых точек, поэтому сортировка при сборке
    /// (обычный `sorted` в Python) и сравнение здесь дают одно и то же.
    func phonemes(for word: String) -> [String]? {
        let key = Array(word.utf8)

        return data.withUnsafeBytes { raw -> [String]? in
            let bytes = raw.bindMemory(to: UInt8.self)
            var low = 0
            var high = bytes.count

            // Границы всегда стоят на начале строки, поэтому от середины хватает
            // отката назад до перевода строки, чтобы получить строку целиком.
            while low < high {
                var start = (low + high) / 2
                while start > low, bytes[start - 1] != Self.newline { start -= 1 }

                var end = start
                while end < high, bytes[end] != Self.newline { end += 1 }
                guard end > start else { return nil }

                var tab = start
                while tab < end, bytes[tab] != Self.tab { tab += 1 }

                switch Self.compare(bytes[start..<tab], key) {
                case .orderedSame:
                    guard tab < end else { return nil }
                    let phonemes = String(decoding: bytes[(tab + 1)..<end], as: UTF8.self)
                    return phonemes.split(separator: " ").map(String.init)
                case .orderedAscending:
                    low = end + 1
                case .orderedDescending:
                    high = start
                }
            }

            return nil
        }
    }

    private static func compare(_ line: Slice<UnsafeBufferPointer<UInt8>>, _ key: [UInt8]) -> ComparisonResult {
        var index = line.startIndex

        for byte in key {
            guard index < line.endIndex else { return .orderedAscending }
            if line[index] != byte { return line[index] < byte ? .orderedAscending : .orderedDescending }
            index += 1
        }

        return index < line.endIndex ? .orderedDescending : .orderedSame
    }
}
