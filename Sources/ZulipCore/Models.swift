import Foundation

public struct Channel: Identifiable, Hashable, Sendable, Codable {
    public var streamID: Int
    public var name: String
    public var description: String
    public var color: String
    public var pinToTop: Bool
    public var isMuted: Bool
    public var inviteOnly: Bool
    public var isWebPublic: Bool
    public var dateCreated: Date?

    public var id: Int { streamID }

    public init(
        streamID: Int,
        name: String,
        description: String = "",
        color: String = "888888",
        pinToTop: Bool = false,
        isMuted: Bool = false,
        inviteOnly: Bool = false,
        isWebPublic: Bool = false,
        dateCreated: Date? = nil
    ) {
        self.streamID = streamID
        self.name = name
        self.description = description
        self.color = color
        self.pinToTop = pinToTop
        self.isMuted = isMuted
        self.inviteOnly = inviteOnly
        self.isWebPublic = isWebPublic
        self.dateCreated = dateCreated
    }

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case name
        case description
        case color
        case pinToTop = "pin_to_top"
        case isMuted = "is_muted"
        case inviteOnly = "invite_only"
        case isWebPublic = "is_web_public"
        case dateCreated = "date_created"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streamID = try c.decode(Int.self, forKey: .streamID)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "888888"
        pinToTop = try c.decodeIfPresent(Bool.self, forKey: .pinToTop) ?? false
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        inviteOnly = try c.decodeIfPresent(Bool.self, forKey: .inviteOnly) ?? false
        isWebPublic = try c.decodeIfPresent(Bool.self, forKey: .isWebPublic) ?? false
        if let created = try c.decodeIfPresent(Double.self, forKey: .dateCreated) {
            dateCreated = Date(timeIntervalSince1970: created)
        } else {
            dateCreated = nil
        }
    }
}

public struct User: Identifiable, Hashable, Sendable, Codable {
    public var userID: Int
    public var fullName: String
    public var email: String
    public var isActive: Bool
    public var isBot: Bool
    public var isAdmin: Bool
    public var isOwner: Bool
    public var avatarURL: String?
    public var timezone: String?

    public var id: Int { userID }

    public init(
        userID: Int,
        fullName: String,
        email: String,
        isActive: Bool = true,
        isBot: Bool = false,
        isAdmin: Bool = false,
        isOwner: Bool = false,
        avatarURL: String? = nil,
        timezone: String? = nil
    ) {
        self.userID = userID
        self.fullName = fullName
        self.email = email
        self.isActive = isActive
        self.isBot = isBot
        self.isAdmin = isAdmin
        self.isOwner = isOwner
        self.avatarURL = avatarURL
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case fullName = "full_name"
        case email
        case isActive = "is_active"
        case isBot = "is_bot"
        case isAdmin = "is_admin"
        case isOwner = "is_owner"
        case avatarURL = "avatar_url"
        case timezone
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(Int.self, forKey: .userID)
        fullName = try c.decode(String.self, forKey: .fullName)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isBot = try c.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
    }
}

public struct Topic: Identifiable, Hashable, Sendable, Codable {
    public var name: String
    public var maxID: Int
    public var isMuted: Bool
    public var isFollowed: Bool

    public var id: String { name }
    public var isResolved: Bool { name.hasPrefix("✔") || name.hasPrefix("✅") }
    public var displayName: String {
        if isResolved {
            var raw = name
            if raw.hasPrefix("✔ ") { raw.removeFirst(2) }
            else if raw.hasPrefix("✔") { raw.removeFirst(1) }
            else if raw.hasPrefix("✅ ") { raw.removeFirst(2) }
            else if raw.hasPrefix("✅") { raw.removeFirst(1) }
            return raw
        }
        return name
    }

    public init(name: String, maxID: Int, isMuted: Bool = false, isFollowed: Bool = false) {
        self.name = name
        self.maxID = maxID
        self.isMuted = isMuted
        self.isFollowed = isFollowed
    }

    enum CodingKeys: String, CodingKey {
        case name
        case maxID = "max_id"
        case isMuted = "is_muted"
        case isFollowed = "is_followed"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        maxID = try c.decode(Int.self, forKey: .maxID)
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        isFollowed = try c.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false
    }
}

public struct RecentDM: Hashable, Sendable, Codable {
    public var userIDs: [Int]
    public var maxMessageID: Int

    public init(userIDs: [Int], maxMessageID: Int) {
        self.userIDs = userIDs
        self.maxMessageID = maxMessageID
    }

    enum CodingKeys: String, CodingKey {
        case userIDs = "user_ids"
        case maxMessageID = "max_message_id"
    }
}

public struct Reaction: Hashable, Sendable, Codable {
    public var emojiName: String
    public var userID: Int
    public var emojiCode: String
    public var reactionType: String

    public init(emojiName: String, userID: Int, emojiCode: String = "", reactionType: String = "unicode_emoji") {
        self.emojiName = emojiName
        self.userID = userID
        self.emojiCode = emojiCode.isEmpty ? emojiName : emojiCode
        self.reactionType = reactionType
    }

    enum CodingKeys: String, CodingKey {
        case emojiName = "emoji_name"
        case userID = "user_id"
        case emojiCode = "emoji_code"
        case reactionType = "reaction_type"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emojiName = try c.decodeIfPresent(String.self, forKey: .emojiName) ?? ""
        userID = try c.decodeIfPresent(Int.self, forKey: .userID) ?? 0
        emojiCode = try c.decodeIfPresent(String.self, forKey: .emojiCode) ?? ""
        reactionType = try c.decodeIfPresent(String.self, forKey: .reactionType) ?? "unicode_emoji"
    }
}

public struct RealmEmoji: Identifiable, Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var sourceURL: String
    public var stillURL: String?
    public var deactivated: Bool
    public var authorID: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case sourceURL = "source_url"
        case stillURL = "still_url"
        case deactivated
        case authorID = "author_id"
    }
}

public enum PresenceStatus: String, Sendable, Codable {
    case active
    case idle
    case offline
}

public struct UserPresence: Sendable, Hashable {
    public var status: PresenceStatus
    public var timestamp: Date
    public var client: String?

    public init(status: PresenceStatus, timestamp: Date = Date(), client: String? = nil) {
        self.status = status
        self.timestamp = timestamp
        self.client = client
    }
}

public struct UserStatus: Sendable, Hashable, Codable {
    public var statusText: String?
    public var emojiName: String?
    public var emojiCode: String?
    public var reactionType: String?
    public var away: Bool?

    public init(statusText: String? = nil, emojiName: String? = nil, emojiCode: String? = nil, reactionType: String? = nil, away: Bool? = nil) {
        self.statusText = statusText
        self.emojiName = emojiName
        self.emojiCode = emojiCode
        self.reactionType = reactionType
        self.away = away
    }

    enum CodingKeys: String, CodingKey {
        case statusText = "status_text"
        case emojiName = "emoji_name"
        case emojiCode = "emoji_code"
        case reactionType = "reaction_type"
        case away
    }
}

public struct Message: Identifiable, Hashable, Sendable {
    public var id: Int
    public var senderID: Int
    public var senderName: String
    public var senderEmail: String
    public var avatarURL: String?
    public var content: String
    public var matchContent: String?
    public var timestamp: Date
    public var type: String
    public var streamID: Int?
    public var streamName: String?
    public var topic: String
    public var flags: Set<String>
    public var reactions: [Reaction]
    public var dmUserIDs: [Int]
    public var lastEdit: Date?

    public var isUnread: Bool { !flags.contains("read") }
    public var isStarred: Bool { flags.contains("starred") }
    public var isMention: Bool {
        flags.contains("mentioned")
            || flags.contains("stream_wildcard_mentioned")
            || flags.contains("topic_wildcard_mentioned")
            || flags.contains("wildcard_mentioned")
    }
    public var displayHTML: String { matchContent ?? content }

    public init(
        id: Int,
        senderID: Int,
        senderName: String,
        senderEmail: String,
        avatarURL: String? = nil,
        content: String,
        matchContent: String? = nil,
        timestamp: Date = Date(),
        type: String = "stream",
        streamID: Int? = nil,
        streamName: String? = nil,
        topic: String = "",
        flags: Set<String> = [],
        reactions: [Reaction] = [],
        dmUserIDs: [Int] = [],
        lastEdit: Date? = nil
    ) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.avatarURL = avatarURL
        self.content = content
        self.matchContent = matchContent
        self.timestamp = timestamp
        self.type = type
        self.streamID = streamID
        self.streamName = streamName
        self.topic = topic
        self.flags = flags
        self.reactions = reactions
        self.dmUserIDs = dmUserIDs
        self.lastEdit = lastEdit
    }
}

extension Message: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case senderID = "sender_id"
        case senderName = "sender_full_name"
        case senderEmail = "sender_email"
        case avatarURL = "avatar_url"
        case content
        case matchContent = "match_content"
        case timestamp
        case type
        case streamID = "stream_id"
        case subject
        case flags
        case reactions
        case displayRecipient = "display_recipient"
        case lastEditTimestamp = "last_edit_timestamp"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        senderID = try c.decode(Int.self, forKey: .senderID)
        senderName = try c.decodeIfPresent(String.self, forKey: .senderName) ?? ""
        senderEmail = try c.decodeIfPresent(String.self, forKey: .senderEmail) ?? ""
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        matchContent = try c.decodeIfPresent(String.self, forKey: .matchContent)
        let rawTimestamp = try c.decodeIfPresent(Double.self, forKey: .timestamp) ?? 0
        timestamp = Date(timeIntervalSince1970: rawTimestamp)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "stream"
        streamID = try c.decodeIfPresent(Int.self, forKey: .streamID)
        topic = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        flags = Set(try c.decodeIfPresent([String].self, forKey: .flags) ?? [])
        reactions = try c.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        if let edit = try c.decodeIfPresent(Double.self, forKey: .lastEditTimestamp) {
            lastEdit = Date(timeIntervalSince1970: edit)
        } else {
            lastEdit = nil
        }

        if let name = try? c.decode(String.self, forKey: .displayRecipient) {
            streamName = name
            dmUserIDs = []
        } else if let people = try? c.decode([DMPerson].self, forKey: .displayRecipient) {
            streamName = nil
            dmUserIDs = people.map(\.id).sorted()
        } else {
            streamName = nil
            dmUserIDs = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(senderID, forKey: .senderID)
        try c.encode(senderName, forKey: .senderName)
        try c.encode(senderEmail, forKey: .senderEmail)
        try c.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(matchContent, forKey: .matchContent)
        try c.encode(timestamp.timeIntervalSince1970, forKey: .timestamp)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(streamID, forKey: .streamID)
        try c.encode(topic, forKey: .subject)
        try c.encode(Array(flags), forKey: .flags)
        try c.encode(reactions, forKey: .reactions)
        if let lastEdit {
            try c.encode(lastEdit.timeIntervalSince1970, forKey: .lastEditTimestamp)
        }
        if let streamName {
            try c.encode(streamName, forKey: .displayRecipient)
        } else if !dmUserIDs.isEmpty {
            let people = dmUserIDs.map { DMPerson(id: $0) }
            try c.encode(people, forKey: .displayRecipient)
        }
    }
}

extension Message: Encodable {}

private struct DMPerson: Codable {
    var id: Int
}

public struct MessageEditHistoryItem: Identifiable, Sendable, Decodable {
    public var id: Double { timestamp }
    public var timestamp: Double
    public var userID: Int?
    public var prevContent: String?
    public var prevRenderedContent: String?
    public var prevTopic: String?
    public var topic: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case userID = "user_id"
        case prevContent = "prev_content"
        case prevRenderedContent = "prev_rendered_content"
        case prevTopic = "prev_topic"
        case topic
    }
}

public struct UnreadState: Sendable, Equatable, Codable {
    public var stream: [Int: [String: Set<Int>]] = [:]
    public var pms: [Int: Set<Int>] = [:]
    public var huddles: [String: Set<Int>] = [:]
    public var mentions: Set<Int> = []

    public init() {}

    public func channelCount(_ streamID: Int) -> Int {
        stream[streamID]?.values.reduce(0) { $0 + $1.count } ?? 0
    }

    public func topicCount(_ streamID: Int, topic: String) -> Int {
        stream[streamID]?[topic]?.count ?? 0
    }

    public func dmCount(userIDs: [Int], selfID: Int) -> Int {
        let others = userIDs.filter { $0 != selfID }.sorted()
        if others.count <= 1 {
            return pms[others.first ?? selfID]?.count ?? 0
        }
        let key = (others + [selfID]).sorted().map(String.init).joined(separator: ",")
        return huddles[key]?.count ?? huddles[others.map(String.init).joined(separator: ",")]?.count ?? 0
    }

    public var dmTotal: Int {
        pms.values.reduce(0) { $0 + $1.count } + huddles.values.reduce(0) { $0 + $1.count }
    }

    public var totalUnread: Int {
        let streamTotal = stream.values.flatMap(\.values).reduce(0) { $0 + $1.count }
        return streamTotal + dmTotal
    }

    public var mentionCount: Int { mentions.count }

    public mutating func applyFlags(ids: [Int], flag: String, op: String) {
        guard flag == "read" else {
            if flag == "mentioned" || flag.hasSuffix("mentioned") {
                if op == "add" { mentions.formUnion(ids) }
                else { mentions.subtract(ids) }
            }
            return
        }
        let remove = op == "add"
        func prune(_ set: inout Set<Int>) {
            if remove { set.subtract(ids) } else { set.formUnion(ids) }
        }
        for streamID in stream.keys {
            for topic in stream[streamID, default: [:]].keys {
                prune(&stream[streamID, default: [:]][topic, default: []])
            }
        }
        for key in pms.keys { prune(&pms[key, default: []]) }
        for key in huddles.keys { prune(&huddles[key, default: []]) }
        if remove { mentions.subtract(ids) }
    }

    public mutating func add(message: Message, selfID: Int) {
        guard message.senderID != selfID, message.isUnread else { return }
        if message.isMention { mentions.insert(message.id) }
        if message.type == "private" {
            let others = message.dmUserIDs.filter { $0 != selfID }.sorted()
            if others.count <= 1 {
                pms[others.first ?? message.senderID, default: []].insert(message.id)
            } else {
                let key = (others + [selfID]).sorted().map(String.init).joined(separator: ",")
                huddles[key, default: []].insert(message.id)
            }
        } else if let streamID = message.streamID {
            stream[streamID, default: [:]][message.topic, default: []].insert(message.id)
        }
    }
}

public struct UnreadMsgsDTO: Decodable, Sendable {
    public var mentions: [Int]?
    public var pms: [UnreadPM]?
    public var huddles: [UnreadHuddle]?
    public var streams: [UnreadStream]?

    public struct UnreadPM: Decodable, Sendable {
        public var senderID: Int
        public var unreadMessageIds: [Int]
        enum CodingKeys: String, CodingKey {
            case senderID = "sender_id"
            case unreadMessageIds = "unread_message_ids"
        }
    }

    public struct UnreadHuddle: Decodable, Sendable {
        public var userIdsString: String
        public var unreadMessageIds: [Int]
        enum CodingKeys: String, CodingKey {
            case userIdsString = "user_ids_string"
            case unreadMessageIds = "unread_message_ids"
        }
    }

    public struct UnreadStream: Decodable, Sendable {
        public var streamID: Int
        public var topic: String
        public var unreadMessageIds: [Int]
        enum CodingKeys: String, CodingKey {
            case streamID = "stream_id"
            case topic
            case unreadMessageIds = "unread_message_ids"
        }
    }

    public func asState() -> UnreadState {
        var state = UnreadState()
        state.mentions = Set(mentions ?? [])
        for pm in pms ?? [] {
            state.pms[pm.senderID] = Set(pm.unreadMessageIds)
        }
        for huddle in huddles ?? [] {
            state.huddles[huddle.userIdsString] = Set(huddle.unreadMessageIds)
        }
        for stream in streams ?? [] {
            state.stream[stream.streamID, default: [:]][stream.topic] = Set(stream.unreadMessageIds)
        }
        return state
    }
}

public struct MessagePage: Sendable {
    public var messages: [Message]
    public var foundOldest: Bool
    public var foundNewest: Bool
    public var anchor: Int?

    public init(messages: [Message], foundOldest: Bool, foundNewest: Bool, anchor: Int? = nil) {
        self.messages = messages
        self.foundOldest = foundOldest
        self.foundNewest = foundNewest
        self.anchor = anchor
    }
}

public struct RegisterSnapshot: Sendable {
    public var queueID: String
    public var lastEventID: Int
    public var selfUserID: Int
    public var selfEmail: String
    public var realmName: String
    public var realmEmoji: [String: RealmEmoji]
    public var channels: [Channel]
    public var users: [User]
    public var recentDMs: [RecentDM]
    public var unread: UnreadState
    public var mutedTopics: [(streamID: Int, topic: String)]
}

public enum ZulipEvent: Sendable {
    case message(Message)
    case updateMessage(id: Int, html: String?, topic: String?, streamID: Int?)
    case deleteMessage(ids: [Int])
    case flags(ids: [Int], flag: String, op: String)
    case reaction(messageID: Int, emojiName: String, emojiCode: String, reactionType: String, userID: Int, op: String)
    case typing(senderID: Int, op: String, streamID: Int?, topic: String?, userIDs: [Int]?)
    case presence(userID: Int, presence: UserPresence)
    case userStatus(userID: Int, status: UserStatus)
    case subscription(op: String, streams: [Channel])
    case realmUser(op: String, person: User)
    case realmEmoji(emojis: [String: RealmEmoji])
    case mutedTopics(topics: [(streamID: Int, topic: String)])
    case heartbeat
    case restart
    case other(String)
}

public struct APIError: Error, LocalizedError, Sendable {
    public var status: Int
    public var message: String
    public var code: String

    public init(status: Int, message: String, code: String = "") {
        self.status = status
        self.message = message
        self.code = code
    }

    public var errorDescription: String? { message }
    public var isDeadQueue: Bool { code == "BAD_EVENT_QUEUE_ID" }
    public var isUnauthorized: Bool { status == 401 || code == "UNAUTHORIZED" }
}
