import AppKit
import SwiftUI
import ZulipCore

public struct MessageColumn: View {
    @Bindable var store: Store

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !store.tabs.isEmpty {
                TabStrip(store: store)
                Divider().opacity(0.6)
            }
            if let tab = store.activeTab {
                ConversationHeader(store: store, tab: tab)
                Divider().opacity(0.6)
                MessageList(store: store, tab: tab)
                    .id(tab.id)
                if tab.narrow.isConversation {
                    ComposeBar(store: store, tab: tab)
                }
            } else {
                ShortcutHelpView(embedded: true)
            }
        }
    }
}

public struct TabStrip: View {
    @Bindable var store: Store
    @Environment(AppSettings.self) private var settings

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(store.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabItemView(tab: tab, store: store, isFirst: index == 0)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 32)

        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }
}

private struct TabItemView: View {
    let tab: ConversationTab
    @Bindable var store: Store
    @Environment(AppSettings.self) private var settings
    var isFirst: Bool = false
    @State private var isHovered = false

    private var isActive: Bool {
        tab.id == store.activeTabID
    }

    var body: some View {
        Button {
            store.activate(tab.id)
        } label: {
            HStack(spacing: 6) {
                tabIcon

                if tab.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if store.threads[tab.id]?.isLoading == true {
                    ProgressView().controlSize(.mini)
                }

                Text(store.tabTitle(tab))
                    .font(.system(size: settings.uiSecondarySize, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .lineLimit(1)

                if tab.unreadSinceOpen > 0 && !isActive {
                    Text("\(tab.unreadSinceOpen)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                        .monospacedDigit()
                }

                // Close Button
                Button {
                    store.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isActive ? Color.secondary : Color.secondary.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .background(isHovered ? Color.secondary.opacity(0.15) : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
                .opacity((isActive || isHovered) ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                isActive
                    ? Color(nsColor: .windowBackgroundColor)
                    : (isHovered ? Color.secondary.opacity(0.06) : Color.clear)
            )
            .overlay {
                if isActive {
                    // Top & side borders and open bottom to merge seamlessly with conversation view
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        Spacer()
                    }
                } else {
                    // Vertical separator between inactive tabs
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 1, height: 14)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(tab.pinned ? "Unpin Tab" : "Pin Tab") { store.togglePin(tab.id) }
            Button("Close Tab") { store.closeTab(tab.id) }
            Button("Close Other Tabs") {
                for other in store.tabs where other.id != tab.id {
                    store.closeTab(other.id)
                }
            }
        }
        .frame(minWidth: 100, maxWidth: 220)
    }

    @ViewBuilder
    private var tabIcon: some View {
        switch tab.narrow {
        case .topic(let streamID, _, _):
            let channel = store.channel(id: streamID)
            Text("#")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: channel?.color ?? "888888"))
        case .dm:
            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.teal)
        case .allMessages:
            Image(systemName: "tray.2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.indigo)
        case .recentTopics:
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
        case .mentions:
            Image(systemName: "at")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
        case .starred:
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
        case .search:
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

public struct ConversationHeader: View {
    @Bindable var store: Store
    let tab: ConversationTab
    @Environment(AppSettings.self) private var settings

    public init(store: Store, tab: ConversationTab) {
        self.store = store
        self.tab = tab
    }

    public var body: some View {
        HStack(spacing: 8) {
            switch tab.narrow {
            case .topic(let streamID, let streamName, let topic):
                let channel = store.channel(id: streamID)
                Text("#")
                    .font(.system(size: settings.uiFontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: channel?.color ?? "888888"))

                Text(streamName)
                    .font(.system(size: settings.uiFontSize, weight: .bold))

                Image(systemName: "chevron.right")
                    .font(.system(size: settings.uiSmallSize, weight: .semibold))
                    .foregroundStyle(.secondary)

                if topic.hasPrefix("✔") || topic.hasPrefix("✅") {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: settings.uiSecondarySize))
                        .foregroundStyle(.green)
                }

                Text(topic.isEmpty ? "(no topic)" : topic)
                    .font(.system(size: settings.uiFontSize, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button {
                    Task { await store.toggleResolveTopic(streamID: streamID, topic: topic) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: topic.hasPrefix("✔") ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(topic.hasPrefix("✔") ? "Resolved" : "Resolve")
                    }
                    .font(.system(size: settings.uiSecondarySize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Toggle topic resolved status")

                Button {
                    Task { await store.toggleMuteTopic(streamID: streamID, topic: topic) }
                } label: {
                    let isMuted = store.mutedTopics.contains("\(streamID):\(topic)")
                    HStack(spacing: 4) {
                        Image(systemName: isMuted ? "bell.slash.fill" : "bell")
                        Text(isMuted ? "Unmute" : "Mute")
                    }
                    .font(.system(size: settings.uiSecondarySize))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Mute or unmute this topic")

            case .dm(let userIDs):
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.teal)
                Text(store.dmTitle(RecentDM(userIDs: userIDs, maxMessageID: 0)))
                    .font(.system(size: settings.uiFontSize, weight: .bold))
                Spacer()

            case .allMessages:
                Image(systemName: "tray.2.fill")
                    .foregroundStyle(.indigo)
                Text("All messages")
                    .font(.system(size: settings.uiFontSize, weight: .bold))
                Spacer()

            case .recentTopics:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text("Recent conversations")
                    .font(.system(size: settings.uiFontSize, weight: .bold))
                Spacer()

                Toggle(isOn: $store.showMutedInRecent) {
                    HStack(spacing: 4) {
                        Image(systemName: store.showMutedInRecent ? "bell.slash.fill" : "bell.slash")
                        Text("Include Muted")
                    }
                    .font(.system(size: 11.5))
                }
                .toggleStyle(.button)
                .controlSize(.small)

                Toggle(isOn: $store.showUnreadOnlyInRecent) {
                    HStack(spacing: 4) {
                        Image(systemName: store.showUnreadOnlyInRecent ? "envelope.badge.fill" : "envelope")
                        Text("Unread Only")
                    }
                    .font(.system(size: 11.5))
                }
                .toggleStyle(.button)
                .controlSize(.small)

            case .mentions:
                Image(systemName: "at")
                    .foregroundStyle(.orange)
                Text("Mentions")
                    .font(.system(size: 13, weight: .bold))
                Spacer()

            case .starred:
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Starred messages")
                    .font(.system(size: 13, weight: .bold))
                Spacer()

            case .search(let query, _, _):
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search: \(query)")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

public struct MessageList: View {
    @Bindable var store: Store
    let tab: ConversationTab
    @Environment(AppSettings.self) private var settings
    @Environment(\.focusedColumn) private var focusedColumn
    @FocusState private var isMessageListFocused: Bool

    public init(store: Store, tab: ConversationTab) {
        self.store = store
        self.tab = tab
    }

    public var body: some View {
        let thread = store.threads[tab.id] ?? MessageThread()
        let visibleMessages: [Message] = {
            if tab.narrow == .allMessages {
                return thread.messages.filter { msg in
                    if let streamID = msg.streamID {
                        if store.channel(id: streamID)?.isMuted == true { return false }
                        if store.mutedTopics.contains("\(streamID):\(msg.topic)") { return false }
                    }
                    return true
                }
            }
            return thread.messages
        }()

        let currentIndex = visibleMessages.firstIndex(where: { $0.id == store.selectedMessageID }) ?? (visibleMessages.count - 1)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: settings.density.listSpacing) {
                    if !thread.foundOldest && !visibleMessages.isEmpty {
                        Button {
                            store.loadOlder(for: tab.id)
                        } label: {
                            HStack(spacing: 6) {
                                if thread.isLoading {
                                    ProgressView().controlSize(.mini)
                                }
                                Text("Load older messages")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(thread.isLoading)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    ForEach(Self.sections(visibleMessages), id: \.day) { section in
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 0.5)
                            Text(MessageTime.dayLabel(section.day))
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(.regularMaterial, in: Capsule())
                                .overlay(Capsule().stroke(Color.secondary.opacity(0.15), lineWidth: 0.5))
                            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 0.5)
                        }
                        .padding(.vertical, 8)

                        ForEach(Self.blocks(from: section.messages)) { block in
                            MessageBlockView(store: store, block: block)
                        }
                    }

                    // Direct child sentinel and AppKit scroll engine
                    ScrollToBottomHelper(trigger: "\(tab.id):\(visibleMessages.count):\(visibleMessages.last?.id ?? 0):\(thread.isLoading)")
                        .frame(height: 1)
                        .id("BOTTOM_SENTINEL")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)
            .focusable()
            .focusEffectDisabled()
            .focused($isMessageListFocused)
            .onKeyPress(.downArrow) {
                guard isMessageListFocused else { return .ignored }
                if currentIndex < visibleMessages.count - 1 {
                    store.selectedMessageID = visibleMessages[currentIndex + 1].id
                    return .handled
                }
                return .handled
            }
            .onKeyPress(keys: ["j"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if currentIndex < visibleMessages.count - 1 {
                    store.selectedMessageID = visibleMessages[currentIndex + 1].id
                    return .handled
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard isMessageListFocused else { return .ignored }
                if currentIndex > 0 {
                    store.selectedMessageID = visibleMessages[currentIndex - 1].id
                    return .handled
                } else if !thread.foundOldest {
                    store.loadOlder(for: tab.id)
                    return .handled
                }
                return .handled
            }
            .onKeyPress(keys: ["k"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if currentIndex > 0 {
                    store.selectedMessageID = visibleMessages[currentIndex - 1].id
                    return .handled
                } else if !thread.foundOldest {
                    store.loadOlder(for: tab.id)
                    return .handled
                }
                return .handled
            }
            .onKeyPress(.pageDown) {
                guard isMessageListFocused else { return .ignored }
                let next = min(currentIndex + 5, visibleMessages.count - 1)
                if visibleMessages.indices.contains(next) {
                    store.selectedMessageID = visibleMessages[next].id
                }
                return .handled
            }
            .onKeyPress(.pageUp) {
                guard isMessageListFocused else { return .ignored }
                let prev = max(currentIndex - 5, 0)
                if visibleMessages.indices.contains(prev) {
                    store.selectedMessageID = visibleMessages[prev].id
                }
                return .handled
            }
            .onKeyPress(.home) {
                guard isMessageListFocused else { return .ignored }
                if let first = visibleMessages.first {
                    store.selectedMessageID = first.id
                }
                return .handled
            }
            .onKeyPress(.end) {
                guard isMessageListFocused else { return .ignored }
                if let last = visibleMessages.last {
                    store.selectedMessageID = last.id
                }
                return .handled
            }
            .onKeyPress(.return) {
                guard isMessageListFocused else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    store.quoteAndReply(message: msg)
                    focusedColumn.wrappedValue = .composer
                    store.focusComposerTrigger += 1
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["r", "q"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    store.quoteAndReply(message: msg)
                    focusedColumn.wrappedValue = .composer
                    store.focusComposerTrigger += 1
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["i", "a"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if tab.narrow.isConversation {
                    focusedColumn.wrappedValue = .composer
                    store.focusComposerTrigger += 1
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["s"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    store.toggleStar(message: msg)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["e"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }), msg.senderID == store.selfUserID {
                    store.editingMessage = msg
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["d"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }), msg.senderID == store.selfUserID {
                    Task { await store.deleteMessage(messageID: msg.id) }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.delete) {
                guard isMessageListFocused else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }), msg.senderID == store.selfUserID {
                    Task { await store.deleteMessage(messageID: msg.id) }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["c"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    let text = MessageHTML.plain(msg.displayHTML)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["l"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    let link = "\(store.site.absoluteString)/#narrow/id/\(msg.id)"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(link, forType: .string)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["h"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }), msg.lastEdit != nil {
                    Task { await store.loadHistory(for: msg) }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["v", "g"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }), let streamID = msg.streamID, let streamName = msg.streamName {
                    store.openTopic(streamID: streamID, streamName: streamName, topic: msg.topic)
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["1", "2", "3", "4", "5"]) { press in
                guard isMessageListFocused, !press.modifiers.contains(.command), !press.modifiers.contains(.option), !press.modifiers.contains(.control) else { return .ignored }
                if let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) {
                    let quickEmoji: [(String, String, String)] = [
                        ("1", "+1", "1f44d"),
                        ("2", "heart", "2764"),
                        ("3", "joy", "1f602"),
                        ("4", "rocket", "1f680"),
                        ("5", "bulb", "1f4a1")
                    ]
                    if let item = quickEmoji.first(where: { $0.0 == press.characters }) {
                        store.toggleReaction(message: msg, emojiName: item.1, emojiCode: item.2, reactionType: "unicode_emoji")
                        return .handled
                    }
                }
                return .ignored
            }
            .onKeyPress(.space) {
                guard isMessageListFocused else { return .ignored }
                if openMediaLightboxForSelectedMessage(in: visibleMessages) {
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.leftArrow) {
                guard isMessageListFocused else { return .ignored }
                if store.showCenterPane && store.hasTopicsForSelectedSource {
                    focusedColumn.wrappedValue = .topics
                    store.focusTopicListTrigger += 1
                } else {
                    focusedColumn.wrappedValue = .sidebar
                }
                return .handled
            }
            .onKeyPress(.escape) {
                guard isMessageListFocused else { return .ignored }
                if store.showCenterPane && store.hasTopicsForSelectedSource {
                    focusedColumn.wrappedValue = .topics
                    store.focusTopicListTrigger += 1
                } else {
                    focusedColumn.wrappedValue = .sidebar
                }
                return .handled
            }
            .onAppear {
                if store.selectedMessageID == nil {
                    store.selectedMessageID = visibleMessages.last?.id
                }
            }
            .overlay {
                if thread.isLoading && thread.messages.isEmpty {
                    ProgressView("Loading messages…")
                } else if thread.messages.isEmpty && !thread.isLoading {
                    ContentUnavailableView("No messages", systemImage: "tray")
                }
            }
            .onChange(of: focusedColumn.wrappedValue) { _, new in
                if new == .messages {
                    isMessageListFocused = true
                    if store.selectedMessageID == nil || !visibleMessages.contains(where: { $0.id == store.selectedMessageID }) {
                        store.selectedMessageID = visibleMessages.last?.id
                    }
                }
            }
            .onChange(of: store.focusMessagesTrigger) { _, _ in
                isMessageListFocused = true
                if store.selectedMessageID == nil || !visibleMessages.contains(where: { $0.id == store.selectedMessageID }) {
                    store.selectedMessageID = visibleMessages.last?.id
                }
            }
            .onChange(of: store.selectedMessageID) { _, id in
                if let id, isMessageListFocused {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .onChange(of: thread.messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: thread.isLoading) { _, loading in
                if !loading {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: visibleMessages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func openMediaLightboxForSelectedMessage(in visibleMessages: [Message]) -> Bool {
        guard let msg = visibleMessages.first(where: { $0.id == store.selectedMessageID }) else { return false }
        let resolved = HTMLRewrite.resolve(msg.displayHTML, site: store.site)
        let blocks = MessageHTML.blocks(resolved)
        for block in blocks {
            if case .media(let src, let original, let alt, let kind) = block {
                if kind == .image || kind == .gif {
                    Task {
                        let displaySrc = MediaURL.sharperPreview(src)
                        let fullSrc = (original != nil && !original!.isEmpty) ? original! : displaySrc
                        if let data = await store.media?.data(firstOf: [displaySrc, src, original ?? ""]) {
                            store.lightbox = LightboxItem(src: displaySrc, fullSrc: fullSrc, data: data, alt: alt, kind: kind)
                        }
                    }
                    return true
                }
            }
        }
        return false
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = false) {
        if animated {
            withAnimation(.easeOut(duration: 0.12)) {
                proxy.scrollTo("BOTTOM_SENTINEL", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("BOTTOM_SENTINEL", anchor: .bottom)
        }
    }


    private struct DaySection {
        var day: Date
        var messages: [Message]
    }

    private static func sections(_ messages: [Message]) -> [(day: Date, messages: [Message])] {
        let calendar = Calendar.current
        var groups: [(day: Date, messages: [Message])] = []
        for msg in messages {
            let start = calendar.startOfDay(for: msg.timestamp)
            if let last = groups.last, calendar.isDate(last.day, inSameDayAs: start) {
                groups[groups.count - 1].messages.append(msg)
            } else {
                groups.append((day: start, messages: [msg]))
            }
        }
        return groups
    }

    public struct MessageBlock: Identifiable {
        public var id: Int { messages.first?.id ?? 0 }
        public var messages: [Message]
        public var senderID: Int
        public var streamID: Int?
        public var streamName: String?
        public var topic: String
    }

    public static func blocks(from messages: [Message]) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        for msg in messages {
            if let last = blocks.last,
               last.senderID == msg.senderID,
               last.streamID == msg.streamID,
               last.topic == msg.topic,
               let lastMsg = last.messages.last,
               msg.timestamp.timeIntervalSince(lastMsg.timestamp) < 300 {
                blocks[blocks.count - 1].messages.append(msg)
            } else {
                blocks.append(MessageBlock(
                    messages: [msg],
                    senderID: msg.senderID,
                    streamID: msg.streamID,
                    streamName: msg.streamName,
                    topic: msg.topic
                ))
            }
        }
        return blocks
    }
}

public struct MessageBlockView: View {
    @Bindable var store: Store
    public let block: MessageList.MessageBlock
    @State private var isBlockHovered = false

    private var blockHoverStroke: Color {
        guard let streamID = block.streamID, let channel = store.channel(id: streamID) else {
            return Color.secondary.opacity(0.24)
        }
        return Color(hex: channel.color).opacity(0.45)
    }

    public init(store: Store, block: MessageList.MessageBlock) {
        self.store = store
        self.block = block
    }

    public var body: some View {
        let isFeed = !(store.activeTab?.narrow.isConversation ?? true)
        let showChannelBanner = isFeed && block.streamID != nil

        VStack(alignment: .leading, spacing: 0) {
            if showChannelBanner, let streamID = block.streamID, let streamName = block.streamName {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: store.channel(id: streamID)?.color ?? "888888"))
                        .frame(width: 7, height: 7)

                    Text(streamName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text("›")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Text(block.topic.isEmpty ? "(no topic)" : block.topic)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        store.openTopic(streamID: streamID, streamName: streamName, topic: block.topic)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Go to topic")
                                .font(.system(size: 10.5, weight: .semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Go to topic in \(streamName)")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.04))

                Rectangle().fill(Color.secondary.opacity(0.10)).frame(height: 0.5)
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(block.messages.enumerated()), id: \.element.id) { index, message in
                    if index > 0 {
                        Rectangle().fill(Color.secondary.opacity(0.08)).frame(height: 0.5)
                            .padding(.leading, 44)
                    }
                    SingleMessageRow(
                        store: store,
                        message: message,
                        isFirstInBlock: index == 0
                    )
                    .id(message.id)
                }
            }
            .padding(.vertical, 4)
        }
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.40),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    isBlockHovered ? blockHoverStroke : Color.secondary.opacity(0.10),
                    lineWidth: 0.8
                )
        )
        .onHover { isBlockHovered = $0 }
        .padding(.vertical, 3)
    }
}

public struct SingleMessageRow: View {
    @Bindable var store: Store
    public let message: Message
    public let isFirstInBlock: Bool
    @State private var isHovering = false
    @Environment(AppSettings.self) private var settings
    @Environment(\.focusedColumn) private var focusedColumn

    public init(store: Store, message: Message, isFirstInBlock: Bool) {
        self.store = store
        self.message = message
        self.isFirstInBlock = isFirstInBlock
    }

    public var body: some View {
        let isKeyboardSelected = store.selectedMessageID == message.id && (focusedColumn.wrappedValue == .messages)

        HStack(alignment: .top, spacing: 10) {
            if isFirstInBlock {
                Button {
                    if let user = store.user(message.senderID) {
                        store.selectedUserForProfile = user
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(userID: message.senderID, avatarURL: message.avatarURL, email: message.senderEmail, site: store.site, loader: store.media, size: 30)

                        let presence = store.presences[message.senderID]?.status ?? .offline
                        if presence != .offline {
                            Circle()
                                .fill(presence == .active ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                .offset(x: 1, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(isHovering ? MessageTime.timeLabel(message.timestamp) : "")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .frame(width: 30, alignment: .trailing)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                if isFirstInBlock {
                    HStack(spacing: 8) {
                        Button {
                            if let user = store.user(message.senderID) {
                                store.selectedUserForProfile = user
                            }
                        } label: {
                            Text(message.senderName)
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .buttonStyle(.plain)

                        if let status = store.userStatuses[message.senderID], let text = status.statusText, !text.isEmpty {
                            Text(text)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.1), in: Capsule())
                        }

                        Text(MessageTime.timeLabel(message.timestamp))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .help(MessageTime.fullLabel(message.timestamp))

                        if message.lastEdit != nil {
                            Button {
                                Task { await store.loadHistory(for: message) }
                            } label: {
                                Text("edited")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Click to view edit history")
                        }

                        if message.isStarred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.yellow)
                        }

                        Spacer()
                    }
                }

                // Message Rich Body
                MessageBody(
                    html: message.displayHTML,
                    site: store.site,
                    media: store.media,
                    onOpenImage: { store.lightbox = $0 }
                )

                // Reactions Bar
                if !message.reactions.isEmpty {
                    ReactionPillsView(store: store, message: message)
                        .padding(.top, 2)
                }

                // Read Receipts — bottom of the message, right-aligned
                if let readers = store.readReceipts[message.id], !readers.isEmpty {
                    HStack {
                        Spacer()
                        ReadReceiptsView(readers: readers, store: store)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, settings.density.rowSpacing(isFirst: isFirstInBlock))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovering ? hoverRowColor : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isKeyboardSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                HoverActionBar(store: store, message: message)
                    .offset(y: -10)
                    .padding(.trailing, 8)
            }
        }
        .onHover { isHovering = $0 }
        .task(id: message.id) {
            store.loadReadReceipts(for: message.id)
        }
        .contextMenu {
            Button("Add Reaction…") {
                NSApp.orderFrontCharacterPalette(nil)
            }
            Button(message.isStarred ? "Unstar message" : "Star message") {
                store.toggleStar(message: message)
            }
            Button("Quote and reply") {
                store.quoteAndReply(message: message)
            }
            if message.senderID == store.selfUserID {
                Button("Edit message") {
                    store.editingMessage = message
                }
                Button("Delete message", role: .destructive) {
                    Task { await store.deleteMessage(messageID: message.id) }
                }
            }
            Divider()
            Button("Copy link to message") {
                let link = "\(store.site.absoluteString)/#narrow/id/\(message.id)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link, forType: .string)
            }
            Button("Copy raw text") {
                let text = MessageHTML.plain(message.displayHTML)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            if message.lastEdit != nil {
                Button("View edit history") {
                    Task { await store.loadHistory(for: message) }
                }
            }
        }
    }

    private var hoverRowColor: Color {
        guard let streamID = message.streamID, let channel = store.channel(id: streamID) else {
            return Color.secondary.opacity(0.06)
        }
        return Color(hex: channel.color).opacity(0.12)
    }
}

public struct MessageRow: View {
    @Bindable var store: Store
    public let message: Message
    public let isFollowup: Bool

    public init(store: Store, message: Message, isFollowup: Bool) {
        self.store = store
        self.message = message
        self.isFollowup = isFollowup
    }

    public var body: some View {
        SingleMessageRow(store: store, message: message, isFirstInBlock: !isFollowup)
    }
}

public struct MessageBody: View {
    public let html: String
    public var site: URL = Auth.defaultSite
    public var media: MediaLoader?
    public var onOpenImage: ((LightboxItem) -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppSettings.self) private var settings
    @State private var emojiImages: [String: NSImage] = [:]

    public init(
        html: String,
        site: URL = Auth.defaultSite,
        media: MediaLoader? = nil,
        onOpenImage: ((LightboxItem) -> Void)? = nil
    ) {
        self.html = html
        self.site = site
        self.media = media
        self.onOpenImage = onOpenImage
    }

    public var body: some View {
        let resolved = HTMLRewrite.resolve(html, site: site)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(MessageHTML.blocks(resolved).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let runs):
                    Self.text(
                        runs,
                        emojiImages: emojiImages,
                        dark: colorScheme == .dark,
                        fontSize: headingFontSize(level),
                        fontFamily: settings.fontFamily
                    )
                        .font(headingFont(level))
                        .fontWeight(.bold)
                        .padding(.top, level == 1 ? 5 : (level == 2 ? 3 : 1))
                        .padding(.bottom, 1)
                        .fixedSize(horizontal: false, vertical: true)
                case .text(let runs):
                    inline(runs)
                case .quote(let runs):
                    HStack(alignment: .top, spacing: 8) {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 3)
                        inline(runs)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .fixedSize(horizontal: false, vertical: true)
                case .spoiler(let header, let runs):
                    DisclosureGroup(header) {
                        inline(runs)
                            .padding(.top, 4)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(8)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                case .table(let rows):
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                            HStack(spacing: 12) {
                                ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                    inline(cell)
                                        .frame(minWidth: 70, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                rowIndex == 0
                                    ? Color.secondary.opacity(0.1)
                                    : (rowIndex % 2 == 1 ? Color.clear : Color.secondary.opacity(0.04))
                            )
                            if rowIndex < rows.count - 1 {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                    .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                case .code(let code):
                    CodeBlockCard(code: code)
                case .media(let src, let original, let alt, let kind):
                    MediaBlockView(
                        src: src,
                        original: original,
                        alt: alt,
                        kind: kind,
                        loader: media,
                        onOpen: onOpenImage
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: html) { await loadCustomEmojis() }
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        let base = settings.fontSize
        switch level {
        case 1: return base * 1.33
        case 2: return base * 1.15
        case 3: return base * 1.04
        default: return base
        }
    }

    private func headingFont(_ level: Int) -> Font {
        let size = headingFontSize(level)
        if settings.fontFamily == "System Default" {
            return .system(size: size, weight: .semibold)
        }
        return .custom(settings.fontFamily, size: size)
    }

    private func inline(_ runs: [HTMLRun]) -> some View {
        Self.text(
            runs,
            emojiImages: emojiImages,
            dark: colorScheme == .dark,
            fontSize: settings.fontSize,
            fontFamily: settings.fontFamily
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func loadCustomEmojis() async {
        guard let media else { return }
        let resolved = HTMLRewrite.resolve(html, site: site)
        let urls = MessageHTML.runs(resolved).compactMap(\.customEmojiURL)
        for url in urls where emojiImages[url] == nil {
            if let data = await media.data(for: url), let image = NSImage(data: data) {
                emojiImages[url] = image
            }
        }
    }

    private static func text(
        _ runs: [HTMLRun],
        emojiImages: [String: NSImage],
        dark: Bool,
        fontSize: CGFloat = 13.5,
        fontFamily: String = "System Default"
    ) -> Text {
        let hasCustomEmoji = runs.contains { run in
            if let url = run.customEmojiURL, emojiImages[url] != nil { return true }
            return false
        }

        if !hasCustomEmoji {
            var full = AttributedString()
            for run in runs {
                full.append(piece(run, dark: dark, fontSize: fontSize, fontFamily: fontFamily))
            }
            return Text(full)
        }

        var combined = Text("")
        var currentChunk = AttributedString()
        for run in runs {
            if let url = run.customEmojiURL, let image = emojiImages[url] {
                if !currentChunk.characters.isEmpty {
                    combined = combined + Text(currentChunk)
                    currentChunk = AttributedString()
                }
                combined = combined + Text(Image(nsImage: resized(image, to: fontSize + 3)))
            } else {
                currentChunk.append(piece(run, dark: dark, fontSize: fontSize, fontFamily: fontFamily))
            }
        }
        if !currentChunk.characters.isEmpty {
            combined = combined + Text(currentChunk)
        }
        return combined
    }

    private static func piece(
        _ run: HTMLRun,
        dark: Bool,
        fontSize: CGFloat,
        fontFamily: String
    ) -> AttributedString {
        var piece = AttributedString(run.text)
        var font: Font
        if fontFamily == "System Default" {
            font = Font.system(size: fontSize)
        } else {
            font = Font.custom(fontFamily, size: fontSize)
        }
        if run.bold { font = font.bold() }
        if run.italic { font = font.italic() }
        if run.code { font = .system(size: max(11, fontSize - 1), design: .monospaced) }
        piece.font = font
        if let link = run.link, let url = URL(string: link) {
            piece.link = url
            piece.foregroundColor = dark ? Color(hex: "64d2ff") : Color(hex: "0b57d0")
            piece.underlineStyle = .single
        }
        if run.highlight {
            piece.backgroundColor = dark ? Color(hex: "8a6d1b") : Color(hex: "ffe566")
        }
        if run.mention {
            piece.backgroundColor = dark ? Color(hex: "2a3f66") : Color(hex: "dce8ff")
        }
        return piece
    }

    private static func resized(_ image: NSImage, to size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let out = NSImage(size: target)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .sourceOver, fraction: 1)
        out.unlockFocus()
        return out
    }
}
