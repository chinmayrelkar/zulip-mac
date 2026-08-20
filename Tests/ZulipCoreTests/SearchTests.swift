import XCTest
@testable import ZulipCore

final class MessageTimeTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testTodayAndYesterday() {
        var parts = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 8, day: 18, hour: 15)
        let now = calendar.date(from: parts)!
        parts.hour = 9
        let today = calendar.date(from: parts)!
        parts.day = 17
        let yesterday = calendar.date(from: parts)!
        parts.day = 12
        let earlier = calendar.date(from: parts)!
        parts.year = 2025
        let lastYear = calendar.date(from: parts)!

        XCTAssertEqual(MessageTime.dayLabel(today, now: now, calendar: calendar), "Today")
        XCTAssertEqual(MessageTime.dayLabel(yesterday, now: now, calendar: calendar), "Yesterday")
        XCTAssertFalse(MessageTime.dayLabel(earlier, now: now, calendar: calendar).contains("2026"))
        XCTAssertTrue(MessageTime.dayLabel(lastYear, now: now, calendar: calendar).contains("2025"))
    }

    func testRewriteRelativeHTML() {
        let site = URL(string: "https://zulip.clarisights.com")!
        let html = #"<a href="/user_uploads/1/x.png"><img src="/user_uploads/1/x.png"></a>"#
        let out = HTMLRewrite.resolve(html, site: site)
        XCTAssertTrue(out.contains("https://zulip.clarisights.com/user_uploads/1/x.png"))
        XCTAssertFalse(out.contains("src=\"/user_uploads"))
    }
}

final class MessageHTMLTests: XCTestCase {
    func testParagraphLinkAndEntities() {
        let html = #"<p>Hello &amp; <a href="https://example.com">there</a></p>"#
        let runs = MessageHTML.runs(html)
        XCTAssertEqual(MessageHTML.plain(html).trimmingCharacters(in: .newlines), "Hello & there")
        XCTAssertTrue(runs.contains(where: { $0.link == "https://example.com" && $0.text == "there" }))
    }

    func testHighlightMentionAndImage() {
        let html = #"<p>see <span class="highlight">outage</span> <span class="user-mention">@you</span></p><img alt="x" src="/a.png">"#
        let blocks = MessageHTML.blocks(html)
        XCTAssertTrue(blocks.contains { if case .media(let src, _, _, .image) = $0 { return src == "/a.png" } else { return false } })
        let runs = MessageHTML.runs(html)
        XCTAssertTrue(runs.contains(where: { $0.highlight && $0.text == "outage" }))
        XCTAssertTrue(runs.contains(where: { $0.mention && $0.text.contains("@you") }))
        XCTAssertFalse(MessageHTML.plain(html).contains("<img"))
    }

    func testQuoteAndCodeBlocks() {
        let html = #"<blockquote><p>earlier</p></blockquote><div class="codehilite"><pre>let x = 1</pre></div>"#
        let blocks = MessageHTML.blocks(html)
        XCTAssertTrue(blocks.contains { if case .quote(let runs) = $0 { return runs.map(\.text).joined().contains("earlier") } else { return false } })
        XCTAssertTrue(blocks.contains { if case .code(let text) = $0 { return text.contains("let x = 1") } else { return false } })
    }

    func testTableAndSpoilerBlocks() {
        let html = """
        <div class="spoiler-block"><p>secret content</p></div>
        <table><tr><th>Header</th></tr><tr><td>Cell 1</td></tr></table>
        """
        let blocks = MessageHTML.blocks(html)
        XCTAssertTrue(blocks.contains { if case .spoiler(_, let runs) = $0 { return runs.map(\.text).joined().contains("secret") } else { return false } })
        XCTAssertTrue(blocks.contains { if case .table(let rows) = $0 { return rows.count == 2 } else { return false } })
    }

    func testQuoteMarkdownBuilder() {
        let message = Message(
            id: 101,
            senderID: 42,
            senderName: "Alice",
            senderEmail: "alice@example.com",
            content: "<p>Let's ship feature parity today!</p>"
        )
        let quoted = MessageHTML.quoteMarkdown(from: message)
        XCTAssertTrue(quoted.contains("@_**Alice|42** said:"))
        XCTAssertTrue(quoted.contains("> Let's ship feature parity today!"))
    }

    func testVideoGifAudioAndEmoji() {
        let html = """
        <div class="message_inline_image message_inline_video"><a href="/user_uploads/2/v/clip.mp4"><video src="/user_uploads/2/v/clip.mp4"></video></a></div>
        <img data-animated="true" src="/user_uploads/2/g/loop.gif">
        <audio src="/user_uploads/2/a/note.mp3" title="note.mp3">
        <img class="emoji" alt=":zulip:" src="/user_avatars/2/emoji/zulip.png">
        """
        let blocks = MessageHTML.blocks(html)
        XCTAssertTrue(blocks.contains { if case .media(_, _, _, .video) = $0 { return true } else { return false } })
        XCTAssertTrue(blocks.contains { if case .media(let src, _, _, .gif) = $0 { return src.contains("loop.gif") } else { return false } })
        XCTAssertTrue(blocks.contains { if case .media(_, _, _, .audio) = $0 { return true } else { return false } })
        XCTAssertFalse(blocks.contains { if case .media(let src, _, _, _) = $0 { return src.contains("emoji") } else { return false } })
        XCTAssertTrue(MessageHTML.plain(html).contains(":zulip:"))
    }

    func testMediaURLHelpers() {
        let site = URL(string: "https://zulip.clarisights.com")!
        let upload = URL(string: "https://zulip.clarisights.com/user_uploads/2/ab/file.png")!
        XCTAssertEqual(MediaURL.uploadAPIPath(for: upload), "/api/v1/user_uploads/2/ab/file.png")
        XCTAssertTrue(MediaURL.needsAuth(upload, site: site))
        let thumb = URL(string: "https://zulip.clarisights.com/user_uploads/thumbnail/2/ab/file.png/840x560.webp")!
        XCTAssertNil(MediaURL.uploadAPIPath(for: thumb))
        XCTAssertTrue(MediaURL.needsAuth(thumb, site: site))
        let remote = URL(string: "https://i.ytimg.com/vi/x/0.jpg")!
        XCTAssertFalse(MediaURL.needsAuth(remote, site: site))
        XCTAssertEqual(
            MediaURL.sharperPreview("/user_uploads/thumbnail/path/to/example.png/840x560.webp"),
            "/user_uploads/thumbnail/path/to/example.png/1920x1080.webp"
        )
    }

    func testThumbnailKeepsOriginalHref() {
        let html = """
        <div class="message_inline_image">
          <a href="/user_uploads/path/to/example.png" title="example.png">
            <img data-original-content-type="image/png" src="/user_uploads/thumbnail/path/to/example.png/840x560.webp">
          </a>
        </div>
        """
        let blocks = MessageHTML.blocks(html)
        guard case .media(let src, let original, _, .image) = blocks.first else {
            return XCTFail("expected image block")
        }
        XCTAssertTrue(src.contains("/thumbnail/"))
        XCTAssertEqual(original, "/user_uploads/path/to/example.png")
    }

    func testStripsScript() {
        let html = #"<p>ok</p><script>hang()</script><p>done</p>"#
        XCTAssertEqual(MessageHTML.plain(html).replacingOccurrences(of: "\n", with: ""), "okdone")
    }
}

final class EmojiProviderTests: XCTestCase {
    func testUnicodeDecodesHexCodePoints() {
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "1f44d"), "👍")
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "1f680"), "🚀")
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "2764"), "❤")
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "2764-fe0f"), "❤️")
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "1f602"), "😂")
        XCTAssertEqual(EmojiProvider.unicode(fromCode: "1f4af"), "💯")
    }

    func testDisplayCustomRealmEmoji() {
        let custom = RealmEmoji(
            id: "14",
            name: "zulip_logo",
            sourceURL: "https://zulip.clarisights.com/user_avatars/14.png",
            stillURL: nil,
            deactivated: false,
            authorID: 1
        )
        let dict = ["14": custom, "zulip_logo": custom]
        let display = EmojiProvider.display(name: "zulip_logo", code: "14", type: "realm_emoji", realmEmojis: dict)
        XCTAssertEqual(display, .custom(url: "https://zulip.clarisights.com/user_avatars/14.png", name: "zulip_logo"))
    }
}

final class AuthFileTests: XCTestCase {
    func testSaveLoadClearRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "zulip-mac-auth-\(UUID().uuidString)")
        let creds = Credentials(
            email: "me@example.com",
            apiKey: "test-key",
            site: URL(string: "https://zulip.example.com")!
        )
        try Auth.save(creds, to: url)
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual((mode?.intValue ?? 0) & 0o777, 0o600)
        let loaded = Auth.load(from: url)
        XCTAssertEqual(loaded, creds)
        Auth.clear(at: url)
        XCTAssertNil(try? Data(contentsOf: url))
    }
}

final class AvatarTests: XCTestCase {
    func testGravatarHashesLowercasedEmail() {
        let url = Avatar.gravatar(email: "  Foo@Example.com  ")
        XCTAssertEqual(
            url?.absoluteString,
            "https://secure.gravatar.com/avatar/b48def645758b95537d4424c84d1a9ff?d=identicon&s=64"
        )
    }

    func testRelativeAvatarUsesSite() {
        let site = URL(string: "https://zulip.clarisights.com")!
        let url = Avatar.url(avatar: "/user_avatars/2/abc.png", email: "x@y.z", site: site)
        XCTAssertEqual(url?.absoluteString, "https://zulip.clarisights.com/user_avatars/2/abc.png")
    }

    func testMissingAvatarFallsBackToGravatar() {
        let site = URL(string: "https://zulip.clarisights.com")!
        let url = Avatar.url(avatar: nil, email: "foo@example.com", site: site)
        XCTAssertEqual(
            url?.absoluteString,
            "https://secure.gravatar.com/avatar/b48def645758b95537d4424c84d1a9ff?d=identicon&s=64"
        )
    }
}

final class SearchTests: XCTestCase {
    func testKeywordAndOperators() {
        let parsed = Search.parse(#"channel:announce -sender:iago@zulip.com cool sunglasses"#)
        XCTAssertEqual(parsed.terms.map(\.op), ["channel", "sender", "search"])
        XCTAssertEqual(parsed.terms[0].operand, .string("announce"))
        XCTAssertTrue(parsed.terms[1].negated)
        XCTAssertEqual(parsed.terms[1].operand, .string("iago@zulip.com"))
        XCTAssertEqual(parsed.terms[2].operand, .string("cool sunglasses"))
        XCTAssertNil(parsed.conversation)
        XCTAssertEqual(parsed.anchor, "newest")
    }

    func testQuotedTopicBecomesConversation() {
        let parsed = Search.parse(#"channel:design topic:"new logo""#)
        XCTAssertEqual(parsed.conversation, .topic(streamID: 0, streamName: "design", topic: "new logo"))
        XCTAssertEqual(parsed.terms.map(\.op), ["channel", "topic"])
    }

    func testNearSetsAnchorAndIsNotATerm() {
        let parsed = Search.parse("channel:design near:12345")
        XCTAssertEqual(parsed.anchor, "12345")
        XCTAssertEqual(parsed.terms.map(\.op), ["channel"])
        XCTAssertNil(parsed.conversation)
    }

    func testAliasesAndNegation() {
        let parsed = Search.parse("stream:ops -is:resolved has:image")
        XCTAssertEqual(parsed.terms.map(\.op), ["channel", "is", "has"])
        XCTAssertTrue(parsed.terms[1].negated)
        XCTAssertEqual(parsed.terms[1].operand, .string("resolved"))
    }

    func testSenderMeAndDMResolution() {
        let users = [
            User(userID: 10, fullName: "Chinmay Relkar", email: "chinmay@clarisights.com"),
            User(userID: 22, fullName: "Bo Lin", email: "bo@example.com"),
            User(userID: 33, fullName: "Elena García", email: "elena@example.com"),
        ]
        let context = SearchContext(selfEmail: "chinmay@clarisights.com", selfUserID: 10, users: users)
        let sender = Search.parse("sender:me", context: context)
        XCTAssertEqual(sender.terms[0].operand, .int(10))

        let dm = Search.parse(#"dm:"Bo Lin, Elena García""#, context: context)
        XCTAssertEqual(dm.terms[0].op, "dm")
        XCTAssertEqual(dm.terms[0].operand, .ints([22, 33]))
        XCTAssertEqual(dm.conversation, .dm(userIDs: [22, 33]))
    }

    func testTokenizeQuotesAndEscapes() {
        XCTAssertEqual(
            Search.tokenize(#"channel:design topic:"new logo" hello"#),
            [#"channel:design"#, #"topic:"new logo""#, "hello"]
        )
    }

    func testFullFilterSetParses() {
        let query = "is:mentioned is:starred is:unread is:followed is:dm has:link has:attachment has:image has:reaction channels:public"
        let parsed = Search.parse(query)
        XCTAssertEqual(parsed.terms.count, 10)
        XCTAssertEqual(Set(parsed.terms.map(\.op)), ["is", "has", "channels"])
    }
}
