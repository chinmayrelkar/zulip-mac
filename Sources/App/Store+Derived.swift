import ZulipCore

extension Store {

    public var activeTab: ConversationTab? {
        tabs.first { $0.id == activeTabID }
    }

    public func channelLastActivity(_ streamID: Int) -> Int {
        var highest = channelActivity[streamID] ?? 0
        if let topics = topicsByStream[streamID], let maxTopicID = topics.map(\.maxID).max() {
            highest = max(highest, maxTopicID)
        }
        if let streamUnreads = unread.stream[streamID] {
            for (_, ids) in streamUnreads {
                if let maxUnread = ids.max() {
                    highest = max(highest, maxUnread)
                }
            }
        }
        return highest
    }

    public var visibleChannels: [Channel] {
        let filtered = channelQuery.isEmpty
            ? channels
            : channels.filter { $0.name.localizedCaseInsensitiveContains(channelQuery) }
        return filtered.sorted { lhs, rhs in
            if lhs.pinToTop != rhs.pinToTop { return lhs.pinToTop }
            if lhs.isMuted != rhs.isMuted { return !lhs.isMuted }
            // Recency: most recently active channels first.
            let lhsAct = channelLastActivity(lhs.streamID)
            let rhsAct = channelLastActivity(rhs.streamID)
            if lhsAct != rhsAct {
                return lhsAct > rhsAct
            }
            // Relevance: then channels with unread messages.
            let lhsUnread = unread.channelCount(lhs.streamID)
            let rhsUnread = unread.channelCount(rhs.streamID)
            if lhsUnread != rhsUnread {
                return lhsUnread > rhsUnread
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public var pinnedChannels: [Channel] {
        visibleChannels.filter { $0.pinToTop }
    }

    public var unmutedChannels: [Channel] {
        visibleChannels.filter { !$0.pinToTop && !$0.isMuted }
    }

    public var mutedChannels: [Channel] {
        visibleChannels.filter { !$0.pinToTop && $0.isMuted }
    }

    public struct ChannelFolderGroup: Identifiable {
        public var id: String { name }
        public var name: String
        public var isFolder: Bool
        public var channels: [Channel]
        public var totalUnread: Int

        public init(name: String, isFolder: Bool, channels: [Channel], totalUnread: Int) {
            self.name = name
            self.isFolder = isFolder
            self.channels = channels
            self.totalUnread = totalUnread
        }
    }

    public var unmutedChannelGroups: [ChannelFolderGroup] {
        buildChannelGroups(from: unmutedChannels)
    }

    public var mutedChannelGroups: [ChannelFolderGroup] {
        buildChannelGroups(from: mutedChannels)
    }

    private func buildChannelGroups(from channelList: [Channel]) -> [ChannelFolderGroup] {
        var folderMap: [String: [Channel]] = [:]
        var directChannels: [Channel] = []

        for ch in channelList {
            if ch.name.contains("/") {
                let parts = ch.name.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let folder = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    folderMap[folder, default: []].append(ch)
                } else {
                    directChannels.append(ch)
                }
            } else {
                directChannels.append(ch)
            }
        }

        var result: [ChannelFolderGroup] = []

        // Add folders sorted by most recent activity (recency-first), so active
        // folders float to the top instead of hiding under alphabetical order.
        for (folder, chs) in folderMap.sorted(by: { lhs, rhs in
            let lhsActivity = lhs.value.map { channelLastActivity($0.streamID) }.max() ?? 0
            let rhsActivity = rhs.value.map { channelLastActivity($0.streamID) }.max() ?? 0
            if lhsActivity != rhsActivity {
                return lhsActivity > rhsActivity
            }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }) {
            let totalUnread = chs.reduce(0) { $0 + unread.channelCount($1.streamID) }
            result.append(ChannelFolderGroup(
                name: folder,
                isFolder: true,
                channels: chs.sorted { lhs, rhs in
                    let lAct = channelLastActivity(lhs.streamID)
                    let rAct = channelLastActivity(rhs.streamID)
                    if lAct != rAct { return lAct > rAct }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                },
                totalUnread: totalUnread
            ))
        }

        // Add standalone channels group if any
        if !directChannels.isEmpty {
            let totalUnread = directChannels.reduce(0) { $0 + unread.channelCount($1.streamID) }
            result.append(ChannelFolderGroup(
                name: "CHANNELS",
                isFolder: false,
                channels: directChannels.sorted { lhs, rhs in
                    let lAct = channelLastActivity(lhs.streamID)
                    let rAct = channelLastActivity(rhs.streamID)
                    if lAct != rAct { return lAct > rAct }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                },
                totalUnread: totalUnread
            ))
        }

        return result
    }

    public var totalResolvedCountInSelectedChannel: Int {
        guard case .channel(let id) = selectedSource else { return 0 }
        let topics = topicsByStream[id] ?? []
        return topics.filter(\.isResolved).count
    }

    public var visibleTopics: [Topic] {
        guard case .channel(let id) = selectedSource else { return [] }
        let topics = topicsByStream[id] ?? []
        var filtered = topics
        if !topicQuery.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(topicQuery) }
        } else if !showResolvedInChannel {
            filtered = filtered.filter { !$0.isResolved }
        }
        return filtered.sorted { lhs, rhs in
            let lhsActivity = max(lhs.maxID, unread.stream[id]?[lhs.name]?.max() ?? 0)
            let rhsActivity = max(rhs.maxID, unread.stream[id]?[rhs.name]?.max() ?? 0)
            if lhsActivity != rhsActivity {
                return channelTopicsSortOrder == .newestLast ? lhsActivity < rhsActivity : lhsActivity > rhsActivity
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    public var visibleDMs: [RecentDM] {
        let list: [RecentDM]
        if topicQuery.isEmpty {
            list = dms
        } else {
            list = dms.filter { dm in
                dmTitle(dm).localizedCaseInsensitiveContains(topicQuery)
            }
        }
        return list.sorted { $0.maxMessageID > $1.maxMessageID }
    }

    public var recentConversations: [RecentTopicItem] {
        var items: [RecentTopicItem] = []
        let mutedSet = mutedTopics
        let showMuted = showMutedInRecent
        let showUnreadOnly = showUnreadOnlyInRecent
        let query = topicQuery
        let streamUnreads = unread.stream
        let isNewestLast = recentSortOrder == .newestLast

        for channel in channels {
            if !showMuted && channel.isMuted { continue }
            guard let topics = topicsByStream[channel.streamID], !topics.isEmpty else { continue }
            let channelUnreads = streamUnreads[channel.streamID]

            for topic in topics {
                let isMuted = mutedSet.contains("\(channel.streamID):\(topic.name)") || channel.isMuted
                if !showMuted && isMuted { continue }
                let topicUnreads = channelUnreads?[topic.name]
                let unreadCount = topicUnreads?.count ?? 0
                if showUnreadOnly && unreadCount == 0 { continue }
                let activityID = max(topic.maxID, topicUnreads?.max() ?? 0)

                items.append(RecentTopicItem(
                    streamID: channel.streamID,
                    streamName: channel.name,
                    streamColor: channel.color,
                    topic: topic.name,
                    isResolved: topic.isResolved,
                    isMuted: isMuted,
                    unreadCount: unreadCount,
                    maxMessageID: activityID,
                    participantUserIDs: []
                ))
            }
        }
        if !query.isEmpty {
            items = items.filter {
                $0.streamName.localizedCaseInsensitiveContains(query)
                    || $0.topic.localizedCaseInsensitiveContains(query)
            }
        }
        return items.sorted { lhs, rhs in
            if lhs.isResolved != rhs.isResolved {
                return !lhs.isResolved
            }
            if isNewestLast {
                return lhs.maxMessageID < rhs.maxMessageID
            } else {
                return lhs.maxMessageID > rhs.maxMessageID
            }
        }
    }

    public var mentionConversations: [RecentTopicItem] {
        var items: [RecentTopicItem] = []
        var seen = Set<String>()
        let mutedSet = mutedTopics
        let streamUnreads = unread.stream
        let query = topicQuery
        let isNewestLast = mentionsSortOrder == .newestLast

        let sortedMentions = mentionsMessages.sorted { $0.id < $1.id }
        for msg in sortedMentions {
            if let streamID = msg.streamID {
                let topic = msg.topic
                let key = "\(streamID):\(topic)"
                if seen.insert(key).inserted {
                    let ch = channel(id: streamID)
                    let streamName = msg.streamName ?? ch?.name ?? "Channel"
                    let streamColor = ch?.color ?? "888888"
                    let isMuted = mutedSet.contains(key) || ch?.isMuted == true
                    let unreadCount = streamUnreads[streamID]?[topic]?.count ?? 0
                    let isResolved = topic.hasPrefix("✔ ") || topic.hasPrefix("[RESOLVED]")
                    items.append(RecentTopicItem(
                        streamID: streamID,
                        streamName: streamName,
                        streamColor: streamColor,
                        topic: topic,
                        isResolved: isResolved,
                        isMuted: isMuted,
                        unreadCount: unreadCount,
                        maxMessageID: msg.id,
                        participantUserIDs: [msg.senderID]
                    ))
                }
            }
        }

        if mentionsUnreadOnly {
            items = items.filter { $0.unreadCount > 0 }
        }

        if !query.isEmpty {
            items = items.filter {
                $0.streamName.localizedCaseInsensitiveContains(query)
                    || $0.topic.localizedCaseInsensitiveContains(query)
            }
        }

        if isNewestLast {
            return items.sorted { $0.maxMessageID < $1.maxMessageID }
        } else {
            return items.sorted { $0.maxMessageID > $1.maxMessageID }
        }
    }
}
