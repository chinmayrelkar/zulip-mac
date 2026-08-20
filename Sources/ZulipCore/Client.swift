import Foundation

public actor ZulipClient {
    public let credentials: Credentials
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(credentials: Credentials) {
        self.credentials = credentials
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    public func register() async throws -> RegisterSnapshot {
        let body: [String: String] = [
            "apply_markdown": "true",
            "client_gravatar": "false",
            "slim_presence": "true",
            "event_types": Self.json([
                "message", "update_message", "delete_message", "reaction",
                "update_message_flags", "subscription", "realm_user",
                "realm_emoji", "typing", "presence", "user_status",
                "muted_topics", "user_topic"
            ]),
            "fetch_event_types": Self.json([
                "message", "subscription", "realm_user", "update_message_flags",
                "realm", "recent_private_conversations", "realm_emoji",
                "presence", "muted_topics", "user_topics"
            ]),
            "client_capabilities": Self.json([
                "notification_settings_null": true,
                "bulk_message_deletion": true,
                "user_avatar_url_field_optional": false,
                "stream_typing_notifications": true,
                "user_settings_object": true,
                "empty_topic_name": true,
            ] as [String: Bool]),
        ]
        let data = try await request("POST", path: "/api/v1/register", form: body)
        let raw = try decoder.decode(RegisterDTO.self, from: data)
        guard let queueID = raw.queueID else {
            throw APIError(status: 200, message: "register returned no queue_id", code: "NO_QUEUE")
        }
        var mutedList: [(streamID: Int, topic: String)] = []
        if let ut = raw.userTopics {
            for item in ut where item.visibilityPolicy == 2 {
                mutedList.append((streamID: item.streamID, topic: item.topicName))
            }
        }
        if let mt = raw.mutedTopics, let subs = raw.subscriptions {
            let channelMap = Dictionary(subs.map { ($0.name.lowercased(), $0.streamID) }, uniquingKeysWith: { lhs, _ in lhs })
            for item in mt {
                if let sid = channelMap[item.streamName.lowercased()] {
                    mutedList.append((streamID: sid, topic: item.topic))
                }
            }
        }
        return RegisterSnapshot(
            queueID: queueID,
            lastEventID: raw.lastEventID ?? -1,
            selfUserID: raw.userID ?? 0,
            selfEmail: raw.email ?? credentials.email,
            realmName: raw.realmName ?? raw.realmUri ?? credentials.site.host ?? "Zulip",
            realmEmoji: raw.realmEmoji ?? [:],
            channels: raw.subscriptions ?? [],
            users: (raw.realmUsers ?? []) + (raw.realmNonActiveUsers ?? []),
            recentDMs: raw.recentPrivateConversations ?? [],
            unread: raw.unreadMsgs?.asState() ?? UnreadState(),
            mutedTopics: mutedList
        )
    }

    public func events(queueID: String, lastEventID: Int, block: Bool = true) async throws -> (lastID: Int, events: [ZulipEvent]) {
        let data = try await request("GET", path: "/api/v1/events", query: [
            "queue_id": queueID,
            "last_event_id": String(lastEventID),
            "dont_block": block ? "false" : "true",
        ])
        let raw = try decoder.decode(EventsDTO.self, from: data)
        var last = lastEventID
        var events: [ZulipEvent] = []
        for event in raw.events ?? [] {
            last = max(last, event.id)
            events.append(event.asEvent())
        }
        return (last, events)
    }

    public func messages(narrow: [NarrowTerm], anchor: String, before: Int, after: Int) async throws -> MessagePage {
        let data = try await request("GET", path: "/api/v1/messages", query: [
            "anchor": anchor,
            "num_before": String(before),
            "num_after": String(after),
            "narrow": Self.json(narrow),
            "apply_markdown": "true",
            "allow_empty_topic_name": "true",
            "client_gravatar": "false",
        ])
        let raw = try decoder.decode(MessagesDTO.self, from: data)
        return MessagePage(
            messages: raw.messages ?? [],
            foundOldest: raw.foundOldest ?? false,
            foundNewest: raw.foundNewest ?? true,
            anchor: raw.anchor
        )
    }

    public func topics(streamID: Int) async throws -> [Topic] {
        let data = try await request("GET", path: "/api/v1/users/me/\(streamID)/topics")
        return try decoder.decode(TopicsDTO.self, from: data).topics ?? []
    }

    public func send(narrow: Narrow, content: String) async throws -> Int {
        var form: [String: String] = ["content": content, "read_by_sender": "true"]
        switch narrow {
        case .topic(let streamID, _, let topic):
            form["type"] = "stream"
            form["to"] = String(streamID)
            form["topic"] = topic
        case .dm(let userIDs):
            form["type"] = "direct"
            form["to"] = Self.json(userIDs)
        case .allMessages, .recentTopics, .mentions, .starred, .search:
            throw APIError(status: 400, message: "Can't compose into this view", code: "INVALID_COMPOSE")
        }
        let data = try await request("POST", path: "/api/v1/messages", form: form)
        return try decoder.decode(SendDTO.self, from: data).id
    }

    public func addReaction(messageID: Int, emojiName: String, emojiCode: String? = nil, reactionType: String? = nil) async throws {
        var form: [String: String] = ["emoji_name": emojiName]
        if let emojiCode, !emojiCode.isEmpty { form["emoji_code"] = emojiCode }
        if let reactionType, !reactionType.isEmpty { form["reaction_type"] = reactionType }
        _ = try await request("POST", path: "/api/v1/messages/\(messageID)/reactions", form: form)
    }

    public func removeReaction(messageID: Int, emojiName: String, emojiCode: String? = nil, reactionType: String? = nil) async throws {
        var query: [String: String] = ["emoji_name": emojiName]
        if let emojiCode, !emojiCode.isEmpty { query["emoji_code"] = emojiCode }
        if let reactionType, !reactionType.isEmpty { query["reaction_type"] = reactionType }
        _ = try await request("DELETE", path: "/api/v1/messages/\(messageID)/reactions", query: query)
    }

    public func editMessage(
        messageID: Int,
        content: String? = nil,
        topic: String? = nil,
        streamID: Int? = nil,
        propagateMode: String = "change_one"
    ) async throws {
        var form: [String: String] = ["propagate_mode": propagateMode]
        if let content { form["content"] = content }
        if let topic { form["topic"] = topic }
        if let streamID { form["stream_id"] = String(streamID) }
        _ = try await request("PATCH", path: "/api/v1/messages/\(messageID)", form: form)
    }

    public func deleteMessage(messageID: Int) async throws {
        _ = try await request("DELETE", path: "/api/v1/messages/\(messageID)")
    }

    public func getMessageHistory(messageID: Int) async throws -> [MessageEditHistoryItem] {
        let data = try await request("GET", path: "/api/v1/messages/\(messageID)/history")
        let raw = try decoder.decode(MessageHistoryDTO.self, from: data)
        return raw.messageHistory ?? []
    }

    public func getReadReceipts(messageID: Int) async throws -> [Int] {
        let data = try await request("GET", path: "/api/v1/messages/\(messageID)/read_receipts")
        return try decoder.decode(ReadReceiptsDTO.self, from: data).userIDs ?? []
    }

    public func toggleStar(messageIDs: [Int], star: Bool) async throws {
        guard !messageIDs.isEmpty else { return }
        _ = try await request("POST", path: "/api/v1/messages/flags", form: [
            "messages": Self.json(messageIDs),
            "op": star ? "add" : "remove",
            "flag": "starred",
        ])
    }

    public func uploadFile(filename: String, data: Data, mimeType: String = "application/octet-stream") async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var base = credentials.site.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/api/v1/user_uploads") else {
            throw APIError(status: 0, message: "bad url", code: "BAD_URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Basic \(credentials.basicToken)", forHTTPHeaderField: "Authorization")
        req.setValue("ZulipMac", forHTTPHeaderField: "User-Agent")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (resData, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = try? decoder.decode(ErrorDTO.self, from: resData), error.result == "error" {
            throw APIError(status: status, message: error.msg ?? "Upload failed", code: error.code ?? "")
        }
        guard (200...299).contains(status) else {
            throw APIError(status: status, message: "HTTP \(status)", code: "HTTP")
        }
        let raw = try decoder.decode(UploadDTO.self, from: resData)
        guard let uri = raw.uri else {
            throw APIError(status: status, message: "No URI returned in upload response", code: "NO_URI")
        }
        return uri
    }

    public func sendTyping(op: String, to: [Int]? = nil, streamID: Int? = nil, topic: String? = nil) async throws {
        var form: [String: String] = ["op": op]
        if let streamID {
            form["type"] = "stream"
            form["to"] = Self.json([streamID])
            if let topic { form["topic"] = topic }
        } else if let to, !to.isEmpty {
            form["type"] = "direct"
            form["to"] = Self.json(to)
        }
        _ = try await request("POST", path: "/api/v1/typing", form: form)
    }

    public func markTopicRead(streamID: Int, topic: String) async throws {
        _ = try await request("POST", path: "/api/v1/mark_topic_as_read", form: [
            "stream_id": String(streamID),
            "topic_name": topic,
        ])
    }

    public func markChannelRead(streamID: Int) async throws {
        _ = try await request("POST", path: "/api/v1/mark_stream_as_read", form: [
            "stream_id": String(streamID),
        ])
    }

    public func markAllRead() async throws {
        _ = try await request("POST", path: "/api/v1/mark_all_as_read")
    }

    public func markRead(ids: [Int]) async throws {
        guard !ids.isEmpty else { return }
        _ = try await request("POST", path: "/api/v1/messages/flags", form: [
            "messages": Self.json(ids),
            "op": "add",
            "flag": "read",
        ])
    }

    public func updateTopicVisibility(streamID: Int, topic: String, policy: Int) async throws {
        _ = try await request("POST", path: "/api/v1/user_topics", form: [
            "stream_id": String(streamID),
            "topic": topic,
            "visibility_policy": String(policy),
        ])
    }

    public func updateSubscription(streamID: Int, isMuted: Bool? = nil, pinToTop: Bool? = nil, color: String? = nil) async throws {
        struct SubProp: Encodable {
            var streamID: Int
            var property: String
            var value: AnyEncodableValue
            enum CodingKeys: String, CodingKey {
                case streamID = "stream_id"
                case property, value
            }
        }
        enum AnyEncodableValue: Encodable {
            case bool(Bool)
            case string(String)
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .bool(let bool): try container.encode(bool)
                case .string(let string): try container.encode(string)
                }
            }
        }
        var list: [SubProp] = []
        if let isMuted { list.append(SubProp(streamID: streamID, property: "is_muted", value: .bool(isMuted))) }
        if let pinToTop { list.append(SubProp(streamID: streamID, property: "pin_to_top", value: .bool(pinToTop))) }
        if let color { list.append(SubProp(streamID: streamID, property: "color", value: .string(color))) }
        guard !list.isEmpty else { return }

        _ = try await request("POST", path: "/api/v1/users/me/subscriptions/properties", form: [
            "subscription_data": Self.json(list),
        ])
    }

    public func getAllStreams() async throws -> [Channel] {
        let data = try await request("GET", path: "/api/v1/streams")
        return try decoder.decode(StreamsDTO.self, from: data).streams ?? []
    }

    public func subscribe(streamNames: [String]) async throws {
        let subs = streamNames.map { ["name": $0] }
        _ = try await request("POST", path: "/api/v1/users/me/subscriptions", form: [
            "subscriptions": Self.json(subs),
        ])
    }

    public func unsubscribe(streamNames: [String]) async throws {
        _ = try await request("DELETE", path: "/api/v1/users/me/subscriptions", form: [
            "subscriptions": Self.json(streamNames),
        ])
    }

    public func updatePresence(status: String) async throws {
        _ = try await request("POST", path: "/api/v1/users/me/presence", form: [
            "status": status,
            "new_user_input": "true",
        ])
    }

    public func updateUserStatus(statusText: String? = nil, emojiName: String? = nil, emojiCode: String? = nil, away: Bool? = nil) async throws {
        var form: [String: String] = [:]
        if let statusText { form["status_text"] = statusText }
        if let emojiName { form["emoji_name"] = emojiName }
        if let emojiCode { form["emoji_code"] = emojiCode }
        if let away { form["away"] = away ? "true" : "false" }
        _ = try await request("POST", path: "/api/v1/users/me/status", form: form)
    }

    public func ownUser() async throws -> User {
        let data = try await request("GET", path: "/api/v1/users/me")
        return try decoder.decode(User.self, from: data)
    }

    public func fetchData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        if url.host == nil || url.host == credentials.site.host {
            request.setValue("Basic \(credentials.basicToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("ZulipMac", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw APIError(status: status, message: "HTTP \(status)", code: "HTTP")
        }
        return data
    }

    public func signedUploadURL(_ url: URL) async throws -> URL {
        guard let path = MediaURL.uploadAPIPath(for: url) else { return url }
        let data = try await request("GET", path: path)
        let raw = try decoder.decode(TempURLDTO.self, from: data)
        return MediaURL.resolve(raw.url, site: credentials.site) ?? url
    }

    public static func login(site: URL, username: String, password: String) async throws -> Credentials {
        var base = site.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/api/v1/fetch_api_key") else {
            throw APIError(status: 0, message: "bad url", code: "BAD_URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("ZulipMac", forHTTPHeaderField: "User-Agent")
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+="))
        let user = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? username
        let pass = password.addingPercentEncoding(withAllowedCharacters: allowed) ?? password
        request.httpBody = Data("username=\(user)&password=\(pass)".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        if let error = try? decoder.decode(ErrorDTO.self, from: data), error.result == "error" {
            throw APIError(status: status, message: error.msg ?? "login failed", code: error.code ?? "")
        }
        guard (200...299).contains(status) else {
            throw APIError(status: status, message: "HTTP \(status)", code: "HTTP")
        }
        let raw = try decoder.decode(FetchKeyDTO.self, from: data)
        return Credentials(email: raw.email, apiKey: raw.apiKey, site: site)
    }

    private func request(
        _ method: String,
        path: String,
        query: [String: String] = [:],
        form: [String: String] = [:]
    ) async throws -> Data {
        var base = credentials.site.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard var components = URLComponents(string: base + path) else {
            throw APIError(status: 0, message: "bad url", code: "BAD_URL")
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError(status: 0, message: "bad url", code: "BAD_URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Basic \(credentials.basicToken)", forHTTPHeaderField: "Authorization")
        request.setValue("ZulipMac", forHTTPHeaderField: "User-Agent")
        if !form.isEmpty {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = encodeForm(form)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = try? decoder.decode(ErrorDTO.self, from: data), error.result == "error" {
            throw APIError(status: status, message: error.msg ?? "request failed", code: error.code ?? "")
        }
        if status == 401 {
            throw APIError(status: status, message: "unauthorized", code: "UNAUTHORIZED")
        }
        if !(200...299).contains(status) {
            throw APIError(status: status, message: "HTTP \(status)", code: "HTTP")
        }
        return data
    }

    private func encodeForm(_ form: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+="))
        let body = form.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encoded)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

private struct LegacyMutedTopicDTO: Decodable, Sendable {
    var streamName: String
    var topic: String
    var dateMuted: Double?

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        streamName = (try? container.decode(String.self)) ?? ""
        topic = (try? container.decode(String.self)) ?? ""
        dateMuted = try? container.decode(Double.self)
    }
}

private struct UserTopicDTO: Decodable, Sendable {
    var streamID: Int
    var topicName: String
    var visibilityPolicy: Int

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case topicName = "topic_name"
        case visibilityPolicy = "visibility_policy"
    }
}

private struct RegisterDTO: Decodable, Sendable {
    var queueID: String?
    var lastEventID: Int?
    var userID: Int?
    var email: String?
    var realmName: String?
    var realmUri: String?
    var realmEmoji: [String: RealmEmoji]?
    var subscriptions: [Channel]?
    var realmUsers: [User]?
    var realmNonActiveUsers: [User]?
    var recentPrivateConversations: [RecentDM]?
    var unreadMsgs: UnreadMsgsDTO?
    var mutedTopics: [LegacyMutedTopicDTO]?
    var userTopics: [UserTopicDTO]?

    enum CodingKeys: String, CodingKey {
        case queueID = "queue_id"
        case lastEventID = "last_event_id"
        case userID = "user_id"
        case email
        case realmName = "realm_name"
        case realmUri = "realm_uri"
        case realmEmoji = "realm_emoji"
        case subscriptions
        case realmUsers = "realm_users"
        case realmNonActiveUsers = "realm_non_active_users"
        case recentPrivateConversations = "recent_private_conversations"
        case unreadMsgs = "unread_msgs"
        case mutedTopics = "muted_topics"
        case userTopics = "user_topics"
    }
}

private struct TopicsDTO: Decodable, Sendable {
    var topics: [Topic]?
}

private struct StreamsDTO: Decodable, Sendable {
    var streams: [Channel]?
}

private struct MessagesDTO: Decodable, Sendable {
    var messages: [Message]?
    var foundOldest: Bool?
    var foundNewest: Bool?
    var anchor: Int?

    enum CodingKeys: String, CodingKey {
        case messages
        case foundOldest = "found_oldest"
        case foundNewest = "found_newest"
        case anchor
    }
}

private struct SendDTO: Decodable, Sendable {
    var id: Int
}

private struct UploadDTO: Decodable, Sendable {
    var uri: String?
}

private struct MessageHistoryDTO: Decodable, Sendable {
    var messageHistory: [MessageEditHistoryItem]?
    enum CodingKeys: String, CodingKey {
        case messageHistory = "message_history"
    }
}

private struct ReadReceiptsDTO: Decodable, Sendable {
    var userIDs: [Int]?
    enum CodingKeys: String, CodingKey {
        case userIDs = "user_ids"
    }
}

private struct TempURLDTO: Decodable, Sendable {
    var url: String
}

private struct FetchKeyDTO: Decodable, Sendable {
    var apiKey: String
    var email: String

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case email
    }
}

private struct ErrorDTO: Decodable, Sendable {
    var result: String?
    var msg: String?
    var code: String?
}

private struct EventsDTO: Decodable, Sendable {
    var events: [EventDTO]?
}

private struct EventDTO: Decodable, Sendable {
    var id: Int
    var type: String
    var op: String?
    var operation: String?
    var message: Message?
    var flags: [String]?
    var messageID: Int?
    var messageIds: [Int]?
    var renderedContent: String?
    var subject: String?
    var streamID: Int?
    var flag: String?
    var emojiName: String?
    var emojiCode: String?
    var reactionType: String?
    var userID: Int?
    var sender: TypingPerson?
    var recipients: [TypingPerson]?
    var statusText: String?
    var away: Bool?
    var subscriptions: [Channel]?
    var person: User?
    var realmEmoji: [String: RealmEmoji]?

    struct TypingPerson: Decodable, Sendable {
        var userID: Int?
        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, op, operation, message, flags, flag
        case messageID = "message_id"
        case messageIds = "message_ids"
        case renderedContent = "rendered_content"
        case subject
        case streamID = "stream_id"
        case emojiName = "emoji_name"
        case emojiCode = "emoji_code"
        case reactionType = "reaction_type"
        case userID = "user_id"
        case sender, recipients
        case statusText = "status_text"
        case away
        case subscriptions
        case person
        case realmEmoji = "realm_emoji"
    }

    func asEvent() -> ZulipEvent {
        switch type {
        case "message":
            guard var message else { return .other(type) }
            if let flags { message.flags = Set(flags) }
            return .message(message)
        case "update_message":
            return .updateMessage(
                id: messageID ?? 0,
                html: renderedContent,
                topic: subject,
                streamID: streamID
            )
        case "delete_message":
            let ids = messageIds ?? messageID.map { [$0] } ?? []
            return .deleteMessage(ids: ids)
        case "update_message_flags":
            return .flags(ids: messageIds ?? [], flag: flag ?? "", op: op ?? operation ?? "")
        case "reaction":
            return .reaction(
                messageID: messageID ?? 0,
                emojiName: emojiName ?? "",
                emojiCode: emojiCode ?? emojiName ?? "",
                reactionType: reactionType ?? "unicode_emoji",
                userID: userID ?? 0,
                op: op ?? ""
            )
        case "typing":
            return .typing(
                senderID: sender?.userID ?? userID ?? 0,
                op: op ?? "",
                streamID: streamID,
                topic: subject,
                userIDs: recipients?.compactMap(\.userID)
            )
        case "user_status":
            return .userStatus(
                userID: userID ?? 0,
                status: UserStatus(
                    statusText: statusText,
                    emojiName: emojiName,
                    emojiCode: emojiCode,
                    reactionType: reactionType,
                    away: away
                )
            )
        case "subscription":
            return .subscription(op: op ?? "", streams: subscriptions ?? [])
        case "realm_user":
            if let person { return .realmUser(op: op ?? "", person: person) }
            return .other(type)
        case "realm_emoji":
            return .realmEmoji(emojis: realmEmoji ?? [:])
        case "muted_topics":
            return .mutedTopics(topics: [])
        case "heartbeat":
            return .heartbeat
        case "restart":
            return .restart
        default:
            return .other(type)
        }
    }
}
