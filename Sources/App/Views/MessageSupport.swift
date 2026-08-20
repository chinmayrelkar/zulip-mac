import AppKit
import SwiftUI
import ZulipCore

// MARK: - Inline Emoji Image

public struct EmojiImageView: View {
    public let rawURL: String
    public let site: URL
    public var loader: MediaLoader?
    public var size: CGFloat
    public var fallback: String

    @State private var data: Data?
    @State private var failed = false

    public init(rawURL: String, site: URL, loader: MediaLoader?, size: CGFloat = 16, fallback: String = "") {
        self.rawURL = rawURL
        self.site = site
        self.loader = loader
        self.size = size
        self.fallback = fallback
    }

    public var body: some View {
        Group {
            if let data, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                Text(fallback)
                    .font(.system(size: max(9, size - 3)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .frame(width: size, height: size)
        .task(id: rawURL) {
            guard let loader else {
                failed = true
                return
            }
            if let loaded = await loader.data(for: rawURL) {
                data = loaded
            } else {
                failed = true
            }
        }
    }
}

// MARK: - Code Block Card

struct CodeBlockCard: View {
    let code: String
    @State private var isCopied = false

    var body: some View {
        VStack(spacing: 0) {
            // Window Header
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.7)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.7)).frame(width: 8, height: 8)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        isCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.08))

            Divider().opacity(0.3)

            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - AppKit Direct Scroll-to-Bottom Helper

public struct ScrollToBottomHelper: NSViewRepresentable {
    public var trigger: String

    public init(trigger: String) {
        self.trigger = trigger
    }

    public func makeNSView(context: Context) -> AutoScrollObserverView {
        AutoScrollObserverView()
    }

    public func updateNSView(_ nsView: AutoScrollObserverView, context: Context) {
        nsView.triggerScroll()
    }
}

public class AutoScrollObserverView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        triggerScroll()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        triggerScroll()
    }

    public func triggerScroll() {
        scroll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.scroll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.scroll()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.scroll()
        }
    }

    private func scroll() {
        guard let scrollView = enclosingScrollView,
              let docView = scrollView.documentView else { return }
        let maxY = max(0, docView.frame.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maxY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

public struct HoverActionBar: View {
    @Bindable var store: Store
    let message: Message
    @State private var showEmojiPicker = false

    public init(store: Store, message: Message) {
        self.store = store
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 2) {
            emojiButton("👍", code: "1f44d", name: "+1")
            emojiButton("❤️", code: "2764", name: "heart")
            emojiButton("😂", code: "1f602", name: "joy")
            emojiButton("🚀", code: "1f680", name: "rocket")
            emojiButton("💡", code: "1f4a1", name: "bulb")

            Divider().frame(height: 12).padding(.horizontal, 2)

            Button {
                showEmojiPicker.toggle()
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Add reaction")
            .popover(isPresented: $showEmojiPicker, arrowEdge: .top) {
                EmojiPickerPopover(store: store) { item in
                    showEmojiPicker = false
                    store.toggleReaction(
                        message: message,
                        emojiName: item.name,
                        emojiCode: item.code,
                        reactionType: item.isCustom ? "realm_emoji" : "unicode_emoji"
                    )
                }
            }

            actionButton(icon: "quote.opening", helpText: "Quote and reply (r)") {
                store.quoteAndReply(message: message)
            }

            actionButton(
                icon: message.isStarred ? "star.fill" : "star",
                tint: message.isStarred ? .yellow : .secondary,
                helpText: message.isStarred ? "Unstar message" : "Star message"
            ) {
                store.toggleStar(message: message)
            }

            if let streamID = message.streamID, let streamName = message.streamName {
                actionButton(icon: "arrow.up.forward.app", helpText: "Go to topic (\(streamName) › \(message.topic))") {
                    store.openTopic(streamID: streamID, streamName: streamName, topic: message.topic)
                }
            }

            if message.senderID == store.selfUserID {
                actionButton(icon: "pencil", helpText: "Edit message") {
                    store.editingMessage = message
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func emojiButton(_ char: String, code: String, name: String) -> some View {
        Button {
            store.toggleReaction(message: message, emojiName: name, emojiCode: code, reactionType: "unicode_emoji")
        } label: {
            Text(char)
                .font(.system(size: 13))
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    private func actionButton(
        icon: String,
        tint: Color = .secondary,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11.5))
                .foregroundStyle(tint)
                .padding(4)
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

public struct ReactionPillsView: View {
    @Bindable var store: Store
    let message: Message

    public init(store: Store, message: Message) {
        self.store = store
        self.message = message
    }

    public var body: some View {
        let groups = Dictionary(grouping: message.reactions, by: \.emojiName)
        HStack(spacing: 4) {
            ForEach(groups.keys.sorted(), id: \.self) { name in
                if let reactions = groups[name], let first = reactions.first {
                    let hasReacted = reactions.contains { $0.userID == store.selfUserID }
                    let display = EmojiProvider.display(
                        name: first.emojiName,
                        code: first.emojiCode,
                        type: first.reactionType,
                        realmEmojis: store.realmEmojis
                    )
                    Button {
                        store.toggleReaction(
                            message: message,
                            emojiName: first.emojiName,
                            emojiCode: first.emojiCode,
                            reactionType: first.reactionType
                        )
                    } label: {
                        HStack(spacing: 4) {
                            switch display {
                            case .unicode(let sym):
                                Text(sym)
                                    .font(.system(size: 12))
                            case .custom(let url, let alt):
                                if url.isEmpty {
                                    Text(":\(alt):")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else {
                                    EmojiImageView(
                                        rawURL: url,
                                        site: store.site,
                                        loader: store.media,
                                        size: 14,
                                        fallback: ":\(alt):"
                                    )
                                }
                            }
                            Text("\(reactions.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(hasReacted ? Color.accentColor : Color.secondary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            hasReacted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().stroke(
                                hasReacted ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.15),
                                lineWidth: 0.5
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .help(reactionTooltip(reactions))
                }
            }
        }
    }

    private func reactionTooltip(_ list: [Reaction]) -> String {
        guard let first = list.first else { return "" }
        let display = EmojiProvider.display(
            name: first.emojiName,
            code: first.emojiCode,
            type: first.reactionType,
            realmEmojis: store.realmEmojis
        )
        let symbol: String
        switch display {
        case .unicode(let char): symbol = char
        case .custom(_, let name): symbol = ":\(name):"
        }
        let names = list.map { reaction in
            reaction.userID == store.selfUserID
                ? "You"
                : (store.user(reaction.userID)?.fullName ?? "#\(reaction.userID)")
        }
        return "\(symbol) \(names.joined(separator: ", "))"
    }
}

public struct ReadReceiptsView: View {
    let readers: [Int]
    @Bindable var store: Store

    public init(readers: [Int], store: Store) {
        self.readers = readers
        self.store = store
    }

    public var body: some View {
        HStack(spacing: -5) {
            ForEach(readers.prefix(4), id: \.self) { userID in
                let user = store.user(userID)
                AvatarView(
                    userID: userID,
                    avatarURL: user?.avatarURL,
                    email: user?.email ?? "",
                    site: store.site,
                    loader: store.media,
                    size: 16
                )
            }
            if readers.count > 4 {
                Text("+\(readers.count - 4)")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showReaderMenu() }
        .help(Self.readerNames(readers, store: store))
    }

    private func showReaderMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(
            title: readers.count == 1 ? "Read by 1 person" : "Read by \(readers.count) people",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(header)
        menu.addItem(.separator())
        for userID in readers {
            let name = store.user(userID)?.fullName ?? "#\(userID)"
            let title = userID == store.selfUserID ? "\(name) (You)" : name
            menu.addItem(NSMenuItem(title: title, action: nil, keyEquivalent: ""))
        }
        if let event = NSApp.currentEvent, let view = NSApp.keyWindow?.contentView {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
        }
    }

    private static func readerNames(_ readers: [Int], store: Store) -> String {
        let names = readers.compactMap { store.user($0)?.fullName ?? "#\($0)" }
        return names.isEmpty ? "Seen by nobody yet" : "Seen by: \(names.joined(separator: ", "))"
    }
}
