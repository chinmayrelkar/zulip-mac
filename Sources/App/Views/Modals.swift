import AppKit
import SwiftUI
import ZulipCore

public struct QuickSwitcherView: View {
    @Bindable var store: Store
    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var sections: [QuickSection] = []
    @State private var flattenedItems: [QuickItem] = []
    @FocusState private var isFocused: Bool

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)

                TextField("Type a channel, topic, or person…", text: $query)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        activateCurrentSelection()
                    }
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                        rebuildItems()
                    }
                    .onKeyPress(.downArrow) {
                        let total = flattenedItems.count
                        if total > 0 {
                            selectedIndex = min(selectedIndex + 1, total - 1)
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        store.showQuickSwitcher = false
                        return .handled
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.showQuickSwitcher = false
                } label: {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.regularMaterial)

            Divider().opacity(0.6)

            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if sections.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .padding(.top, 24)
                                Text("No results found for \"\(query)\"")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Try searching for a channel name, topic, or person")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(sections) { section in
                                sectionHeader(section.title)
                                ForEach(section.items) { item in
                                    let isSelected = item.globalIndex == selectedIndex
                                    itemRow(item: item, isSelected: isSelected)
                                        .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 360)
                .onChange(of: selectedIndex) { _, idx in
                    if idx >= 0 && idx < flattenedItems.count {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(flattenedItems[idx].id, anchor: .center)
                        }
                    }
                }
            }

            Divider().opacity(0.6)

            // Footer Shortcuts
            HStack(spacing: 12) {
                shortcutHint("↑↓", "Navigate")
                shortcutHint("↵", "Open")
                shortcutHint("esc", "Close")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .onAppear {
            rebuildItems()
            isFocused = true
        }
        .onExitCommand { store.showQuickSwitcher = false }
    }

    private func itemRow(item: QuickItem, isSelected: Bool) -> some View {
        Button {
            activateItem(item)
        } label: {
            HStack(spacing: 8) {
                switch item.kind {
                case .channel(let channel):
                    Text("#")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: channel.color))
                        .frame(width: 16)

                    Text(channel.name)
                        .font(.system(size: 13, weight: .medium))

                    Spacer()

                    Text("Channel")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                case .topic(_, let streamName, let streamColor, let topic):
                    Circle()
                        .fill(Color(hex: streamColor))
                        .frame(width: 6, height: 6)

                    Text(streamName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)

                    Text("›")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text(topic.isEmpty ? "(no topic)" : topic)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer()

                    Text("Topic")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                case .user(let user):
                    AvatarView(userID: user.userID, avatarURL: user.avatarURL, email: user.email, site: store.site, loader: store.media, size: 20)

                    Text(user.fullName)
                        .font(.system(size: 13, weight: .medium))

                    Text(user.email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text("Direct Message")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private struct QuickItem: Identifiable, Hashable {
        enum Kind: Hashable {
            case channel(Channel)
            case topic(streamID: Int, streamName: String, streamColor: String, topic: String)
            case user(User)
        }

        var id: String
        var globalIndex: Int
        var kind: Kind
    }

    private struct QuickSection: Identifiable {
        var id: String { title }
        var title: String
        var items: [QuickItem]
    }

    private func rebuildItems() {
        var newSections: [QuickSection] = []
        var allItems: [QuickItem] = []
        var runningIndex = 0

        // Channels
        let channelMatches = matchingChannels()
        if !channelMatches.isEmpty {
            var items: [QuickItem] = []
            for ch in channelMatches {
                let item = QuickItem(id: "ch-\(ch.streamID)", globalIndex: runningIndex, kind: .channel(ch))
                items.append(item)
                allItems.append(item)
                runningIndex += 1
            }
            newSections.append(QuickSection(title: "CHANNELS", items: items))
        }

        // Topics
        let topicMatches = matchingTopics()
        if !topicMatches.isEmpty {
            var items: [QuickItem] = []
            for topic in topicMatches {
                let item = QuickItem(
                    id: "top-\(topic.streamID)-\(topic.topic)",
                    globalIndex: runningIndex,
                    kind: .topic(
                        streamID: topic.streamID,
                        streamName: topic.streamName,
                        streamColor: topic.streamColor,
                        topic: topic.topic
                    )
                )
                items.append(item)
                allItems.append(item)
                runningIndex += 1
            }
            newSections.append(QuickSection(title: "TOPICS", items: items))
        }

        // People
        let userMatches = matchingUsers()
        if !userMatches.isEmpty {
            var items: [QuickItem] = []
            for user in userMatches {
                let item = QuickItem(id: "user-\(user.userID)", globalIndex: runningIndex, kind: .user(user))
                items.append(item)
                allItems.append(item)
                runningIndex += 1
            }
            newSections.append(QuickSection(title: "PEOPLE", items: items))
        }

        self.sections = newSections
        self.flattenedItems = allItems
        if selectedIndex >= allItems.count {
            selectedIndex = max(0, allItems.count - 1)
        }
    }

    private func activateCurrentSelection() {
        guard selectedIndex >= 0 && selectedIndex < flattenedItems.count else { return }
        activateItem(flattenedItems[selectedIndex])
    }

    private func activateItem(_ item: QuickItem) {
        switch item.kind {
        case .channel(let channel):
            store.selectChannel(channel.streamID)
        case .topic(let streamID, let streamName, _, let topic):
            store.openTopic(streamID: streamID, streamName: streamName, topic: topic)
        case .user(let user):
            store.openDM(with: [user.userID])
        }
        store.showQuickSwitcher = false
    }

}

private extension QuickSwitcherView {
    private struct TopicMatch: Hashable {
        var streamID: Int
        var streamName: String
        var streamColor: String
        var topic: String
    }

    private struct TopicHit {
        var streamID: Int
        var streamName: String
        var streamColor: String
        var topic: String
        var score: Int
    }

    private func channelRelevanceScore(_ channel: Channel) -> Int {
        var score = 0
        if channel.pinToTop { score += 10000 }
        let unreadCount = store.unread.channelCount(channel.streamID)
        if unreadCount > 0 {
            score += 2000 + min(unreadCount * 20, 1500)
        }
        if let maxActivity = store.channelActivity[channel.streamID] {
            score += min(maxActivity / 1000, 1000)
        } else if let topics = store.topicsByStream[channel.streamID], let maxTopicID = topics.map(\.maxID).max() {
            score += min(maxTopicID / 1000, 1000)
        }
        if channel.isMuted { score -= 5000 }
        return score
    }

    private func matchingChannels() -> [Channel] {
        if query.isEmpty {
            return store.channels
                .sorted { channelRelevanceScore($0) > channelRelevanceScore($1) }
                .prefix(6)
                .map { $0 }
        }
        let term = query.lowercased()
        var scoredMatches: [(channel: Channel, matchScore: Int)] = []

        for channel in store.channels {
            let name = channel.name.lowercased()
            var matchScore = 0

            if name == term {
                matchScore += 10000
            } else if name.hasPrefix(term) {
                matchScore += 5000
            } else if name.contains("/" + term) || name.contains("-" + term) || name.contains("_" + term) {
                matchScore += 3000
            } else if name.contains(term) {
                matchScore += 1000
            } else {
                continue
            }

            matchScore += channelRelevanceScore(channel)
            scoredMatches.append((channel, matchScore))
        }

        return scoredMatches
            .sorted { $0.matchScore > $1.matchScore }
            .prefix(6)
            .map(\.channel)
    }

    private func matchingUsers() -> [User] {
        if query.isEmpty { return [] }
        let term = query.lowercased()
        var matches: [(user: User, score: Int)] = []
        for user in store.users.values {
            guard user.userID != store.selfUserID else { continue }
            let name = user.fullName.lowercased()
            let email = user.email.lowercased()
            var score = 0
            if name == term {
                score += 10000
            } else if name.hasPrefix(term) {
                score += 5000
            } else if name.contains(" " + term) {
                score += 3000
            } else if name.contains(term) || email.contains(term) {
                score += 1000
            } else {
                continue
            }
            if store.presences[user.userID]?.status == .active { score += 500 }
            matches.append((user, score))
        }
        return matches.sorted { $0.score > $1.score }.prefix(6).map(\.user)
    }

    private func matchingTopics() -> [TopicMatch] {
        if query.isEmpty {
            var list: [TopicMatch] = []
            let rankedChannels = store.channels.sorted { channelRelevanceScore($0) > channelRelevanceScore($1) }
            for channel in rankedChannels.prefix(8) {
                guard let topics = store.topicsByStream[channel.streamID] else { continue }
                let sortedTopics = topics.sorted { lhs, rhs in
                    let lUnread = store.unread.stream[channel.streamID]?[lhs.name]?.count ?? 0
                    let rUnread = store.unread.stream[channel.streamID]?[rhs.name]?.count ?? 0
                    if (lUnread > 0) != (rUnread > 0) { return lUnread > 0 }
                    return lhs.maxID > rhs.maxID
                }
                for topic in sortedTopics.prefix(2) {
                    list.append(
                        TopicMatch(
                            streamID: channel.streamID,
                            streamName: channel.name,
                            streamColor: channel.color,
                            topic: topic.name
                        )
                    )
                    if list.count >= 8 { return list }
                }
            }
            return list
        }
        let term = query.lowercased()
        var results: [TopicHit] = []
        for channel in store.channels {
            guard let topics = store.topicsByStream[channel.streamID] else { continue }
            let channelMatches = channel.name.lowercased().contains(term)
            let baseScore = channelRelevanceScore(channel) / 2
            for topic in topics {
                let topicName = topic.name.lowercased()
                guard let matchScore = topicScore(topicName, term: term, channelMatches: channelMatches) else { continue }
                results.append(
                    TopicHit(
                        streamID: channel.streamID,
                        streamName: channel.name,
                        streamColor: channel.color,
                        topic: topic.name,
                        score: matchScore + baseScore
                    )
                )
            }
        }
        return results.sorted { $0.score > $1.score }.prefix(8).map { hit in
            TopicMatch(
                streamID: hit.streamID,
                streamName: hit.streamName,
                streamColor: hit.streamColor,
                topic: hit.topic
            )
        }
    }

    private func topicScore(_ topicName: String, term: String, channelMatches: Bool) -> Int? {
        if topicName == term { return 8000 }
        if topicName.hasPrefix(term) { return 4000 }
        if topicName.contains(term) { return 2000 }
        if channelMatches { return 1000 }
        return nil
    }
}

public struct NewDMModal: View {
    @Bindable var store: Store
    @State private var query = ""
    @State private var selectedUserIDs: Set<Int> = []

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Direct Message")
                .font(.title3.weight(.bold))

            if !selectedUserIDs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(selectedUserIDs), id: \.self) { uid in
                            if let user = store.user(uid) {
                                HStack(spacing: 5) {
                                    Text(user.fullName)
                                        .font(.system(size: 12, weight: .medium))
                                    Button {
                                        selectedUserIDs.remove(uid)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3.5)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            TextField("Search by name or email…", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            List {
                ForEach(filteredUsers) { user in
                    HStack(spacing: 10) {
                        AvatarView(userID: user.userID, avatarURL: user.avatarURL, email: user.email, site: store.site, loader: store.media, size: 28)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(user.fullName)
                                .font(.system(size: 13, weight: .medium))
                            Text(user.email)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedUserIDs.contains(user.userID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedUserIDs.contains(user.userID) {
                            selectedUserIDs.remove(user.userID)
                        } else {
                            selectedUserIDs.insert(user.userID)
                        }
                    }
                }
            }
            .frame(height: 240)
            .listStyle(.plain)

            HStack {
                Button("Cancel") {
                    store.showNewDMModal = false
                }
                Spacer()
                Button("Start Conversation") {
                    store.openDM(with: Array(selectedUserIDs))
                    store.showNewDMModal = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedUserIDs.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var filteredUsers: [User] {
        let all = store.users.values.filter { $0.userID != store.selfUserID && $0.isActive }
        if query.isEmpty { return Array(all.sorted { $0.fullName < $1.fullName }) }
        return all.filter {
            $0.fullName.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query)
        }.sorted { $0.fullName < $1.fullName }
    }
}

public struct ChannelBrowserModal: View {
    @Bindable var store: Store
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isInputFocused: Bool

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "number")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.accentColor)

                TextField("Filter channels…", text: $query)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .onSubmit {
                        openSelected()
                    }
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                    .onKeyPress(.downArrow) {
                        let total = filteredStreams.count
                        if total > 0 {
                            selectedIndex = min(selectedIndex + 1, total - 1)
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        store.showChannelBrowser = false
                        return .handled
                    }
                    .onKeyPress(.space) {
                        toggleSelectedJoin()
                        return .handled
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.showChannelBrowser = false
                } label: {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.regularMaterial)

            Divider().opacity(0.6)

            // Channels List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if filteredStreams.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "number")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .padding(.top, 24)
                                Text("No channels found for \"\(query)\"")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Try searching with a different keyword")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(Array(filteredStreams.enumerated()), id: \.element.streamID) { idx, channel in
                                let isSelected = idx == selectedIndex
                                let isSubscribed = store.channels.contains(where: { $0.streamID == channel.streamID })
                                ChannelBrowserRowView(
                                    channel: channel,
                                    isSubscribed: isSubscribed,
                                    isSelected: isSelected,
                                    onSelect: {
                                        selectedIndex = idx
                                    },
                                    onOpen: {
                                        store.selectChannel(channel.streamID)
                                        store.showChannelBrowser = false
                                    },
                                    onToggle: {
                                        toggleChannelSubscription(channel: channel, isSubscribed: isSubscribed)
                                    }
                                )
                                .id(channel.streamID)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(height: 320)
                .onChange(of: selectedIndex) { _, idx in
                    if idx >= 0 && idx < filteredStreams.count {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(filteredStreams[idx].streamID, anchor: .center)
                        }
                    }
                }
            }

            Divider().opacity(0.6)

            // Footer
            HStack(spacing: 12) {
                shortcutHint("↑↓", "Navigate")
                shortcutHint("↵", "Open Channel")
                shortcutHint("Space", "Join / Leave")
                shortcutHint("esc", "Close")

                Spacer()

                Button("Close") {
                    store.showChannelBrowser = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Open Channel") {
                    openSelected()
                }
                .buttonStyle(.borderedProminent)
                .disabled(filteredStreams.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .onAppear { isInputFocused = true }
        .onExitCommand { store.showChannelBrowser = false }
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var filteredStreams: [Channel] {
        if query.isEmpty { return store.channels }
        let term = query.lowercased()
        return store.channels.filter {
            $0.name.lowercased().contains(term) || $0.description.lowercased().contains(term)
        }
    }

    private func openSelected() {
        let streams = filteredStreams
        guard selectedIndex >= 0 && selectedIndex < streams.count else { return }
        let channel = streams[selectedIndex]
        store.selectChannel(channel.streamID)
        store.showChannelBrowser = false
    }

    private func toggleSelectedJoin() {
        let streams = filteredStreams
        guard selectedIndex >= 0 && selectedIndex < streams.count else { return }
        let channel = streams[selectedIndex]
        let isSubscribed = store.channels.contains(where: { $0.streamID == channel.streamID })
        toggleChannelSubscription(channel: channel, isSubscribed: isSubscribed)
    }

    private func toggleChannelSubscription(channel: Channel, isSubscribed: Bool) {
        if isSubscribed {
            store.channels.removeAll { $0.streamID == channel.streamID }
        } else {
            store.channels.append(channel)
        }
    }
}

public struct MessageEditSheet: View {
    @Bindable var store: Store
    let message: Message
    @State private var content: String
    @State private var topic: String
    @State private var propagateMode = "change_one"

    public init(store: Store, message: Message) {
        self.store = store
        self.message = message
        _content = State(initialValue: MessageHTML.plain(message.displayHTML))
        _topic = State(initialValue: message.topic)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Message")
                .font(.headline)

            if message.type == "stream" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Topic").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextField("Topic", text: $topic)
                        .textFieldStyle(.roundedBorder)

                    Picker("Topic change affects", selection: $propagateMode) {
                        Text("This message only").tag("change_one")
                        Text("This and later messages").tag("change_later")
                        Text("All messages in topic").tag("change_all")
                    }
                    .pickerStyle(.segmented)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Message").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                TextEditor(text: $content)
                    .font(.system(size: 13))
                    .frame(height: 120)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            }

            HStack {
                Button("Cancel") { store.editingMessage = nil }
                Spacer()
                Button("Save Changes") {
                    Task {
                        await store.editMessage(
                            messageID: message.id,
                            content: content,
                            topic: topic != message.topic ? topic : nil,
                            propagateMode: propagateMode
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

public struct MessageHistorySheet: View {
    @Bindable var store: Store
    let message: Message

    public init(store: Store, message: Message) {
        self.store = store
        self.message = message
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit History")
                .font(.headline)

            List(store.historyItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(MessageTime.fullLabel(Date(timeIntervalSince1970: item.timestamp)))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    if let prev = item.prevContent {
                        Text(prev)
                            .font(.system(size: 12.5))
                            .padding(8)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    if let prevTop = item.prevTopic {
                        Text("Moved from topic: \(prevTop)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 280)
            .listStyle(.plain)

            HStack {
                Spacer()
                Button("Close") { store.viewingHistoryForMessage = nil }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
