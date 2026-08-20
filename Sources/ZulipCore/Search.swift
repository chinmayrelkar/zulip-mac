import Foundation

public struct SearchContext: Sendable {
    public var selfEmail: String
    public var selfUserID: Int
    public var users: [User]

    public init(selfEmail: String, selfUserID: Int, users: [User]) {
        self.selfEmail = selfEmail
        self.selfUserID = selfUserID
        self.users = users
    }
}

public struct ParsedSearch: Equatable, Sendable {
    public var query: String
    public var terms: [NarrowTerm]
    public var anchor: String
    public var conversation: Narrow?

    public init(query: String, terms: [NarrowTerm], anchor: String = "newest", conversation: Narrow? = nil) {
        self.query = query
        self.terms = terms
        self.anchor = anchor
        self.conversation = conversation
    }
}

public enum Search {
    private static let operators: Set<String> = [
        "channel", "stream", "channels", "streams",
        "topic", "sender", "is", "has",
        "dm", "pm-with", "dm-including", "group-pm-with",
        "mentions", "id", "with", "near", "search",
    ]

    private static let aliases: [String: String] = [
        "stream": "channel",
        "streams": "channels",
        "pm-with": "dm",
        "group-pm-with": "dm-including",
    ]

    public static func parse(_ raw: String, context: SearchContext? = nil) -> ParsedSearch {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var terms: [NarrowTerm] = []
        var keywords: [String] = []
        var anchor = "newest"
        var channel: NarrowTerm.Operand?
        var topic: String?
        var dmIDs: [Int]?
        var extra = false

        for token in tokenize(query) {
            let parsed = splitOperator(token)
            guard let parsed else {
                keywords.append(token)
                extra = true
                continue
            }
            let op = aliases[parsed.op] ?? parsed.op
            if op == "near" {
                if let id = Int(parsed.operand), !parsed.negated {
                    anchor = String(id)
                }
                continue
            }
            let operand = resolveOperand(op: op, raw: parsed.operand, context: context)
            terms.append(NarrowTerm(op: op, operand: operand, negated: parsed.negated))
            if parsed.negated {
                extra = true
                continue
            }
            switch op {
            case "channel":
                channel = operand
            case "topic":
                topic = parsed.operand
            case "dm":
                if case .ints(let ids) = operand { dmIDs = ids }
                else { extra = true }
            default:
                extra = true
            }
        }

        if !keywords.isEmpty {
            terms.append(NarrowTerm(op: "search", operand: .string(keywords.joined(separator: " "))))
        }

        var conversation: Narrow?
        if !extra, let dmIDs, channel == nil, topic == nil {
            conversation = .dm(userIDs: dmIDs.sorted())
        } else if !extra, let channel, let topic, dmIDs == nil {
            switch channel {
            case .int(let id):
                conversation = .topic(streamID: id, streamName: "#\(id)", topic: topic)
            case .string(let name):
                conversation = .topic(streamID: 0, streamName: name, topic: topic)
            case .ints:
                break
            }
        }

        return ParsedSearch(query: query, terms: terms, anchor: anchor, conversation: conversation)
    }

    public static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuote = false
        var escape = false
        for char in input {
            if escape {
                current.append(char)
                escape = false
                continue
            }
            if char == "\\" {
                escape = true
                continue
            }
            if char == "\"" {
                inQuote.toggle()
                current.append(char)
                continue
            }
            if char.isWhitespace && !inQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(char)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func splitOperator(_ token: String) -> (negated: Bool, op: String, operand: String)? {
        var rest = token
        var negated = false
        if rest.hasPrefix("-") {
            negated = true
            rest.removeFirst()
        }
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let op = String(rest[..<colon]).lowercased()
        guard operators.contains(op) else { return nil }
        var operand = String(rest[rest.index(after: colon)...])
        if operand.hasPrefix("\""), operand.hasSuffix("\""), operand.count >= 2 {
            operand = String(operand.dropFirst().dropLast())
        }
        return (negated, op, operand)
    }

    private static func resolveOperand(op: String, raw: String, context: SearchContext?) -> NarrowTerm.Operand {
        if op == "id" || op == "with" {
            if let value = Int(raw) { return .int(value) }
        }
        if op == "channel" || op == "channels" {
            if let value = Int(raw) { return .int(value) }
            return .string(raw)
        }
        if op == "sender" {
            if raw == "me", let context {
                return .int(context.selfUserID)
            }
            if let value = Int(raw) { return .int(value) }
            if let user = resolveUser(raw, context: context) {
                return .int(user.userID)
            }
            return .string(raw)
        }
        if op == "mentions" {
            if let value = Int(raw) { return .int(value) }
            if let user = resolveUser(raw, context: context) {
                return .int(user.userID)
            }
            return .string(raw)
        }
        if op == "dm" || op == "dm-including" {
            if let context {
                let ids = raw.split(separator: ",").compactMap { part -> Int? in
                    let name = part.trimmingCharacters(in: .whitespaces)
                    if let value = Int(name) { return value }
                    return resolveUser(name, context: context)?.userID
                }
                if !ids.isEmpty { return .ints(ids) }
            }
            return .string(raw)
        }
        return .string(raw)
    }

    private static func resolveUser(_ raw: String, context: SearchContext?) -> User? {
        guard let context else { return nil }
        let needle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.caseInsensitiveCompare(context.selfEmail) == .orderedSame {
            return context.users.first { $0.userID == context.selfUserID }
        }
        let exact = context.users.filter { $0.fullName.caseInsensitiveCompare(needle) == .orderedSame }
        if exact.count == 1 { return exact[0] }
        let email = context.users.filter { $0.email.caseInsensitiveCompare(needle) == .orderedSame }
        if email.count == 1 { return email[0] }
        return nil
    }
}
