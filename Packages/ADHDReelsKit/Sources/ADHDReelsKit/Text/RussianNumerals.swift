import Foundation

/// Числительные словами в тех формах, которых нет у `NumberFormatter`: он знает
/// только именительный падеж и выдаёт «в две тысячи двадцать году» и «из каждых сто».
///
/// Формы закрытые и пересчитываются по таблице, поэтому здесь они, а не в подсказке
/// модели: стоило попросить перевод писать числа словами — и четырёхмиллиардная
/// модель начинала их выдумывать, «34» превращались в «тридцать», а «29» — в «двадцать».
enum RussianNumerals {

    /// Родительный падеж: «из каждых ста», «двадцати восьми».
    static func genitive(_ value: Int) -> String? {
        parts(value, units: unitsGenitive, tens: tensGenitive, hundreds: hundredsGenitive)?
            .joined(separator: " ")
    }

    /// Основа для сложных слов: «34» + «летний» — это «тридцатичетырёхлетний».
    /// Отличий от родительного всего три, и все — на стыке с остальным словом.
    static func compound(_ value: Int) -> String? {
        guard var joined = parts(value, units: unitsGenitive, tens: tensGenitive, hundreds: hundredsGenitive)
        else { return nil }

        if value % 10 == 1, value % 100 != 11, let last = joined.indices.last { joined[last] = "одно" }
        if value % 100 == 90, let last = joined.indices.last { joined[last] = "девяносто" }
        if value == 100 { joined = ["сто"] }

        return joined.joined()
    }

    /// Год в «в ... году»: порядковое в предложном падеже, и склоняется только
    /// последняя значащая часть — «две тысячи двадцатом», «тысяча девятьсот восьмом».
    static func yearPrepositional(_ value: Int) -> String? {
        guard (1000...2999).contains(value) else { return nil }

        let thousands = value / 1000
        let rest = value % 1000
        guard rest > 0 else { return thousands == 1 ? "тысячном" : "двухтысячном" }

        let prefix = thousands == 1 ? "тысяча" : "две тысячи"
        let hundreds = rest / 100
        let tail = rest % 100

        if tail == 0 { return "\(prefix) \(hundredsOrdinal[hundreds - 1])" }

        var words = [prefix]
        if hundreds > 0 { words.append(hundredsNominative[hundreds - 1]) }

        if tail < 20 {
            words.append(unitsOrdinal[tail - 1])
        } else if tail % 10 == 0 {
            words.append(tensOrdinal[tail / 10 - 2])
        } else {
            words.append(tensNominative[tail / 10 - 2])
            words.append(unitsOrdinal[tail % 10 - 1])
        }

        return words.joined(separator: " ")
    }

    // MARK: - Разбор на сотни, десятки и единицы

    /// Числа до тысячи: дальше в рассказах встречаются только суммы, а они и в
    /// именительном звучат как надо — «пять тысяч долларов».
    private static func parts(
        _ value: Int,
        units: [String],
        tens: [String],
        hundreds: [String]
    ) -> [String]? {
        guard (0...999).contains(value) else { return nil }

        var words: [String] = []
        if value >= 100 { words.append(hundreds[value / 100 - 1]) }

        let tail = value % 100
        if tail >= 20 {
            words.append(tens[tail / 10 - 2])
            if tail % 10 > 0 { words.append(units[tail % 10]) }
        } else if tail > 0 || words.isEmpty {
            words.append(units[tail])
        }

        return words
    }

    // MARK: - Таблицы

    /// Ноль в родительном не встречается ни в возрасте, ни в датах, но индекс нужен.
    private static let unitsGenitive = [
        "ноля", "одного", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти",
        "десяти", "одиннадцати", "двенадцати", "тринадцати", "четырнадцати", "пятнадцати",
        "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати",
    ]

    private static let tensGenitive = [
        "двадцати", "тридцати", "сорока", "пятидесяти",
        "шестидесяти", "семидесяти", "восьмидесяти", "девяноста",
    ]

    private static let hundredsGenitive = [
        "ста", "двухсот", "трёхсот", "четырёхсот", "пятисот",
        "шестисот", "семисот", "восьмисот", "девятисот",
    ]

    private static let tensNominative = [
        "двадцать", "тридцать", "сорок", "пятьдесят",
        "шестьдесят", "семьдесят", "восемьдесят", "девяносто",
    ]

    private static let hundredsNominative = [
        "сто", "двести", "триста", "четыреста", "пятьсот",
        "шестьсот", "семьсот", "восемьсот", "девятьсот",
    ]

    private static let unitsOrdinal = [
        "первом", "втором", "третьем", "четвёртом", "пятом", "шестом", "седьмом", "восьмом",
        "девятом", "десятом", "одиннадцатом", "двенадцатом", "тринадцатом", "четырнадцатом",
        "пятнадцатом", "шестнадцатом", "семнадцатом", "восемнадцатом", "девятнадцатом",
    ]

    private static let tensOrdinal = [
        "двадцатом", "тридцатом", "сороковом", "пятидесятом",
        "шестидесятом", "семидесятом", "восьмидесятом", "девяностом",
    ]

    private static let hundredsOrdinal = [
        "сотом", "двухсотом", "трёхсотом", "четырёхсотом", "пятисотом",
        "шестисотом", "семисотом", "восьмисотом", "девятисотом",
    ]
}
