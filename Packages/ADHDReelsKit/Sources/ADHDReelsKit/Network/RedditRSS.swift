import Foundation

/// Разбор Atom-ленты Reddit. Нужен потому, что анонимные запросы к `.json` Reddit
/// отдаёт 403 с большинства адресов, а те же данные в `.rss` открыты.
/// Рейтинга в ленте нет — зато порядок в ней уже «топ», и сортировать нечего.
enum RedditRSS {

    static func posts(from data: Data, subreddit: String) -> [RedditPost] {
        entries(from: data).compactMap { entry in
            guard entry.id.hasPrefix("t3_"), !entry.title.isEmpty else { return nil }

            return RedditPost(
                id: String(entry.id.dropFirst(3)),
                subreddit: subreddit,
                title: HTMLText.plain(entry.title),
                selftext: HTMLText.plain(entry.content),
                score: 0,
                isNSFW: false,
                permalink: path(of: entry.link)
            )
        }
    }

    static func comments(from data: Data) -> [RedditComment] {
        entries(from: data).compactMap { entry in
            guard entry.id.hasPrefix("t1_") else { return nil }

            let body = HTMLText.plain(entry.content)
            guard !body.isEmpty else { return nil }

            return RedditComment(id: String(entry.id.dropFirst(3)), body: body, score: 0)
        }
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
