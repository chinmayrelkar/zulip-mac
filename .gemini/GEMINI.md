# Zulip Mac (`zulip-mac`) Architecture & Knowledge Base

Native macOS Zulip client built with Swift 6, SwiftUI, and AppKit targeting macOS 14.0+.

## Architecture Overview

### 1. `ZulipCore`
- **`Models.swift`**: Models for Zulip REST API and events system (`Message`, `Channel`, `Topic`, `User`, `Reaction`, `RealmEmoji`, `UserPresence`, `UserStatus`, `MessageEditHistoryItem`, `UnreadState`, `ZulipEvent`).
- **`Client.swift`**: Fully featured `actor ZulipClient` implementing REST API endpoints (messages, topics, reactions, presence, typing, subscriptions, user status, user uploads, edit/delete messages, and long-polling events queue).
- **`Emoji.swift`**: Dynamic Unicode hex codepoint decoder (`1f44d` -> 👍, `1f469-200d-1f4bb` -> 👩‍💻), realm emoji resolver, and Zulip shortcode mappings.
- **`Narrow.swift` & `Search.swift`**: High-performance parser and narrow representation covering `.topic`, `.dm`, `.recentTopics`, `.allMessages`, `.mentions`, `.starred`, and structured `.search`.
- **`MessageHTML.swift`**: Clean HTML parser generating rich blocks (paragraphs, styled text, inline mentions, quotes, spoilers, markdown tables, syntax codeblocks, inline media and attachments) and Markdown quote formatting.
- **`Auth.swift` & `Avatar.swift`**: Secure credentials storage and Gravatar / Zulip avatar resolution.

### 2. `ZulipMac` Application Layer (`Sources/App/`)
- **`Store.swift`**: Central `@Observable` `@MainActor` state store managing active tabs, unread counts, typing status, presence updates, draft persistence, optimistic reaction/star updates, and background event streaming.
- **`ContentView.swift`**: Root 3-column `NavigationSplitView` with keyboard shortcuts (`Cmd+K`, `Cmd+N`, `Cmd+1..4`, `Cmd+W`, `Ctrl+Tab`), lightbox overlays, and modals.
- **`SidebarViews.swift`**: Standard Zulip navigation feeds (Recent Conversations, All Messages, Mentions, Starred), DM section, and Channels list with unread badges, stream colors, and context menus.
- **`TopicListView.swift`**: Middle column rendering active topic list or recent conversations feed with resolve/mute state and unread counts. Uses AppKit-backed virtualized `List` (`.listStyle(.plain)` with `.scrollContentBackground(.hidden)`) for high-performance rendering of 10,000+ topics without AttributeGraph layout explosion.
- **`MessageViews.swift`**: Rich message stream with date separators, avatars with presence dots, message block grouping cards, reaction pills bar, hover action toolbar, and lightbox integrations.
- **`ComposeView.swift`**: Formatting toolbar, attachments upload, drag-and-drop file upload, and real-time typing indicators.
- **`Modals.swift`**: Quick Switcher (`Cmd+K`) command palette, New DM picker, Channel Browser, Message Edit & History sheets, and User Profile popovers.

## Performance & Virtualization Conventions
- **macOS Large Lists**: Always use SwiftUI `List` (backed by `NSTableView`) rather than `ScrollView + LazyVStack` for lists that can scale to thousands of items (e.g. `recentConversations`, topics, search). `LazyVStack` does not fully virtualize layout subview engines on macOS and causes high memory consumption and main-thread hangs with 5,000+ items.
- **Card Styling in Lists**: To style items as distinct cards within `List`, set `.listRowInsets(...)`, `.listRowSeparator(.hidden)`, and `.listRowBackground(Color.clear)`, wrapping the row contents in a `.buttonStyle(.plain)` `Button` with a bordered `RoundedRectangle` background.

