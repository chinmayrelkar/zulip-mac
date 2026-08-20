import Foundation

public struct CachedAppState: Codable, Sendable {
    public var channels: [Channel]
    public var users: [User]
    public var topicsByStream: [Int: [Topic]]
    public var channelActivity: [Int: Int]
    public var mutedTopics: [String]
    public var dms: [RecentDM]
    public var unread: UnreadState
    public var realmName: String
    public var selfUserID: Int
    public var selfEmail: String

    public init(
        channels: [Channel] = [],
        users: [User] = [],
        topicsByStream: [Int: [Topic]] = [:],
        channelActivity: [Int: Int] = [:],
        mutedTopics: [String] = [],
        dms: [RecentDM] = [],
        unread: UnreadState = UnreadState(),
        realmName: String = "",
        selfUserID: Int = 0,
        selfEmail: String = ""
    ) {
        self.channels = channels
        self.users = users
        self.topicsByStream = topicsByStream
        self.channelActivity = channelActivity
        self.mutedTopics = mutedTopics
        self.dms = dms
        self.unread = unread
        self.realmName = realmName
        self.selfUserID = selfUserID
        self.selfEmail = selfEmail
    }
}

public enum LocalCache {
    public static var cacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/zulip-mac/cache", directoryHint: .isDirectory)
    }

    public static var threadsDirectory: URL {
        cacheDirectory.appending(path: "threads", directoryHint: .isDirectory)
    }

    private static var avatarsDirectory: URL {
        cacheDirectory.appending(path: "avatars", directoryHint: .isDirectory)
    }

    public static func loadAvatar(_ userID: Int) -> Data? {
        let file = avatarsDirectory.appending(path: "\(userID).png", directoryHint: .notDirectory)
        return try? Data(contentsOf: file)
    }

    public static func saveAvatar(_ data: Data, userID: Int) {
        Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
                try data.write(to: avatarsDirectory.appending(path: "\(userID).png", directoryHint: .notDirectory), options: .atomic)
            } catch {
                // Silently ignore disk write failures
            }
        }
    }

    private static var stateFileURL: URL {
        cacheDirectory.appending(path: "state.json", directoryHint: .notDirectory)
    }

    public static func loadState() -> CachedAppState? {
        guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
        return try? JSONDecoder().decode(CachedAppState.self, from: data)
    }

    public static func saveState(_ state: CachedAppState) {
        Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(state)
                try data.write(to: stateFileURL, options: .atomic)
            } catch {
                // Silently ignore disk write failures
            }
        }
    }

    public static func loadThreadMessages(key: String) -> [Message]? {
        let file = threadFileURL(for: key)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode([Message].self, from: data)
    }

    public static func saveThreadMessages(key: String, messages: [Message]) {
        let file = threadFileURL(for: key)
        let limited = Array(messages.suffix(200))
        Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(at: threadsDirectory, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(limited)
                try data.write(to: file, options: .atomic)
            } catch {
                // Silently ignore disk write failures
            }
        }
    }

    public static func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    private static func threadFileURL(for key: String) -> URL {
        let safeName = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return threadsDirectory.appending(path: "\(safeName).json", directoryHint: .notDirectory)
    }
}
