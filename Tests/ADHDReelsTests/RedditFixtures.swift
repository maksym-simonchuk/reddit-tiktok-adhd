/// Зафиксированные ответы Reddit. Лежат строками, а не файлами, чтобы golden-тесты
/// не зависели от ресурсов тестового бандла и работали без сети.
enum RedditFixtures {

    static let listing = #"""
    {"kind":"Listing","data":{"children":[
      {"kind":"t3","data":{
        "id":"a1","subreddit":"AskReddit","title":"AITA for leaving early?",
        "selftext":"My wife (28F) got mad.\n\nI left the party at 9.\n\nEdit: wow this blew up",
        "score":8400,"over_18":false,"permalink":"/r/AskReddit/comments/a1/x/","stickied":false}},
      {"kind":"t3","data":{
        "id":"a2","subreddit":"AskReddit","title":"Pinned: read the rules",
        "selftext":"","score":50000,"over_18":false,"permalink":"/r/AskReddit/comments/a2/x/","stickied":true}},
      {"kind":"t3","data":{
        "id":"a3","subreddit":"AskReddit","title":"Low effort post",
        "selftext":"nothing","score":12,"over_18":false,"permalink":"/r/AskReddit/comments/a3/x/","stickied":false}},
      {"kind":"t3","data":{
        "id":"a4","subreddit":"AskReddit","title":"Spicy thread",
        "selftext":"body","score":9000,"over_18":true,"permalink":"/r/AskReddit/comments/a4/x/","stickied":false}},
      {"kind":"more","data":{"id":"a5"}}
    ]}}
    """#

    static let comments = #"""
    [
      {"kind":"Listing","data":{"children":[
        {"kind":"t3","data":{"id":"a1","title":"AITA for leaving early?","selftext":"body","score":8400,
          "permalink":"/r/AskReddit/comments/a1/x/","stickied":false}}
      ]}},
      {"kind":"Listing","data":{"children":[
        {"kind":"t1","data":{"id":"c1","body":"NTA, honestly. See [the rules](https://reddit.com/rules) for that.","score":300}},
        {"kind":"t1","data":{"id":"c2","body":"YTA and everyone knows it 😤","score":1200}},
        {"kind":"t1","data":{"id":"c3","body":"[deleted]","score":9000}},
        {"kind":"t1","data":{"id":"c4","body":"","score":400}},
        {"kind":"more","data":{"id":"c5","body":"ignored","score":99999}}
      ]}}
    ]
    """#
}
