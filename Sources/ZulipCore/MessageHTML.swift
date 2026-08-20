import Foundation

public struct HTMLRun: Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var code: Bool
    public var highlight: Bool
    public var mention: Bool
    public var link: String?
    public var customEmojiURL: String?

    public init(
        text: String,
        bold: Bool = false,
        italic: Bool = false,
        code: Bool = false,
        highlight: Bool = false,
        mention: Bool = false,
        link: String? = nil,
        customEmojiURL: String? = nil
    ) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.code = code
        self.highlight = highlight
        self.mention = mention
        self.link = link
        self.customEmojiURL = customEmojiURL
    }
}

public enum MediaKind: Equatable, Sendable {
    case image
    case gif
    case video
    case audio
}

public struct TableRowData: Equatable, Sendable {
    public var cells: [[HTMLRun]]
    public var isHeader: Bool
    public init(cells: [[HTMLRun]], isHeader: Bool = false) {
        self.cells = cells
        self.isHeader = isHeader
    }
}

public enum MessageBlock: Equatable, Sendable {
    case heading(level: Int, runs: [HTMLRun])
    case text([HTMLRun])
    case quote([HTMLRun])
    case spoiler(header: String, content: [HTMLRun])
    case table([TableRowData])
    case code(String)
    case media(src: String, original: String?, alt: String, kind: MediaKind)
}

public enum MessageHTML {
    public static func blocks(_ html: String) -> [MessageBlock] {
        var parser = Parser(html: html)
        parser.parse()
        return parser.finish()
    }

    public static func runs(_ html: String) -> [HTMLRun] {
        blocks(html).flatMap { block -> [HTMLRun] in
            switch block {
            case .heading(_, let runs), .text(let runs), .quote(let runs):
                return runs
            case .spoiler(let header, let content):
                return [HTMLRun(text: "\(header): ")] + content
            case .table(let rows):
                return rows.flatMap { $0.cells.flatMap { $0 } }
            case .code(let text):
                return [HTMLRun(text: text, code: true)]
            case .media(_, _, let alt, let kind):
                let label = alt.isEmpty ? " [\(kind)] " : " \(alt) "
                return [HTMLRun(text: label)]
            }
        }
    }

    public static func plain(_ html: String) -> String {
        runs(html).map(\.text).joined()
    }

    public static func quoteMarkdown(from message: Message) -> String {
        let plainText = plain(message.displayHTML).trimmingCharacters(in: .whitespacesAndNewlines)
        let quotedLines = plainText.split(whereSeparator: \.isNewline).map { "> \($0)" }.joined(separator: "\n")
        return "@_**\(message.senderName)|\(message.senderID)** said:\n\(quotedLines)\n\n"
    }

    public static func fromMarkdown(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var result = ""
        var inCodeBlock = false
        var codeBlockContent: [String] = []
        var inList = false
        var listIsOrdered = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code blocks
            if trimmed.hasPrefix("```") {
                if inList {
                    result += listIsOrdered ? "</ol>\n" : "</ul>\n"
                    inList = false
                }
                if inCodeBlock {
                    inCodeBlock = false
                    let code = codeBlockContent.joined(separator: "\n")
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    result += "<pre><code>\(code)</code></pre>\n"
                    codeBlockContent.removeAll()
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }

            // Headers
            if trimmed.hasPrefix("### ") {
                if inList { result += listIsOrdered ? "</ol>\n" : "</ul>\n"; inList = false }
                let text = parseInlineMarkdown(String(trimmed.dropFirst(4)))
                result += "<h3>\(text)</h3>\n"
                continue
            }
            if trimmed.hasPrefix("## ") {
                if inList { result += listIsOrdered ? "</ol>\n" : "</ul>\n"; inList = false }
                let text = parseInlineMarkdown(String(trimmed.dropFirst(3)))
                result += "<h2>\(text)</h2>\n"
                continue
            }
            if trimmed.hasPrefix("# ") {
                if inList { result += listIsOrdered ? "</ol>\n" : "</ul>\n"; inList = false }
                let text = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                result += "<h1>\(text)</h1>\n"
                continue
            }

            // Blockquotes
            if trimmed.hasPrefix("> ") {
                if inList { result += listIsOrdered ? "</ol>\n" : "</ul>\n"; inList = false }
                let quote = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                result += "<blockquote><p>\(quote)</p></blockquote>\n"
                continue
            }

            // Unordered list: - item or * item
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList || listIsOrdered {
                    if inList { result += "</ol>\n" }
                    result += "<ul>\n"
                    inList = true
                    listIsOrdered = false
                }
                let item = parseInlineMarkdown(String(trimmed.dropFirst(2)))
                result += "<li>\(item)</li>\n"
                continue
            }

            // Ordered list: 1. item
            if let match = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                if !inList || !listIsOrdered {
                    if inList { result += "</ul>\n" }
                    result += "<ol>\n"
                    inList = true
                    listIsOrdered = true
                }
                let item = parseInlineMarkdown(String(trimmed[match.upperBound...]))
                result += "<li>\(item)</li>\n"
                continue
            }

            if inList {
                result += listIsOrdered ? "</ol>\n" : "</ul>\n"
                inList = false
            }

            if line.isEmpty {
                result += "<p><br/></p>\n"
                continue
            }

            let parsed = parseInlineMarkdown(line)
            result += "<p>\(parsed)</p>\n"
        }

        if inList {
            result += listIsOrdered ? "</ol>\n" : "</ul>\n"
        }

        if inCodeBlock && !codeBlockContent.isEmpty {
            let code = codeBlockContent.joined(separator: "\n")
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            result += "<pre><code>\(code)</code></pre>\n"
        }

        return result
    }

    private static func parseInlineMarkdown(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // User mentions: @**User Name** or @**User Name|1234**
        if let regex = try? NSRegularExpression(pattern: #"@\*\*([^*|]+)(?:\|[0-9]+)?\*\*"#) {
            let nsString = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let name = nsString.substring(with: match.range(at: 1))
                    let replacement = "<span class=\"user-mention\">@\(name)</span>"
                    s = (s as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        // Channel mentions: #**channel>topic** or #**channel**
        if let regex = try? NSRegularExpression(pattern: #"#\*\*([^*>]+)(?:>([^*]+))?\*\*"#) {
            let nsString = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let streamName = nsString.substring(with: match.range(at: 1))
                let replacement = "<span class=\"stream-topic\">#\(streamName)</span>"
                s = (s as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        // Emojis: :emoji_name:
        if let regex = try? NSRegularExpression(pattern: #":([a-zA-Z0-9_+ -]+):"#) {
            let nsString = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if match.numberOfRanges >= 2 {
                    let name = nsString.substring(with: match.range(at: 1)).lowercased()
                    if let char = EmojiProvider.character(for: name) {
                        s = (s as NSString).replacingCharacters(in: match.range, with: char)
                    }
                }
            }
        }

        // Bold: **text**
        while let start = s.range(of: "**") {
            let rest = s[start.upperBound...]
            if let end = rest.range(of: "**") {
                let inner = s[start.upperBound..<end.lowerBound]
                s.replaceSubrange(start.lowerBound..<end.upperBound, with: "<strong>\(inner)</strong>")
            } else {
                break
            }
        }

        // Italic: *text*
        while let start = s.range(of: "*") {
            let rest = s[start.upperBound...]
            if let end = rest.range(of: "*") {
                let inner = s[start.upperBound..<end.lowerBound]
                s.replaceSubrange(start.lowerBound..<end.upperBound, with: "<em>\(inner)</em>")
            } else {
                break
            }
        }

        // Inline code: `code`
        while let start = s.range(of: "`") {
            let rest = s[start.upperBound...]
            if let end = rest.range(of: "`") {
                let inner = s[start.upperBound..<end.lowerBound]
                s.replaceSubrange(start.lowerBound..<end.upperBound, with: "<code>\(inner)</code>")
            } else {
                break
            }
        }

        // Strikethrough: ~~text~~
        while let start = s.range(of: "~~") {
            let rest = s[start.upperBound...]
            if let end = rest.range(of: "~~") {
                let inner = s[start.upperBound..<end.lowerBound]
                s.replaceSubrange(start.lowerBound..<end.upperBound, with: "<del>\(inner)</del>")
            } else {
                break
            }
        }

        // Links: [title](url)
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)") {
            let nsString = s as NSString
            let matches = regex.matches(in: s, range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                if match.numberOfRanges == 3 {
                    let titleRange = match.range(at: 1)
                    let urlRange = match.range(at: 2)
                    let title = nsString.substring(with: titleRange)
                    let url = nsString.substring(with: urlRange)
                    let replacement = "<a href=\"\(url)\">\(title)</a>"
                    s = (s as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }
        }

        return s
    }
}

private struct Style {
    var bold = false
    var italic = false
    var code = false
    var highlight = false
    var mention = false
    var link: String?
}

private struct Parser {
    let chars: [Character]
    var index = 0
    var style = Style()
    var stack: [(String, Style)] = []
    var quoteDepth = 0
    var inPre = false
    var codeBuffer = ""
    var pendingHref: String?
    var inVideoWrap = false
    var inSpoiler = false
    var spoilerHeader = "Spoiler"
    var spoilerRuns: [HTMLRun] = []
    var inTable = false
    var tableRows: [TableRowData] = []
    var currentRowCells: [[HTMLRun]] = []
    var currentCellRuns: [HTMLRun] = []
    var inHeadingLevel: Int?
    var current: [HTMLRun] = []
    var blocks: [MessageBlock] = []

    init(html: String) {
        chars = Array(html)
    }

    mutating func parse() {
        while index < chars.count {
            if chars[index] == "<" {
                parseTag()
            } else {
                parseText()
            }
        }
    }

    mutating func finish() -> [MessageBlock] {
        flushText()
        return blocks.filter { block in
            switch block {
            case .heading(_, let runs), .text(let runs), .quote(let runs):
                return runs.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            case .spoiler(_, let content):
                return !content.isEmpty
            case .table(let rows):
                return !rows.isEmpty
            case .code(let text):
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .media(let src, _, _, _):
                return !src.isEmpty
            }
        }
    }

    mutating func parseText() {
        var raw = ""
        while index < chars.count, chars[index] != "<" {
            raw.append(chars[index])
            index += 1
        }
        emit(decode(raw))
    }

    mutating func parseTag() {
        guard chars[index] == "<" else { return }
        index += 1
        if index < chars.count, chars[index] == "!" {
            skipUntil(">")
            return
        }
        let closing = consume("/")
        let name = readName().lowercased()
        let attrs = readAttrs()
        _ = consume("/")
        if index < chars.count, chars[index] == ">" { index += 1 }
        if name.isEmpty { return }
        if ["script", "style"].contains(name) {
            if !closing { skipUntilClose(name) }
            return
        }
        if closing {
            close(name)
        } else {
            open(name, attrs: attrs)
        }
    }

    mutating func open(_ name: String, attrs: [String: String]) {
        let previous = style
        stack.append((name, previous))
        let classes = attrs["class"] ?? ""

        switch name {
        case "br":
            emit("\n")
            stack.removeLast()
            style = previous
        case "hr":
            flushText()
            stack.removeLast()
            style = previous
        case "img":
            if classes.contains("emoji") {
                var unicodeChar: String?
                if let title = attrs["title"] ?? attrs["alt"] {
                    let clean = title.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
                    unicodeChar = EmojiProvider.character(for: clean)
                }
                if let char = unicodeChar {
                    emit(char)
                } else {
                    let name = (attrs["title"] ?? attrs["alt"] ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
                    if let src = attrs["src"], !src.isEmpty, !name.isEmpty {
                        // Custom realm emoji: keep the :name: text for copy/quote, carry the
                        // image URL so the UI can render it inline.
                        appendRun(HTMLRun(text: ":\(name):", customEmojiURL: src))
                    } else {
                        emit(name.isEmpty ? "✨" : ":\(name):")
                    }
                }
                stack.removeLast()
                style = previous
            } else {
                let src = mediaSource(attrs)
                let alt = attrs["alt"] ?? attrs["title"] ?? ""
                flushText()
                if !src.isEmpty {
                    // For GIFs, a linked <img> is just the static preview (e.g. Zulip's
                    // /external_content proxy) while the wrapping <a> is the animated
                    // media — skip the preview block so it isn't rendered twice.
                    // Non-GIF media links keep their thumbnail <img> (original preserved).
                    let isGifPreview = pendingHref.map { $0.lowercased().contains(".gif") } ?? false
                    if !isGifPreview {
                        let original = attrs["data-original-src"] ?? pendingHref
                        blocks.append(.media(
                            src: src,
                            original: original == src ? nil : original,
                            alt: alt,
                            kind: MediaKind.detect(
                                src: src,
                                contentType: attrs["data-original-content-type"] ?? "",
                                animated: attrs["data-animated"] != nil || classes.contains("animated"),
                                tag: "img"
                            )
                        ))
                    }
                }
                stack.removeLast()
                style = previous
            }
        case "video":
            let src = attrs["src"] ?? pendingHref ?? ""
            flushText()
            if !src.isEmpty {
                blocks.append(.media(src: src, original: pendingHref == src ? nil : pendingHref, alt: attrs["title"] ?? "", kind: .video))
            }
            stack.removeLast()
            style = previous
            pendingHref = nil
            inVideoWrap = false
        case "audio":
            let src = attrs["src"] ?? attrs["data-original-url"] ?? pendingHref ?? ""
            flushText()
            if !src.isEmpty {
                blocks.append(.media(src: src, original: nil, alt: attrs["title"] ?? "", kind: .audio))
            }
            stack.removeLast()
            style = previous
        case "pre":
            flushText()
            inPre = true
            codeBuffer = ""
        case "div":
            if classes.contains("spoiler-block") {
                flushText()
                inSpoiler = true
                spoilerHeader = "Spoiler"
                spoilerRuns = []
            }
            if classes.contains("message_inline_video") {
                inVideoWrap = true
            }
        case "table":
            flushText()
            inTable = true
            tableRows = []
        case "tr":
            currentRowCells = []
        case "th", "td":
            currentCellRuns = []
        case "li":
            flushText()
            if classes.contains("task-list-item") {
                // Task list item
            } else {
                emit("• ")
            }
        case "input":
            if attrs["type"] == "checkbox" {
                let checked = attrs["checked"] != nil
                emit(checked ? "[x] " : "[ ] ")
            }
            stack.removeLast()
            style = previous
        case "h1", "h2", "h3", "h4", "h5", "h6":
            flushText()
            if let level = Int(name.dropFirst()) {
                inHeadingLevel = level
            }
            style.bold = true
        case "strong", "b":
            style.bold = true
        case "em", "i":
            style.italic = true
        case "code", "tt":
            if !inPre { style.code = true }
        case "blockquote":
            flushText()
            quoteDepth += 1
        case "a":
            if let href = attrs["href"], !href.isEmpty {
                style.link = href
                pendingHref = href
            }
            if classes.contains("user-mention") || classes.contains("user-group-mention") {
                style.mention = true
            }
        case "span":
            if classes.contains("emoji") {
                var unicodeChar: String?
                for cls in classes.split(separator: " ") {
                    if cls.hasPrefix("emoji-") {
                        let hex = String(cls.dropFirst(6))
                        if let decoded = EmojiProvider.unicode(fromCode: hex) {
                            unicodeChar = decoded
                            break
                        }
                    }
                }
                if unicodeChar == nil, let title = attrs["title"] ?? attrs["aria-label"] {
                    let clean = title.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
                    unicodeChar = EmojiProvider.character(for: clean)
                }
                if let char = unicodeChar {
                    emit(char)
                    skipUntilClose("span")
                    stack.removeLast()
                    style = previous
                    return
                }
            }
            if classes.contains("highlight") { style.highlight = true }
            if classes.contains("mention") || classes.contains("user-mention") || classes.contains("user-group-mention") {
                style.mention = true
            }
        case "time":
            if classes.contains("highlight") { style.highlight = true }
            if classes.contains("mention") || classes.contains("user-mention") || classes.contains("user-group-mention") {
                style.mention = true
            }
        default:
            break
        }
    }

    mutating func close(_ name: String) {
        if let idx = stack.lastIndex(where: { $0.0 == name }) {
            style = stack[idx].1
            stack.removeSubrange(idx...)
        }
        switch name {
        case "pre": closePre()
        case "blockquote": closeBlockquote()
        case "div": closeDiv()
        case "table": closeTable()
        case "tr": closeRow()
        case "th", "td": closeCell()
        case "a": closeLink()
        case "p", "li": closeParagraph()
        case "h1", "h2", "h3", "h4", "h5", "h6": closeHeading()
        default: break
        }
    }

    private mutating func closePre() {
        inPre = false
        let code = codeBuffer.trimmingCharacters(in: .newlines)
        codeBuffer = ""
        if !code.isEmpty { blocks.append(.code(code)) }
    }

    private mutating func closeBlockquote() {
        flushText()
        quoteDepth = max(0, quoteDepth - 1)
    }

    private mutating func closeDiv() {
        if inSpoiler {
            inSpoiler = false
            if !spoilerRuns.isEmpty {
                blocks.append(.spoiler(header: spoilerHeader, content: spoilerRuns))
            }
            spoilerRuns = []
        }
        if inVideoWrap, let href = pendingHref {
            if !blocks.contains(where: { if case .media(let src, _, _, .video) = $0 { return src == href } else { return false } }) {
                blocks.append(.media(src: href, original: nil, alt: "", kind: .video))
            }
            pendingHref = nil
            inVideoWrap = false
        }
    }

    private mutating func closeTable() {
        inTable = false
        if !tableRows.isEmpty {
            blocks.append(.table(tableRows))
        }
        tableRows = []
    }

    private mutating func closeRow() {
        if !currentRowCells.isEmpty {
            tableRows.append(TableRowData(cells: currentRowCells))
        }
        currentRowCells = []
    }

    private mutating func closeCell() {
        currentRowCells.append(currentCellRuns)
        currentCellRuns = []
    }

    private mutating func closeLink() {
        if let href = pendingHref {
            if isMediaLink(href) && !blocks.contains(where: { block in
                if case .media(let src, let original, _, _) = block {
                    if sameMedia(src, href) { return true }
                    if let original, sameMedia(original, href) { return true }
                }
                return false
            }) {
                flushText()
                let kind = MediaKind.detect(src: href, contentType: "", animated: href.lowercased().contains("gif"), tag: "img")
                blocks.append(.media(src: href, original: href, alt: "", kind: kind))
            }
        }
        pendingHref = nil
    }

    private mutating func closeParagraph() {
        if !inPre { flushText() }
    }

    private mutating func closeHeading() {
        if !inPre { flushText() }
        inHeadingLevel = nil
    }

    func mediaSource(_ attrs: [String: String]) -> String {
        let classes = attrs["class"] ?? ""
        let original = attrs["data-original-src"]
        if classes.contains("image-loading-placeholder") {
            return original ?? pendingHref ?? ""
        }
        if let original, !original.isEmpty,
           (attrs["src"] ?? "").contains("/spinner")
        {
            return original
        }
        // Animated media: prefer the real asset URL over a static thumbnail so
        // GIFs render animated (and the wrapping <a> doesn't add a duplicate).
        let animated = attrs["data-animated"] != nil || classes.contains("animated")
        if animated, let original, !original.isEmpty {
            return original
        }
        return attrs["src"] ?? original ?? pendingHref ?? ""
    }

    func sameMedia(_ first: String, _ second: String) -> Bool {
        if first == second { return true }
        guard let urlFirst = URL(string: first), let urlSecond = URL(string: second) else { return false }
        return !urlFirst.path.isEmpty && urlFirst.path == urlSecond.path
    }

    func isMediaLink(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.hasSuffix(".gif") || lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".webp")
            || lower.contains("giphy.com/media/") || lower.contains("media.giphy.com/") || lower.contains("giphy.gif")
            || lower.contains("tenor.com/view/") || lower.contains("media.tenor.com/")
    }

    mutating func emit(_ text: String) {
        guard !text.isEmpty else { return }
        if inPre {
            codeBuffer += text
            return
        }
        appendRun(text)
    }

    mutating func appendRun(_ text: String) {
        appendRun(HTMLRun(
            text: text,
            bold: style.bold,
            italic: style.italic,
            code: style.code,
            highlight: style.highlight,
            mention: style.mention,
            link: style.link
        ))
    }

    mutating func appendRun(_ run: HTMLRun) {
        if inTable {
            currentCellRuns.append(run)
            return
        }
        if inSpoiler {
            spoilerRuns.append(run)
            return
        }
        if var last = current.last, last.sameStyle(as: run) {
            last.text += run.text
            current[current.count - 1] = last
        } else {
            current.append(run)
        }
    }

    mutating func flushText() {
        let runs = current
        current = []
        let meaningful = runs.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard meaningful else { return }
        var trimmed = runs
        if var first = trimmed.first {
            while first.text.hasPrefix("\n") { first.text.removeFirst() }
            trimmed[0] = first
        }
        if var last = trimmed.last {
            while last.text.hasSuffix("\n") { last.text.removeLast() }
            trimmed[trimmed.count - 1] = last
        }
        trimmed = trimmed.filter { !$0.text.isEmpty }
        guard !trimmed.isEmpty else { return }

        if let level = inHeadingLevel {
            blocks.append(.heading(level: level, runs: trimmed))
        } else if quoteDepth > 0 {
            blocks.append(.quote(trimmed))
        } else if inSpoiler {
            spoilerRuns.append(contentsOf: trimmed)
        } else if inTable {
            currentCellRuns.append(contentsOf: trimmed)
        } else {
            blocks.append(.text(trimmed))
        }
    }

    mutating func readName() -> String {
        let start = index
        while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "-" {
            index += 1
        }
        return String(chars[start..<index])
    }

    mutating func readAttrs() -> [String: String] {
        var attrs: [String: String] = [:]
        while index < chars.count {
            skipSpaces()
            if index >= chars.count { break }
            let next = chars[index]
            if next == ">" || next == "/" { break }
            let key = readName().lowercased()
            skipSpaces()
            var value = ""
            if consume("=") {
                skipSpaces()
                if consume("\"") {
                    value = readUntil("\"")
                } else if consume("'") {
                    value = readUntil("'")
                } else {
                    value = readName()
                }
            }
            if !key.isEmpty { attrs[key] = decode(value) }
        }
        return attrs
    }

    mutating func readUntil(_ stop: Character) -> String {
        let start = index
        while index < chars.count, chars[index] != stop { index += 1 }
        let text = String(chars[start..<index])
        if index < chars.count { index += 1 }
        return text
    }

    mutating func skipUntil(_ stop: Character) {
        while index < chars.count, chars[index] != stop { index += 1 }
        if index < chars.count { index += 1 }
    }

    mutating func skipUntilClose(_ name: String) {
        let needle = "</\(name)>".lowercased()
        let remaining = String(chars[index...]).lowercased()
        if let range = remaining.range(of: needle) {
            index += remaining.distance(from: remaining.startIndex, to: range.upperBound)
        } else {
            index = chars.count
        }
    }

    mutating func skipSpaces() {
        while index < chars.count, chars[index].isWhitespace { index += 1 }
    }

    mutating func consume(_ scalar: Character) -> Bool {
        guard index < chars.count, chars[index] == scalar else { return false }
        index += 1
        return true
    }

    func decode(_ raw: String) -> String {
        var result = ""
        var idx = raw.startIndex
        while idx < raw.endIndex {
            if raw[idx] == "&", let semi = raw[idx...].firstIndex(of: ";") {
                let entity = raw[raw.index(after: idx)..<semi]
                if let decoded = decodeEntity(String(entity)) {
                    result.append(decoded)
                    idx = raw.index(after: semi)
                    continue
                }
            }
            result.append(raw[idx])
            idx = raw.index(after: idx)
        }
        return result
    }

    func decodeEntity(_ entity: String) -> String? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos", "#39": return "'"
        case "nbsp": return " "
        case "mdash": return "—"
        case "ndash": return "–"
        default:
            if entity.hasPrefix("#x") || entity.hasPrefix("#X"),
               let value = UInt32(entity.dropFirst(2), radix: 16),
               let scalar = UnicodeScalar(value)
            {
                return String(Character(scalar))
            }
            if entity.hasPrefix("#"),
               let value = UInt32(entity.dropFirst()),
               let scalar = UnicodeScalar(value)
            {
                return String(Character(scalar))
            }
            return nil
        }
    }
}

public extension MediaKind {
    static func detect(src: String, contentType: String, animated: Bool, tag: String) -> MediaKind {
        let lower = src.lowercased()
        let type = contentType.lowercased()
        if tag == "video" || type.hasPrefix("video/") || looksLikeVideo(lower) { return .video }
        if tag == "audio" || type.hasPrefix("audio/") { return .audio }
        if animated || type.contains("gif") || lower.contains(".gif") { return .gif }
        return .image
    }

    static func looksLikeVideo(_ src: String) -> Bool {
        [".mp4", ".mov", ".webm", ".m4v"].contains { src.lowercased().contains($0) }
    }
}

public enum MediaURL {
    public static func resolve(_ raw: String, site: URL) -> URL? {
        if let url = URL(string: raw), url.scheme != nil { return url }
        var base = site.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        if raw.hasPrefix("/") { return URL(string: base + raw) }
        return URL(string: raw)
    }

    public static func uploadAPIPath(for url: URL) -> String? {
        let path = url.path
        guard path.hasPrefix("/user_uploads/") else { return nil }
        if path.hasPrefix("/user_uploads/thumbnail/") || path.hasPrefix("/user_uploads/temporary/") {
            return nil
        }
        return "/api/v1" + path
    }

    public static func sharperPreview(_ src: String) -> String {
        guard src.contains("/user_uploads/thumbnail/") else { return src }
        guard let regex = try? NSRegularExpression(pattern: #"/(\d+)x(\d+)\.([A-Za-z0-9]+)$"#) else { return src }
        let range = NSRange(src.startIndex..., in: src)
        guard let match = regex.firstMatch(in: src, range: range), let found = Range(match.range, in: src) else {
            return src
        }
        return src.replacingCharacters(in: found, with: "/1920x1080.webp")
    }

    public static func needsAuth(_ url: URL, site: URL) -> Bool {
        guard url.host == site.host || url.host == nil else { return false }
        let path = url.path
        return path.hasPrefix("/user_uploads") || path.hasPrefix("/user_avatars") || path.hasPrefix("/avatar")
    }
}

private extension HTMLRun {
    func sameStyle(as other: HTMLRun) -> Bool {
        bold == other.bold
            && italic == other.italic
            && code == other.code
            && highlight == other.highlight
            && mention == other.mention
            && link == other.link
            && customEmojiURL == other.customEmojiURL
    }
}
