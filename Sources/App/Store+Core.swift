import AppKit
import UserNotifications
import ZulipCore

extension Store {

    // MARK: - Accessors

    public func channel(id: Int) -> Channel? {
        channels.first { $0.streamID == id }
    }

    public func user(_ id: Int) -> User? {
        users[id]
    }

    public func dmTitle(_ dm: RecentDM) -> String {
        let names = dm.userIDs.filter { $0 != selfUserID }.compactMap { users[$0]?.fullName }
        if names.isEmpty {
            return dm.userIDs.map(String.init).joined(separator: ",")
        }
        return names.joined(separator: ", ")
    }

    public func tabTitle(_ tab: ConversationTab) -> String {
        switch tab.narrow {
        case .topic(_, let stream, let topic):
            return "\(stream) › \(topic)"
        case .dm(let ids):
            let names = ids.filter { $0 != selfUserID }.compactMap { users[$0]?.fullName }
            return names.isEmpty ? "Direct message" : names.joined(separator: ", ")
        default:
            return tab.narrow.title
        }
    }

    // MARK: - Mentions

    public func mergeMentions(_ messages: [Message]) {
        guard !messages.isEmpty else { return }
        var map = Dictionary(uniqueKeysWithValues: mentionsMessages.map { ($0.id, $0) })
        for msg in messages {
            map[msg.id] = msg
        }
        mentionsMessages = map.values.sorted { $0.id > $1.id }
    }

    public func loadMentions() {
        guard let client else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await client.messages(
                    narrow: [NarrowTerm(op: "is", operand: .string("mentioned"))],
                    anchor: "newest",
                    before: 100,
                    after: 0
                )
                self.mergeMentions(page.messages)
            } catch {}
        }
    }

    // MARK: - Persistence

    public func loadCachedState() {
        guard let state = LocalCache.loadState() else { return }
        channels = state.channels
        users = Dictionary(uniqueKeysWithValues: state.users.map { ($0.userID, $0) })
        topicsByStream = state.topicsByStream
        channelActivity = state.channelActivity
        mutedTopics = Set(state.mutedTopics)
        dms = state.dms
        unread = state.unread
        realmName = state.realmName
        selfUserID = state.selfUserID
        selfEmail = state.selfEmail
    }

    public func persistState() {
        LocalCache.saveState(CachedAppState(
            channels: channels,
            users: Array(users.values),
            topicsByStream: topicsByStream,
            channelActivity: channelActivity,
            mutedTopics: Array(mutedTopics),
            dms: dms,
            unread: unread,
            realmName: realmName,
            selfUserID: selfUserID,
            selfEmail: selfEmail
        ))
    }

    // MARK: - Lifecycle

    public func start() async {
        loadCachedState()
        if let credentials = Auth.load() {
            await connect(credentials)
        } else {
            session = .loggedOut
        }
    }

    public func login(site: String, email: String, password: String) async {
        guard let siteURL = Auth.siteURL(site) else {
            errorMessage = "Invalid server URL"
            return
        }
        isBusy = true
        status = "Logging in…"
        do {
            let credentials = try await ZulipClient.login(site: siteURL, username: email, password: password)
            try Auth.save(credentials)
            await connect(credentials)
        } catch {
            isBusy = false
            status = nil
            session = .loggedOut
            errorMessage = error.localizedDescription
        }
    }

    public func logout() {
        eventsTask?.cancel()
        eventsTask = nil
        topicsTask?.cancel()
        topicsTask = nil
        typingTimer?.cancel()
        typingTimer = nil
        for task in loadTasks.values { task.cancel() }
        loadTasks = [:]
        client = nil
        media = nil
        Auth.clear()
        LocalCache.clearAll()
        session = .loggedOut
        status = nil
        isBusy = false
        channels = []
        users = [:]
        topicsByStream = [:]
        channelActivity = [:]
        mutedTopics = []
        dms = []
        unread = UnreadState()
        realmEmojis = [:]
        presences = [:]
        userStatuses = [:]
        typingUsers = [:]
        mentionsMessages = []
        tabs = []
        activeTabID = nil
        threads = [:]
        historyItems = []
        errorMessage = nil
    }

    public func connect(_ credentials: Credentials) async {
        let client = ZulipClient(credentials: credentials)
        self.client = client
        self.site = credentials.site
        isBusy = true
        status = "Connecting…"
        session = .connecting
        do {
            let snap = try await client.register()
            media = MediaLoader(client: client, site: credentials.site)
            apply(snap)
            requestNotifications()
            loadMentions()
            startEventLoop()
            startTypingTimer()
            try? await client.updatePresence(status: "active")
            session = .ready
            isBusy = false
            status = nil
        } catch {
            isBusy = false
            status = nil
            session = .loggedOut
            errorMessage = error.localizedDescription
        }
    }

    private func startEventLoop() {
        eventsTask?.cancel()
        guard let client, let queueID else { return }
        eventsTask = Task { [weak self] in
            var lastID = self?.lastEventID ?? -1
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let result = try await client.events(queueID: queueID, lastEventID: lastID)
                    lastID = result.lastID
                    self.applyEvents(result.events, lastID: lastID)
                } catch is CancellationError {
                    return
                } catch let error as APIError where error.isDeadQueue {
                    await self.reconnect()
                    return
                } catch {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
    }

    private func startTypingTimer() {
        typingTimer?.cancel()
        typingTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self?.reportTyping()
            }
        }
    }

    // MARK: - Sidebar selection

    public func selectRecentTopics() {
        selectedSource = .recentTopics
        selectedTopic = nil
        selectedDMKey = nil
    }

    public func selectAllMessages() {
        selectedSource = .allMessages
        open(.allMessages)
    }

    public func selectMentions() {
        selectedSource = .mentions
        selectedTopic = nil
        selectedDMKey = nil
    }

    public func selectStarred() {
        selectedSource = .starred
        open(.starred)
    }

    public func selectDMs() {
        selectedSource = .directMessages
        selectedTopic = nil
        selectedDMKey = nil
    }

    public func selectChannel(_ id: Int) {
        selectedSource = .channel(id)
        selectedTopic = nil
        selectedDMKey = nil
        showCenterPane = true
        if topicsByStream[id] == nil {
            loadTopics(id)
        }
    }

    // MARK: - Opening conversations

    public func openTopic(_ topic: Topic, preferNew: Bool? = nil) {
        guard case .channel(let id) = selectedSource, let channel = channel(id: id) else { return }
        open(.topic(streamID: id, streamName: channel.name, topic: topic.name), preferNew: preferNew ?? commandHeld)
    }

    public func openTopic(streamID: Int, streamName: String, topic: String, preferNew: Bool? = nil) {
        open(.topic(streamID: streamID, streamName: streamName, topic: topic), preferNew: preferNew ?? commandHeld)
    }

    public func openDM(_ dm: RecentDM, preferNew: Bool? = nil) {
        open(.dm(userIDs: Array(Set(dm.userIDs + [selfUserID])).sorted()), preferNew: preferNew ?? commandHeld)
    }

    public func openDM(with userIDs: [Int], preferNew: Bool? = nil) {
        open(.dm(userIDs: Array(Set(userIDs + [selfUserID])).sorted()), preferNew: preferNew ?? commandHeld)
    }

    public func submitSearch(_ rawQuery: String) {
        let parsed = Search.parse(rawQuery, context: searchContext)
        if let conversation = parsed.conversation {
            open(conversation, preferNew: true)
            return
        }
        open(Narrow.search(query: parsed.query, terms: parsed.terms, anchor: parsed.anchor), preferNew: true)
    }

    private func open(_ narrow: Narrow, preferNew: Bool = false) {
        if !preferNew, let existing = tabs.first(where: { $0.narrow == narrow }) {
            activeTabID = existing.id
            syncSelection(to: narrow)
            return
        }
        let tab = ConversationTab(narrow: narrow)
        tabs.append(tab)
        activeTabID = tab.id
        syncSelection(to: narrow)
        focusComposerTrigger += 1
        if let cached = LocalCache.loadThreadMessages(key: cacheKey(for: narrow)) {
            threads[tab.id] = MessageThread(messages: cached, foundOldest: false, foundNewest: true, isLoading: false)
        }
        loadTabMessages(for: tab.id)
    }

    // MARK: - Tabs

    public func activate(_ id: ConversationTab.ID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        activeTabID = id
        syncSelection(to: tab.narrow)
        if threads[id] == nil {
            loadTabMessages(for: id)
        }
    }

    public func closeTab(_ id: ConversationTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        loadTasks[id]?.cancel()
        loadTasks[id] = nil
        tabs.remove(at: index)
        if activeTabID == id {
            if index < tabs.count {
                activeTabID = tabs[index].id
            } else {
                activeTabID = tabs.last?.id
            }
            if let next = tabs.first(where: { $0.id == activeTabID }) {
                syncSelection(to: next.narrow)
            } else {
                activeTabID = nil
                selectedSource = .recentTopics
            }
        }
    }

    public func closeActiveTab() {
        if let id = activeTabID { closeTab(id) }
    }

    public func cycleTab(_ delta: Int) {
        guard !tabs.isEmpty else { return }
        let current = tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
        let next = (current + delta + tabs.count) % tabs.count
        activate(tabs[next].id)
    }

    public func togglePin(_ id: ConversationTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].pinned.toggle()
    }

    public func setDraft(_ text: String) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].draft = text
    }

    // MARK: - Sending & reactions

    public func send() async {
        guard let tab = activeTab, let client else { return }
        let content = tab.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        do {
            _ = try await client.send(narrow: tab.narrow, content: content)
            if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                tabs[index].draft = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleReaction(message: Message, emojiName: String, emojiCode: String = "", reactionType: String = "unicode_emoji") {
        let hasReacted = message.reactions.contains { $0.userID == selfUserID && $0.emojiName == emojiName }
        for key in threads.keys {
            guard var thread = threads[key], let index = thread.messages.firstIndex(where: { $0.id == message.id }) else { continue }
            if hasReacted {
                thread.messages[index].reactions.removeAll {
                    $0.userID == selfUserID && $0.emojiName == emojiName
                }
            } else {
                thread.messages[index].reactions.append(Reaction(
                    emojiName: emojiName,
                    userID: selfUserID,
                    emojiCode: emojiCode,
                    reactionType: reactionType
                ))
            }
            threads[key] = thread
        }
        Task { [weak self] in
            guard let self, let client = self.client else { return }
            do {
                if hasReacted {
                    try await client.removeReaction(messageID: message.id, emojiName: emojiName, emojiCode: emojiCode, reactionType: reactionType)
                } else {
                    try await client.addReaction(messageID: message.id, emojiName: emojiName, emojiCode: emojiCode, reactionType: reactionType)
                }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func toggleStar(message: Message) {
        let star = !message.isStarred
        for key in threads.keys {
            guard var thread = threads[key], let index = thread.messages.firstIndex(where: { $0.id == message.id }) else { continue }
            if star { thread.messages[index].flags.insert("starred") } else { thread.messages[index].flags.remove("starred") }
            threads[key] = thread
        }
        Task { [weak self] in
            guard let self, let client = self.client else { return }
            try? await client.toggleStar(messageIDs: [message.id], star: star)
        }
    }

    public func editMessage(messageID: Int, content: String? = nil, topic: String? = nil, propagateMode: String = "change_one") async {
        guard let client else { return }
        do {
            try await client.editMessage(messageID: messageID, content: content, topic: topic, propagateMode: propagateMode)
            editingMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func deleteMessage(messageID: Int) async {
        guard let client else { return }
        do {
            try await client.deleteMessage(messageID: messageID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func loadHistory(for message: Message) async {
        guard let client else { return }
        do {
            let items = try await client.getMessageHistory(messageID: message.id)
            historyItems = items
            viewingHistoryForMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func quoteAndReply(message: Message) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        let quote = MessageHTML.quoteMarkdown(from: message)
        let current = tabs[index].draft
        tabs[index].draft = current.isEmpty ? quote : current + "\n\n" + quote
    }

    public func uploadAttachment(filename: String, data: Data, mimeType: String) async {
        guard let client else { return }
        do {
            let uri = try await client.uploadFile(filename: filename, data: data, mimeType: mimeType)
            let url = MediaURL.resolve(uri, site: site)?.absoluteString ?? uri
            if let index = tabs.firstIndex(where: { $0.id == activeTabID }) {
                let current = tabs[index].draft
                tabs[index].draft = current.isEmpty ? url : current + "\n" + url
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Channel / topic management

    public func markChannelRead(streamID: Int) async {
        guard let client else { return }
        do {
            try await client.markChannelRead(streamID: streamID)
            unread.stream[streamID] = [:]
            refreshBadge()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clientUpdateSubscription(streamID: Int, isMuted: Bool? = nil, pinToTop: Bool? = nil, color: String? = nil) async throws {
        try await client?.updateSubscription(streamID: streamID, isMuted: isMuted, pinToTop: pinToTop, color: color)
        if let index = channels.firstIndex(where: { $0.streamID == streamID }) {
            if let isMuted { channels[index].isMuted = isMuted }
            if let pinToTop { channels[index].pinToTop = pinToTop }
            if let color { channels[index].color = color }
        }
        persistState()
    }

    public func toggleResolveTopic(streamID: Int, topic: String) async {
        guard let client, let maxID = topicsByStream[streamID]?.first(where: { $0.name == topic })?.maxID else { return }
        let isResolved = topic.hasPrefix("✔") || topic.hasPrefix("✅")
        let newName = isResolved
            ? String(topic.drop(while: { $0 == "✔" || $0 == "✅" })).trimmingCharacters(in: .whitespaces)
            : "✔ \(topic)"
        do {
            try await client.editMessage(messageID: maxID, topic: newName, propagateMode: "change_later")
            var topics = topicsByStream[streamID] ?? []
            if let idx = topics.firstIndex(where: { $0.name == topic }) {
                topics[idx].name = newName
            }
            topicsByStream[streamID] = topics
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleMuteTopic(streamID: Int, topic: String) async {
        guard let client else { return }
        let isMuted = mutedTopics.contains("\(streamID):\(topic)")
        do {
            try await client.updateTopicVisibility(streamID: streamID, topic: topic, policy: isMuted ? 1 : 2)
            if isMuted {
                mutedTopics.remove("\(streamID):\(topic)")
            } else {
                mutedTopics.insert("\(streamID):\(topic)")
            }
            var topics = topicsByStream[streamID] ?? []
            if let idx = topics.firstIndex(where: { $0.name == topic }) {
                topics[idx].isMuted = !isMuted
            }
            topicsByStream[streamID] = topics
            persistState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTopics(_ streamID: Int) {
        guard let client else { return }
        topicsTask?.cancel()
        topicsTask = Task { [weak self] in
            guard let self else { return }
            do {
                let topics = try await client.topics(streamID: streamID)
                self.applyTopics(topics, streamID: streamID)
            } catch {}
        }
    }

    // MARK: - Thread loading

    func markRead(_ tab: ConversationTab) {
        guard let client else { return }
        let unreadIDs = (threads[tab.id]?.messages ?? []).filter { $0.isUnread }.map(\.id)
        if !unreadIDs.isEmpty {
            unread.applyFlags(ids: unreadIDs, flag: "read", op: "add")
            if var thread = threads[tab.id] {
                for index in thread.messages.indices {
                    thread.messages[index].flags.insert("read")
                }
                threads[tab.id] = thread
            }
            refreshBadge()
            Task { try? await client.markRead(ids: unreadIDs) }
        }
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index].unreadSinceOpen = 0
        }
    }

    private func loadTabMessages(for tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }), let client else { return }
        if threads[tabID]?.isLoading == true { return }
        loadTasks[tabID]?.cancel()
        var thread = threads[tabID] ?? MessageThread()
        thread.isLoading = true
        threads[tabID] = thread
        loadTasks[tabID] = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await client.messages(narrow: tab.narrow.terms, anchor: "newest", before: 50, after: 0)
                self.applyMessagePage(page, to: tabID)
            } catch {
                self.threads[tabID]?.isLoading = false
            }
        }
    }

    private func applyMessagePage(_ page: MessagePage, to tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        var thread = threads[tabID] ?? MessageThread()
        thread.messages = page.messages
        thread.foundOldest = page.foundOldest
        thread.foundNewest = page.foundNewest
        thread.isLoading = false
        threads[tabID] = thread
        LocalCache.saveThreadMessages(key: cacheKey(for: tab.narrow), messages: page.messages)
        markRead(tab)
    }

    public func loadOlder(for tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }), let client else { return }
        guard let thread = threads[tabID], !thread.isLoading, !thread.foundOldest,
              let firstID = thread.messages.first?.id else { return }
        threads[tabID]?.isLoading = true
        loadTasks[tabID]?.cancel()
        loadTasks[tabID] = Task { [weak self] in
            guard let self else { return }
            do {
                let page = try await client.messages(narrow: tab.narrow.terms, anchor: String(firstID), before: 50, after: 0)
                self.appendOlder(page, to: tabID)
            } catch {
                self.threads[tabID]?.isLoading = false
            }
        }
    }

    private func appendOlder(_ page: MessagePage, to tabID: UUID) {
        guard var thread = threads[tabID] else { return }
        let existing = Set(thread.messages.map(\.id))
        let older = page.messages.filter { !existing.contains($0.id) }
        thread.messages = older + thread.messages
        thread.foundOldest = page.foundOldest
        thread.isLoading = false
        threads[tabID] = thread
        if let tab = tabs.first(where: { $0.id == tabID }) {
            LocalCache.saveThreadMessages(key: cacheKey(for: tab.narrow), messages: thread.messages)
        }
    }

    private func cacheKey(for narrow: Narrow) -> String {
        switch narrow {
        case .topic(let streamID, _, let topic): return "t:\(streamID):\(topic)"
        case .dm(let ids): return "d:" + ids.sorted().map(String.init).joined(separator: ",")
        case .allMessages: return "feed:all"
        case .recentTopics: return "feed:recent"
        case .mentions: return "feed:mentions"
        case .starred: return "feed:starred"
        case .search(let query, _, _): return "search:\(query)"
        }
    }

    // MARK: - Keyboard shortcuts (tabs & sidebar)

    public func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activate(tabs[index].id)
    }

    public func selectSidebarItem(at index: Int) {
        switch index {
        case 0: selectRecentTopics()
        case 1: selectAllMessages()
        case 2: selectMentions()
        case 3: selectStarred()
        case 4: selectDMs()
        default:
            let channelIndex = index - 5
            let channels = visibleChannels
            guard channels.indices.contains(channelIndex) else { return }
            selectChannel(channels[channelIndex].streamID)
        }
        showCenterPane = true
        focusTopicListTrigger += 1
    }

    public func sidebarItemTitle(at index: Int) -> String {
        switch index {
        case 0: return "Recent"
        case 1: return "All Messages"
        case 2: return "Mentions"
        case 3: return "Starred"
        case 4: return "Direct Messages"
        default:
            let channelIndex = index - 5
            let channels = visibleChannels
            return channels.indices.contains(channelIndex) ? channels[channelIndex].name : ""
        }
    }

    // MARK: - Read receipts

    public func loadReadReceipts(for messageID: Int) {
        guard let client else { return }
        guard !readReceipts.keys.contains(messageID) else { return }
        Task { [weak self] in
            guard let self else { return }
            if let ids = try? await client.getReadReceipts(messageID: messageID) {
                self.readReceipts[messageID] = ids
            }
        }
    }

    // MARK: - Pane visibility (⌘B / ⌘⇧B)

    public func toggleLeftPane() {
        showLeftPane.toggle()
    }

    public func toggleCenterPane() {
        showCenterPane.toggle()
    }
}
