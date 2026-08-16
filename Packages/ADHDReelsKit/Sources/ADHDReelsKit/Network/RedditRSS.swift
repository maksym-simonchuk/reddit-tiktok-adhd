import Foundation

/// Разбор Atom-ленты Reddit. Нужен потому, что анонимные запросы к `.json` Reddit
/// отдаёт 403 с большинства адресов, а те же данные в `.rss` открыты.
/// Рейтинга в ленте нет — зато порядок в ней уже «топ», и сортировать нечего.
enum RedditRSS {

    static func posts(from data: Data, subreddit: String) -> [RedditPost] {
        entries(from: data).compactMap { entry in
            guard entry.id.hasPrefix("t3_"), !entry.title.isEmpty else { return nil }

            // Пост без текста — картинка или ссылка: истории в нём нет, ролик из
            // одной подписи «submitted by …» собирать не из чего.
            let body = HTMLText.plain(selftext(in: entry.content))
            guard body.split(whereSeparator: \.isWhitespace).count >= 5 else { return nil }

            return RedditPost(
                id: String(entry.id.dropFirst(3)),
                subreddit: subreddit,
                title: HTMLText.plain(entry.title),
                selftext: body,
                score: 0,
                isNSFW: false,
                permalink: path(of: entry.link)
            )
        }
    }

    /// Тело поста Reddit обрамляет маркерами SC_OFF/SC_ON; всё вне их — служебная
    /// подпись «submitted by … [link] [comments]», локализованная под язык
    /// устройства, поэтому вырезать её по тексту ненадёжно, а по маркерам — точно.
    static func selftext(in content: String) -> String {
        guard let start = content.range(of: "<!-- SC_OFF -->"),
              let end = content.range(of: "<!-- SC_ON -->", range: start.upperBound..<content.endIndex)
        else { return "" }

        return String(content[start.upperBound..<end.lowerBound])
    }

    /// Ссылка приходит абсолютной, а `RedditPost.permalink` везде хранится путём.
    private static func path(of link: String) -> String {
        URL(string: link)?.path() ?? link
    }

    // MARK: - Разбор

    struct Entry {
        var id = ""
        var title = ""
        var content = ""
        var link = ""
    }

    static func entries(from data: Data) -> [Entry] {
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.parse()

        return collector.entries
    }

    private final class Collector: NSObject, XMLParserDelegate {

        var entries: [Entry] = []

        private var entry: Entry?
        private var field: String?
        private var buffer = ""

        func parser(
            _ parser: XMLParser,
            didStartElement element: String,
            namespaceURI: String?,
            qualifiedName: String?,
            attributes: [String: String]
        ) {
            switch element {
            case "entry":
                entry = Entry()
            case "id", "title", "content":
                // Те же имена встречаются и в шапке ленты — берём только внутри записи.
                guard entry != nil else { return }
                field = element
                buffer = ""
            case "link":
                if entry != nil, let href = attributes["href"] { entry?.link = href }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard field != nil else { return }
            buffer += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement element: String,
            namespaceURI: String?,
            qualifiedName: String?
        ) {
            if element == "entry", let entry {
                entries.append(entry)
                self.entry = nil
            }

            guard element == field else { return }
            switch element {
            case "id": entry?.id = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            case "title": entry?.title = buffer
            case "content": entry?.content = buffer
            default: break
            }
            field = nil
        }
    }
}
