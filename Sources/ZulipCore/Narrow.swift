import Foundation

public struct NarrowTerm: Hashable, Sendable, Codable {
    public var op: String
    public var operand: Operand
    public var negated: Bool

    public init(op: String, operand: Operand, negated: Bool = false) {
        self.op = op
        self.operand = operand
        self.negated = negated
    }

    public enum Operand: Hashable, Sendable, Codable {
        case string(String)
        case int(Int)
        case ints([Int])

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .ints(let value): try container.encode(value)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode([Int].self) {
                self = .ints(value)
            } else if let value = try? container.decode(Int.self) {
                self = .int(value)
            } else {
                self = .string(try container.decode(String.self))
            }
        }

        public var stringValue: String {
            switch self {
            case .string(let value): return value
            case .int(let value): return String(value)
            case .ints(let value): return value.map(String.init).joined(separator: ",")
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case op = "operator"
        case operand
        case negated
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(op, forKey: .op)
        try container.encode(operand, forKey: .operand)
        if negated {
            try container.encode(true, forKey: .negated)
        }
    }
}

public enum Narrow: Hashable, Sendable {
    case topic(streamID: Int, streamName: String, topic: String)
    case dm(userIDs: [Int])
    case allMessages
    case recentTopics
    case mentions
    case starred
    case search(query: String, terms: [NarrowTerm], anchor: String)

    public var title: String {
        switch self {
        case .topic(_, let stream, let topic):
            return "\(stream) › \(topic.isEmpty ? "(no topic)" : topic)"
        case .dm(let ids):
            return "dm:\(ids.map(String.init).joined(separator: ","))"
        case .allMessages:
            return "All messages"
        case .recentTopics:
            return "Recent conversations"
        case .mentions:
            return "Mentions"
        case .starred:
            return "Starred messages"
        case .search(let query, _, _):
            return query
        }
    }

    public var shortTitle: String {
        switch self {
        case .topic(_, _, let topic):
            return topic.isEmpty ? "(no topic)" : topic
        case .dm:
            return title
        case .allMessages:
            return "All messages"
        case .recentTopics:
            return "Recent"
        case .mentions:
            return "Mentions"
        case .starred:
            return "Starred"
        case .search(let query, _, _):
            return query
        }
    }

    public var terms: [NarrowTerm] {
        switch self {
        case .topic(let streamID, _, let topic):
            return [
                NarrowTerm(op: "channel", operand: .int(streamID)),
                NarrowTerm(op: "topic", operand: .string(topic)),
            ]
        case .dm(let userIDs):
            return [NarrowTerm(op: "dm", operand: .ints(userIDs.sorted()))]
        case .allMessages:
            return []
        case .recentTopics:
            return []
        case .mentions:
            return [NarrowTerm(op: "is", operand: .string("mentioned"))]
        case .starred:
            return [NarrowTerm(op: "is", operand: .string("starred"))]
        case .search(_, let terms, _):
            return terms
        }
    }

    public var anchor: String {
        switch self {
        case .search(_, _, let anchor):
            return anchor
        case .allMessages, .recentTopics, .mentions, .starred, .topic, .dm:
            return "newest"
        }
    }

    public var isConversation: Bool {
        switch self {
        case .topic, .dm: true
        case .allMessages, .recentTopics, .mentions, .starred, .search: false
        }
    }

    public func matches(_ message: Message) -> Bool {
        switch self {
        case .topic(let streamID, _, let topic):
            return message.streamID == streamID && message.topic == topic
        case .dm(let userIDs):
            return message.type == "private" && Set(message.dmUserIDs) == Set(userIDs)
        case .allMessages:
            return true
        case .recentTopics:
            return true
        case .mentions:
            return message.isMention
        case .starred:
            return message.isStarred
        case .search:
            return false
        }
    }
}

public struct ConversationTab: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var narrow: Narrow
    public var pinned: Bool
    public var draft: String
    public var unreadSinceOpen: Int

    public init(
        id: UUID = UUID(),
        narrow: Narrow,
        pinned: Bool = false,
        draft: String = "",
        unreadSinceOpen: Int = 0
    ) {
        self.id = id
        self.narrow = narrow
        self.pinned = pinned
        self.draft = draft
        self.unreadSinceOpen = unreadSinceOpen
    }
}
