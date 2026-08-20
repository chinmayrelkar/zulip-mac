import AppKit
import SwiftUI
import ZulipCore

public struct TopicSidebar: View {
    @Bindable var store: Store
    @Environment(\.focusedColumn) private var focusedColumn
    @FocusState private var isListFocused: Bool
    @State private var keyboardIndex = 0

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Search & Filters
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField(filterPlaceholder, text: $store.topicQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !store.topicQuery.isEmpty {
                        Button {
                            store.topicQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                )

                if store.selectedSource == .recentTopics {
                    HStack(spacing: 6) {
                        Menu {
                            Picker("Sort order", selection: $store.recentSortOrder) {
                                Label("Newest on top", systemImage: "arrow.up").tag(TopicSortOrder.newestFirst)
                                Label("Newest at bottom", systemImage: "arrow.down").tag(TopicSortOrder.newestLast)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.recentSortOrder == .newestLast ? "arrow.down" : "arrow.up")
                                    .font(.system(size: 10))
                                Text(store.recentSortOrder.rawValue)
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        Toggle(isOn: $store.showMutedInRecent) {
                            HStack(spacing: 4) {
                                Image(systemName: store.showMutedInRecent ? "bell.slash.fill" : "bell.slash")
                                    .font(.system(size: 10))
                                Text("Muted")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(.button)
                        .controlSize(.mini)
                        .help("Include muted channels and topics")

                        Toggle(isOn: $store.showUnreadOnlyInRecent) {
                            HStack(spacing: 4) {
                                Image(systemName: store.showUnreadOnlyInRecent ? "envelope.badge.fill" : "envelope")
                                    .font(.system(size: 10))
                                Text("Unread")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(.button)
                        .controlSize(.mini)
                        .help("Show only conversations with unread messages")

                        Spacer()

                        Text("\(store.recentConversations.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else if store.selectedSource == .mentions {
                    HStack(spacing: 6) {
                        Menu {
                            Picker("Sort order", selection: $store.mentionsSortOrder) {
                                Label("Newest at bottom", systemImage: "arrow.down").tag(TopicSortOrder.newestLast)
                                Label("Newest on top", systemImage: "arrow.up").tag(TopicSortOrder.newestFirst)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.mentionsSortOrder == .newestLast ? "arrow.down" : "arrow.up")
                                    .font(.system(size: 10))
                                Text(store.mentionsSortOrder.rawValue)
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        Toggle(isOn: $store.mentionsUnreadOnly) {
                            HStack(spacing: 4) {
                                Image(systemName: store.mentionsUnreadOnly ? "envelope.badge.fill" : "envelope")
                                    .font(.system(size: 10))
                                Text("Unread")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(.button)
                        .controlSize(.mini)

                        Spacer()

                        Text("\(store.mentionConversations.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } else if case .channel = store.selectedSource {
                    HStack(spacing: 6) {
                        Menu {
                            Picker("Sort order", selection: $store.channelTopicsSortOrder) {
                                Label("Newest on top", systemImage: "arrow.up").tag(TopicSortOrder.newestFirst)
                                Label("Newest at bottom", systemImage: "arrow.down").tag(TopicSortOrder.newestLast)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: store.channelTopicsSortOrder == .newestLast ? "arrow.down" : "arrow.up")
                                    .font(.system(size: 10))
                                Text(store.channelTopicsSortOrder.rawValue)
                                    .font(.system(size: 11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        let resolvedCount = store.totalResolvedCountInSelectedChannel
                        if resolvedCount > 0 {
                            Toggle(isOn: $store.showResolvedInChannel) {
                                HStack(spacing: 4) {
                                    Image(systemName: store.showResolvedInChannel ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.system(size: 10))
                                    Text(store.showResolvedInChannel ? "Resolved" : "Resolved")
                                        .font(.system(size: 11))
                                }
                            }
                            .toggleStyle(.button)
                            .controlSize(.mini)
                        }

                        Spacer()

                        Text("\(store.visibleTopics.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)

            Divider().opacity(0.6)

            // Content List
            switch store.selectedSource {
            case .recentTopics:
                recentTopicsList
            case .mentions:
                mentionsTopicsList
            case .directMessages:
                dmList
            case .channel(let id):
                channelTopicList(streamID: id)
            case .allMessages, .starred, nil:
                feedInfoView
            }
        }
        .focused($isListFocused)
        .onKeyPress(.downArrow) {
            let count = keyboardItemCount
            if count > 0 { keyboardIndex = min(keyboardIndex + 1, count - 1) }
            return .handled
        }
        .onKeyPress(.upArrow) {
            keyboardIndex = max(keyboardIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            keyboardOpenSelection()
            return .handled
        }
        .onChange(of: store.focusTopicListTrigger) { _, _ in
            isListFocused = true
            keyboardIndex = 0
        }
        .onChange(of: focusedColumn.wrappedValue) { _, new in
            if new == .topics { isListFocused = true }
        }
        .onChange(of: store.selectedSource) { _, _ in
            keyboardIndex = 0
        }
        .navigationTitle(title)
        .toolbar {
            if case .channel(let id) = store.selectedSource, let channel = store.channel(id: id) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.openTopic(streamID: channel.streamID, streamName: channel.name, topic: "new topic")
                    } label: {
                        Label("New Topic", systemImage: "plus")
                    }
                    .help("New topic in \(channel.name)")
                }
            }
        }
    }

}

private extension TopicSidebar {

    private var keyboardItemCount: Int {
        switch store.selectedSource {
        case .recentTopics: store.recentConversations.count
        case .mentions: store.mentionConversations.count
        case .directMessages: store.visibleDMs.count
        case .channel: store.visibleTopics.count
        default: 0
        }
    }

    private func keyboardOpenSelection() {
        let idx = keyboardIndex
        switch store.selectedSource {
        case .recentTopics:
            if store.recentConversations.indices.contains(idx) {
                let item = store.recentConversations[idx]
                store.openTopic(streamID: item.streamID, streamName: item.streamName, topic: item.topic)
            }
        case .mentions:
            if store.mentionConversations.indices.contains(idx) {
                let item = store.mentionConversations[idx]
                store.openTopic(streamID: item.streamID, streamName: item.streamName, topic: item.topic)
            }
        case .directMessages:
            if store.visibleDMs.indices.contains(idx) {
                store.openDM(store.visibleDMs[idx])
            }
        case .channel:
            if store.visibleTopics.indices.contains(idx) {
                store.openTopic(store.visibleTopics[idx])
            }
        default:
            break
        }
    }

    private func keyboardHighlight(index: Int) -> Color {
        index == keyboardIndex && isListFocused
            ? Color.accentColor.opacity(0.15)
            : Color.clear
    }
    private var filterPlaceholder: String {
        switch store.selectedSource {
        case .recentTopics: "Filter recent conversations…"
        case .mentions: "Filter mentions by topic or channel…"
        case .directMessages: "Filter direct messages…"
        case .channel: "Filter topics…"
        default: "Filter…"
        }
    }

    private var title: String {
        switch store.selectedSource {
        case .recentTopics: "Recent conversations"
        case .allMessages: "All messages"
        case .mentions: "Mentions"
        case .starred: "Starred messages"
        case .directMessages: "Direct messages"
        case .channel(let id): store.channel(id: id)?.name ?? "Topics"
        case nil: "Topics"
        }
    }

    private var recentTopicsList: some View {
        List(Array(store.recentConversations.enumerated()), id: \.element.id) { index, item in
            RecentTopicRowView(item: item, store: store)
                .listRowInsets(EdgeInsets(top: 2.5, leading: 8, bottom: 2.5, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(keyboardHighlight(index: index))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.recentConversations.isEmpty {
                ContentUnavailableView("No conversations", systemImage: "clock")
            }
        }
    }

    private var mentionsTopicsList: some View {
        ScrollViewReader { proxy in
            List(store.mentionConversations, id: \.id) { item in
                RecentTopicRowView(item: item, store: store)
                    .id(item.id)
                    .listRowInsets(EdgeInsets(top: 2.5, leading: 8, bottom: 2.5, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .defaultScrollAnchor(store.mentionsSortOrder == .newestLast ? .bottom : .top)
            .onAppear {
                scrollMentionsToEdge(proxy: proxy)
            }
            .task {
                try? await Task.sleep(nanoseconds: 80_000_000)
                scrollMentionsToEdge(proxy: proxy)
            }
            .onChange(of: store.mentionsSortOrder) { _, _ in
                withAnimation {
                    scrollMentionsToEdge(proxy: proxy)
                }
            }
            .onChange(of: store.mentionConversations.count) { _, _ in
                scrollMentionsToEdge(proxy: proxy)
            }
            .overlay {
                if store.mentionConversations.isEmpty {
                    ContentUnavailableView(
                        "No mentions yet",
                        systemImage: "at",
                        description: Text("Conversations where you are mentioned will appear here by time chronology.")
                    )
                }
            }
        }
    }

    private func scrollMentionsToEdge(proxy: ScrollViewProxy) {
        if store.mentionsSortOrder == .newestLast {
            if let last = store.mentionConversations.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            if let first = store.mentionConversations.first {
                proxy.scrollTo(first.id, anchor: .top)
            }
        }
    }

    private func channelTopicList(streamID: Int) -> some View {
        List {
            ForEach(store.visibleTopics, id: \.name) { topic in
                TopicRowView(
                    topic: topic,
                    unread: store.unread.topicCount(streamID, topic: topic.name),
                    isMuted: store.mutedTopics.contains("\(streamID):\(topic.name)"),
                    streamID: streamID,
                    store: store
                )
                .listRowInsets(EdgeInsets(top: 2.5, leading: 8, bottom: 2.5, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !store.showResolvedInChannel && store.totalResolvedCountInSelectedChannel > 0 {
                Button {
                    store.showResolvedInChannel = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 11))
                        Text("Show \(store.totalResolvedCountInSelectedChannel) resolved topics")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.visibleTopics.isEmpty {
                ContentUnavailableView("No topics", systemImage: "text.bubble")
            }
        }
    }

    private var dmList: some View {
        List(store.visibleDMs, id: \.key) { dm in
            DMRowView(dm: dm, store: store)
                .listRowInsets(EdgeInsets(top: 2.5, leading: 8, bottom: 2.5, trailing: 8))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.visibleDMs.isEmpty {
                ContentUnavailableView("No direct messages", systemImage: "person.2")
            }
        }
    }

    private var feedInfoView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray.2.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
            Text("Stream feed displayed in the conversation column.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var topicSelection: Binding<String?> {
        Binding(
            get: { store.selectedTopic },
            set: { name in
                guard let name, let topic = store.visibleTopics.first(where: { $0.name == name }) else { return }
                store.openTopic(topic)
            }
        )
    }

    private var dmSelection: Binding<String?> {
        Binding(
            get: { store.selectedDMKey },
            set: { key in
                guard let key, let dm = store.visibleDMs.first(where: { $0.key == key }) else { return }
                store.openDM(dm)
            }
        )
    }
}

private struct RecentTopicRowView: View {
    @Environment(AppSettings.self) private var settings
    let item: RecentTopicItem
    @Bindable var store: Store
    @State private var isHovered = false

    var body: some View {
        Button {
            store.openTopic(streamID: item.streamID, streamName: item.streamName, topic: item.topic)
        } label: {
            HStack(spacing: 6) {
                Text("#")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: item.streamColor))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(item.streamName)
                            .font(.system(size: settings.uiSecondarySize, weight: .semibold))
                            .foregroundStyle(.secondary)
                        if item.isResolved {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(item.topic.isEmpty ? "(no topic)" : item.topic)
                        .font(.system(size: settings.uiFontSize, weight: item.unreadCount > 0 ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(item.isMuted ? Color.secondary.opacity(0.65) : Color.primary)
                }

                Spacer()

                if item.unreadCount > 0 {
                    Text("\(item.unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .contextMenu {
            Button(item.isResolved ? "Unmark as resolved" : "Mark as resolved") {
                Task { await store.toggleResolveTopic(streamID: item.streamID, topic: item.topic) }
            }
            Button(item.isMuted ? "Unmute topic" : "Mute topic") {
                Task { await store.toggleMuteTopic(streamID: item.streamID, topic: item.topic) }
            }
        }
    }
}

private struct TopicRowView: View {
    @Environment(AppSettings.self) private var settings
    let topic: Topic
    let unread: Int
    let isMuted: Bool
    let streamID: Int
    @Bindable var store: Store
    @State private var isHovered = false

    var body: some View {
        Button {
            store.openTopic(topic)
        } label: {
            HStack(spacing: 6) {
                if topic.isResolved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
                Text(topic.displayName.isEmpty ? "(no topic)" : topic.displayName)
                    .font(.system(size: settings.uiFontSize, weight: unread > 0 ? .semibold : .regular))
                    .lineLimit(1)
                    .strikethrough(topic.isResolved)
                    .foregroundStyle(isMuted ? Color.secondary.opacity(0.65) : Color.primary)

                Spacer()

                if isMuted {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .contextMenu {
            Button(topic.isResolved ? "Unmark as resolved" : "Mark as resolved") {
                Task { await store.toggleResolveTopic(streamID: streamID, topic: topic.name) }
            }
            Button(isMuted ? "Unmute topic" : "Mute topic") {
                Task { await store.toggleMuteTopic(streamID: streamID, topic: topic.name) }
            }
        }
    }
}

private struct DMRowView: View {
    @Environment(AppSettings.self) private var settings
    let dm: RecentDM
    @Bindable var store: Store
    @State private var isHovered = false

    var body: some View {
        Button {
            store.openDM(dm)
        } label: {
            HStack(spacing: 8) {
                let firstUser = dm.userIDs.first.flatMap { store.user($0) }
                let unreadCount = store.unread.dmCount(userIDs: dm.userIDs, selfID: store.selfUserID)

                AvatarView(userID: firstUser?.userID ?? 0, avatarURL: firstUser?.avatarURL, email: firstUser?.email ?? "", site: store.site, loader: store.media, size: 22)
                .overlay(alignment: .bottomTrailing) {
                    let presence = firstUser.flatMap { store.presences[$0.userID]?.status } ?? .offline
                    if presence != .offline {
                        Circle()
                            .fill(presenceColor(presence))
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1))
                    }
                }

                Text(store.dmTitle(dm))
                    .font(.system(size: settings.uiFontSize, weight: unreadCount > 0 ? .semibold : .regular))
                    .lineLimit(1)

                Spacer()

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.accentColor, in: Capsule())
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
    }

    private func presenceColor(_ status: PresenceStatus) -> Color {
        switch status {
        case .active: .green
        case .idle: .orange
        default: .gray
        }
    }
}
