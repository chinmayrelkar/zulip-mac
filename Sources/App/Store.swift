import AppKit
import Observation
import UniformTypeIdentifiers
import UserNotifications
import ZulipCore

public enum SidebarSource: Hashable, Identifiable {
    case recentTopics
    case allMessages
    case mentions
    case starred
    case directMessages
    case channel(Int)

    public var id: String {
        switch self {
        case .recentTopics: "recent"
        case .allMessages: "all"
        case .mentions: "mentions"
        case .starred: "starred"
        case .directMessages: "dm"
        case .channel(let id): "c-\(id)"
        }
    }
}

public struct RecentTopicItem: Identifiable, Hashable, Sendable {
    public var id: String { "\(streamID):\(topic)" }
    public var streamID: Int
    public var streamName: String
    public var streamColor: String
    public var topic: String
    public var isResolved: Bool
    public var isMuted: Bool
    public var unreadCount: Int
    public var maxMessageID: Int
    public var participantUserIDs: [Int]
}

public struct MessageThread {
    public var messages: [Message] = []
    public var foundOldest = false
    public var foundNewest = true
    public var isLoading = false
    public init(messages: [Message] = [], foundOldest: Bool = false, foundNewest: Bool = true, isLoading: Bool = false) {
        self.messages = messages
        self.foundOldest = foundOldest
        self.foundNewest = foundNewest
        self.isLoading = isLoading
    }
}

public enum TopicSortOrder: String, CaseIterable, Identifiable, Codable {
    case newestLast = "Newest at bottom"
    case newestFirst = "Newest on top"

    public var id: String { rawValue }
}

@MainActor
@Observable
public final class Store {
    public var session: Session = .loggedOut
    public var realmName = "Zulip"
    public var site = Auth.defaultSite
    public var selfUserID = 0
    public var selfEmail = ""
    public var channels: [Channel] = []
    public var users: [Int: User] = [:]
    public var topicsByStream: [Int: [Topic]] = [:]
    public var channelActivity: [Int: Int] = [:]
    public var mutedTopics: Set<String> = [] // "\(streamID):\(topic)"
    public var dms: [RecentDM] = []
    public var unread = UnreadState()
    public var realmEmojis: [String: RealmEmoji] = [:]
    public var presences: [Int: UserPresence] = [:]
    public var userStatuses: [Int: UserStatus] = [:]
    public var typingUsers: [String: Set<Int>] = [:] // key -> Set of userIDs
    public var mentionsMessages: [Message] = []
    public var readReceipts: [Int: [Int]] = [:] // messageID -> userIDs who read it

    public var selectedSource: SidebarSource? = .recentTopics
    public var selectedTopic: String?
    public var selectedDMKey: String?
    public var channelQuery = ""
    public var topicQuery = ""
    public var showMutedInRecent = false
    public var showUnreadOnlyInRecent = false
    public var showResolvedInChannel = false
    public var mentionsSortOrder: TopicSortOrder = .newestLast
    public var mentionsUnreadOnly = false
    public var recentSortOrder: TopicSortOrder = .newestFirst
    public var channelTopicsSortOrder: TopicSortOrder = .newestFirst

    public var tabs: [ConversationTab] = []
    public var activeTabID: ConversationTab.ID?
    public var threads: [UUID: MessageThread] = [:]
    public var errorMessage: String?
    public var status: String?
    public var isBusy = false
    public var media: MediaLoader?
    public var lightbox: LightboxItem?

    // Modals & Sheets
    public var showQuickSwitcher = false
    public var showCommandPalette = false
    public var showShortcutHelp = false
    public var showNewDMModal = false
    public var showChannelBrowser = false
    public var showStatusModal = false
    public var focusSearchTrigger: Int = 0
    public var focusComposerTrigger: Int = 0
    public var focusTopicListTrigger: Int = 0
    public var focusMessagesTrigger: Int = 0
    public var selectedMessageID: Int?
    public var showLeftPane = true
    public var showCenterPane = true
    public var selectedUserForProfile: User?
    public var editingMessage: Message?
    public var viewingHistoryForMessage: Message?
    public var historyItems: [MessageEditHistoryItem] = []
    public var allStreamsList: [Channel] = []

    var client: ZulipClient?
    var queueID: String?
    var lastEventID: Int = -1
    var eventsTask: Task<Void, Never>?
    var topicsTask: Task<Void, Never>?
    var loadTasks: [UUID: Task<Void, Never>] = [:]
    var typingTimer: Task<Void, Never>?
    var lastTypingReport: Date?

    public enum Session {
        case loggedOut
        case connecting
        case ready
    }

    public init() {}
}

