import XCTest
@testable import ZulipCore

final class EmojiRenderingTests: XCTestCase {
    func testCustomEmojiImgCarriesURL() {
        let html = #"""
        <p>hi <img alt=":team_celebrate:" class="emoji"
        src="/user_uploads/1/ab/cd/team_celebrate.png" title="team_celebrate"> there</p>
        """#
        let runs = MessageHTML.runs(html)
        let emojiRun = runs.first { $0.customEmojiURL != nil }
        XCTAssertNotNil(emojiRun, "custom emoji img should produce a run with customEmojiURL")
        XCTAssertEqual(emojiRun?.customEmojiURL, "/user_uploads/1/ab/cd/team_celebrate.png")
        XCTAssertEqual(emojiRun?.text, ":team_celebrate:")
    }

    func testUnicodeEmojiImgStillDecodesToChar() {
        let html = #"""
        <p><img alt=":smile:" class="emoji" src="/static/generated/emoji/images/emoji/1f604.png" title="smile"></p>
        """#
        let runs = MessageHTML.runs(html)
        XCTAssertNil(runs.first?.customEmojiURL)
        XCTAssertEqual(runs.first?.text, "😄")
    }

    func testPlainKeepsNameForQuote() {
        let html = #"""
        <p><img alt=":team_celebrate:" class="emoji" src="/x/y.png" title="team_celebrate"></p>
        """#
        XCTAssertEqual(MessageHTML.plain(html), ":team_celebrate:")
    }

    func testDisplayEmojiCustomURL() {
        let realm = [
            "team_celebrate": RealmEmoji(
                id: "team_celebrate",
                name: "team_celebrate",
                sourceURL: "/user_uploads/1/ab/team_celebrate.png",
                deactivated: false,
                authorID: nil
            )
        ]
        let display = EmojiProvider.display(
            name: "team_celebrate",
            code: "team_celebrate",
            type: "realm_emoji",
            realmEmojis: realm
        )
        XCTAssertEqual(display, .custom(url: "/user_uploads/1/ab/team_celebrate.png", name: "team_celebrate"))
    }
}

final class MediaDedupTests: XCTestCase {
    func testAnimatedGifNotDuplicated() {
        let html = #"""
        <p><a href="/user_media/1/ab/cat.gif">
        <img class="message_inline_image animated" src="/user_uploads/thumbnail/1/ab/100x100.webp"
        data-original-src="/user_media/1/ab/cat.gif" data-animated="1" alt="cat.gif"></a></p>
        """#
        let media = MessageHTML.blocks(html).compactMap { block -> String? in
            if case .media(let src, _, _, _) = block { return src }
            return nil
        }
        XCTAssertEqual(media, ["/user_media/1/ab/cat.gif"], "one animated block, not a static thumbnail + animated duplicate")
    }

    func testGiphyLinkDedupedByPath() {
        let html = #"""
        <p><a href="https://giphy.com/media/abc123/giphy.gif"><img src="https://media.giphy.com/media/abc123/giphy.gif" alt="gif"></a></p>
        """#
        let media = MessageHTML.blocks(html).compactMap { block -> String? in
            if case .media(let src, _, _, _) = block { return src }
            return nil
        }
        XCTAssertEqual(media.count, 1, "giphy img + wrapping link should collapse to one media block")
    }
}

