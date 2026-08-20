import AppKit
import UserNotifications
import ZulipCore

extension Store {
    func applyEvents(_ events: [ZulipEvent], lastID: Int) {
        lastEventID = lastID
        for event in events { apply(event) }
    }

    func reconnect() async {
        if let credentials = Auth.load() {
            await connect(credentials)
        }
    }

    func setStatus(_ text: String) {
        status = text
    }

    func apply(_ snap: RegisterSnapshot) {
        queueID = snap.queueID
        lastEventID = snap.lastEventID
        selfUserID = snap.selfUserID
        selfEmail = snap.selfEmail
        realmName = snap.realmName
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        realmEmojis = snap.realmEmoji
        channels = snap.channels
        users = Dictionary(uniqueKeysWithValues: snap.users.map { ($0.userID, $0) })
        unread = snap.unread
        mutedTopics = Set(snap.mutedTopics.map { "\($0.streamID):\($0.topic)" })
        dms = []
        for dm in snap.recentDMs {
            upsertDM(userIDs: dm.userIDs, maxID: dm.maxMessageID)
        }
        mergeUnreadDMs()
        refreshBadge()
        persistState()
        startDMHistory()
        loadAllChannelTopics()
        if selectedSource == nil {
            selectRecentTopics()
        }
    }

    // Single dispatcher over ZulipEvent: the switch shape is inherent to the event
    // model, so each case is a one-line call and the real logic lives in small handlers.
    // swiftlint:disable:next cyclomatic_complexity
    func apply(_ event: ZulipEvent) {
        switch event {
        case .message(let message):
            applyMessageEvent(message)
        case .updateMessage(let id, let html, let topic, let streamID):
            applyUpdateMessageEvent(id: id, html: html, topic: topic, streamID: streamID)
        case .deleteMessage(let ids):
            applyDeleteEvent(ids)
        case .flags(let ids, let flag, let op):
            applyFlagsEvent(ids: ids, flag: flag, op: op)
        case .reaction(let messageID, let emojiName, let emojiCode, let reactionType, let userID, let op):
            applyReactionEvent(messageID: messageID, emojiName: emojiName, emojiCode: emojiCode, reactionType: reactionType, userID: userID, op: op)
        case .typing(let senderID, let op, let streamID, let topic, let userIDs):
            applyTypingEvent(senderID: senderID, op: op, streamID: streamID, topic: topic, userIDs: userIDs)
        case .presence(let userID, let presence):
            presences[userID] = presence
        case .userStatus(let userID, let status):
            userStatuses[userID] = status
        case .subscription(let op, let subs):
            applySubscriptionEvent(op: op, subs: subs)
        case .realmUser(let op, let person):
            if op == "add" || op == "update" {
                users[person.userID] = person
            }
        case .realmEmoji(let emojis):
            realmEmojis = emojis
        case .mutedTopics(let topics):
            mutedTopics = Set(topics.map { "\($0.streamID):\($0.topic)" })
        case .heartbeat, .other, .restart:
            break
        }
    }

    private func applyMessageEvent(_ message: Message) {
        unread.add(message: message, selfID: selfUserID)
        for index in tabs.indices {
            let tab = tabs[index]
            if tab.narrow.matches(message) {
                if var thread = threads[tab.id], !thread.messages.contains(where: { $0.id == message.id }) {
                    thread.messages.append(message)
                    threads[tab.id] = thread
                }
                if tab.id == activeTabID {
                    markRead(tab)
                } else {
                    tabs[index].unreadSinceOpen += 1
                }
            }
        }
        if message.type == "private" {
            upsertDM(userIDs: message.dmUserIDs, maxID: message.id)
        } else if let streamID = message.streamID {
            upsertTopic(streamID: streamID, name: message.topic, maxID: message.id)
        }
        if message.isMention {
            mergeMentions([message])
        }
        if message.senderID != selfUserID {
            notify(message)
        }
        refreshBadge()
    }

    private func applyUpdateMessageEvent(id: Int, html: String?, topic: String?, streamID: Int?) {
        for key in threads.keys {
            guard var thread = threads[key], let index = thread.messages.firstIndex(where: { $0.id == id }) else { continue }
            if let html { thread.messages[index].content = html }
            if let topic { thread.messages[index].topic = topic }
            if let streamID { thread.messages[index].streamID = streamID }
            threads[key] = thread
        }
        if let streamID, let topic {
            upsertTopic(streamID: streamID, name: topic, maxID: id)
        }
    }

    private func applyDeleteEvent(_ ids: [Int]) {
        let gone = Set(ids)
        for key in threads.keys {
            threads[key]?.messages.removeAll { gone.contains($0.id) }
        }
    }

    private func applyFlagsEvent(ids: [Int], flag: String, op: String) {
        unread.applyFlags(ids: ids, flag: flag, op: op)
        let set = Set(ids)
        for key in threads.keys {
            guard var thread = threads[key] else { continue }
            for index in thread.messages.indices where set.contains(thread.messages[index].id) {
                if op == "add" { thread.messages[index].flags.insert(flag) }
                else { thread.messages[index].flags.remove(flag) }
            }
            threads[key] = thread
        }
        refreshBadge()
    }

    private func applyReactionEvent(messageID: Int, emojiName: String, emojiCode: String, reactionType: String, userID: Int, op: String) {
        for key in threads.keys {
            guard var thread = threads[key], let index = thread.messages.firstIndex(where: { $0.id == messageID }) else { continue }
            if op == "add" {
                if !thread.messages[index].reactions.contains(where: { $0.userID == userID && $0.emojiName == emojiName }) {
                    thread.messages[index].reactions.append(Reaction(
                        emojiName: emojiName,
                        userID: userID,
                        emojiCode: emojiCode,
                        reactionType: reactionType
                    ))
                }
            } else {
                thread.messages[index].reactions.removeAll {
                    $0.userID == userID && ($0.emojiName == emojiName || $0.emojiCode == emojiCode)
                }
            }
            threads[key] = thread
        }
    }

    private func applyTypingEvent(senderID: Int, op: String, streamID: Int?, topic: String?, userIDs: [Int]?) {
        let key = typingKey(streamID: streamID, topic: topic, userIDs: userIDs)
        if op == "start" {
            typingUsers[key, default: []].insert(senderID)
        } else {
            typingUsers[key, default: []].remove(senderID)
        }
    }

    private func applySubscriptionEvent(op: String, subs: [Channel]) {
        if op == "add" {
            for sub in subs where !channels.contains(where: { $0.streamID == sub.streamID }) {
                channels.append(sub)
            }
        } else if op == "remove" {
            let ids = Set(subs.map(\.streamID))
            channels.removeAll { ids.contains($0.streamID) }
        }
    }

    func typingKey(streamID: Int?, topic: String?, userIDs: [Int]?) -> String {
        if let streamID, let topic {
            return "s-\(streamID):\(topic)"
        }
        if let userIDs {
            return "dm:" + userIDs.sorted().map(String.init).joined(separator: ",")
        }
        return ""
    }

    func reportTyping() {
        guard let tab = activeTab, let client else { return }
        let now = Date()
        if let last = lastTypingReport, now.timeIntervalSince(last) < 4 { return }
        lastTypingReport = now
        Task.detached {
            switch tab.narrow {
            case .topic(let streamID, _, let topic):
                try? await client.sendTyping(op: "start", streamID: streamID, topic: topic)
            case .dm(let userIDs):
                try? await client.sendTyping(op: "start", to: userIDs)
            default:
                break
            }
        }
    }

    func loadAllChannelTopics() {
        guard let client else { return }
        let channelIDs = channels.map(\.streamID)
        Task.detached { [weak self] in
            var allResults: [Int: [Topic]] = [:]
            await withTaskGroup(of: (Int, [Topic]?).self) { group in
                for id in channelIDs {
                    group.addTask {
                        let topics = try? await client.topics(streamID: id)
                        return (id, topics)
                    }
                }
                for await (id, topics) in group {
                    if let topics {
                        allResults[id] = topics
                    }
                }
            }
            guard !Task.isCancelled else { return }
            await self?.applyAllTopics(allResults)
        }
    }

    func applyAllTopics(_ allTopics: [Int: [Topic]]) {
        for (streamID, topics) in allTopics {
            topicsByStream[streamID] = topics
            if let maxID = topics.map(\.maxID).max() {
                channelActivity[streamID] = max(channelActivity[streamID] ?? 0, maxID)
            }
        }
        persistState()
    }

    func upsertTopic(streamID: Int, name: String, maxID: Int) {
        var topics = topicsByStream[streamID] ?? []
        if let index = topics.firstIndex(where: { $0.name == name }) {
            if maxID > topics[index].maxID {
                topics[index].maxID = maxID
            }
        } else {
            topics.append(Topic(name: name, maxID: maxID))
        }
        topicsByStream[streamID] = topics
        channelActivity[streamID] = max(channelActivity[streamID] ?? 0, maxID)
        persistState()
    }

    func startDMHistory() {
        guard let client else { return }
        Task.detached { [weak self] in
            do {
                let page = try await client.messages(
                    narrow: [NarrowTerm(op: "is", operand: .string("dm"))],
                    anchor: "newest",
                    before: 400,
                    after: 0
                )
                await self?.applyDMHistory(page.messages)
            } catch {
                await self?.setStatus(error.localizedDescription)
            }
        }
    }

    func applyTopics(_ topics: [Topic], streamID: Int) {
        topicsByStream[streamID] = topics
        if let maxID = topics.map(\.maxID).max() {
            channelActivity[streamID] = max(channelActivity[streamID] ?? 0, maxID)
        }
        persistState()
    }

    func applyDMHistory(_ messages: [Message]) {
        for message in messages {
            upsertDM(userIDs: message.dmUserIDs, maxID: message.id)
        }
    }

    func mergeUnreadDMs() {
        for (sender, ids) in unread.pms {
            upsertDM(userIDs: [sender], maxID: ids.max() ?? 0)
        }
        for (key, ids) in unread.huddles {
            let people = key.split(separator: ",").compactMap { Int($0) }
            upsertDM(userIDs: people, maxID: ids.max() ?? 0)
        }
    }

    func upsertDM(userIDs: [Int], maxID: Int) {
        let ids = normalizedDM(userIDs)
        if let index = dms.firstIndex(where: { $0.userIDs == ids }) {
            if maxID > dms[index].maxMessageID {
                dms[index].maxMessageID = maxID
            }
        } else {
            dms.append(RecentDM(userIDs: ids, maxMessageID: maxID))
        }
    }

    func normalizedDM(_ ids: [Int]) -> [Int] {
        let others = Set(ids).subtracting([selfUserID]).sorted()
        return others.isEmpty ? [selfUserID] : others
    }

    func syncSelection(to narrow: Narrow) {
        switch narrow {
        case .topic(let streamID, _, let topic):
            if selectedSource != .recentTopics && selectedSource != .mentions {
                selectedSource = .channel(streamID)
            }
            selectedTopic = topic
            selectedDMKey = nil
            if topicsByStream[streamID] == nil {
                loadTopics(streamID)
            }
        case .dm(let userIDs):
            if selectedSource != .recentTopics && selectedSource != .mentions {
                selectedSource = .directMessages
            }
            selectedTopic = nil
            selectedDMKey = dmKey(RecentDM(userIDs: userIDs, maxMessageID: 0))
        case .recentTopics:
            selectedSource = .recentTopics
        case .allMessages:
            selectedSource = .allMessages
        case .mentions:
            selectedSource = .mentions
        case .starred:
            selectedSource = .starred
        case .search:
            break
        }
    }

    func notify(_ message: Message) {
        let interesting = message.isMention || message.type == "private"
        guard interesting else { return }
        let content = UNMutableNotificationContent()
        content.title = message.senderName
        content.subtitle = message.type == "private" ? "DM" : "\(message.streamName ?? "") › \(message.topic)"
        content.body = message.content.strippingHTML
        content.sound = .default
        let req = UNNotificationRequest(identifier: String(message.id), content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func refreshBadge() {
        let total = unread.mentionCount + unread.dmTotal
        NSApp.dockTile.badgeLabel = total > 0 ? String(total) : nil
    }

    func dmKey(_ dm: RecentDM) -> String {
        dm.userIDs.filter { $0 != selfUserID }.sorted().map(String.init).joined(separator: ",")
    }

    var commandHeld: Bool {
        NSEvent.modifierFlags.contains(.command)
    }

    var searchContext: SearchContext {
        SearchContext(selfEmail: selfEmail, selfUserID: selfUserID, users: Array(users.values))
    }
}

private extension String {
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
