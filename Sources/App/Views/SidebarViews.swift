import AppKit
import SwiftUI
import ZulipCore

public struct ChannelSidebar: View {
    @Bindable var store: Store
    @AppStorage("sidebar_group_folders") private var groupFolders = true
    @Environment(AppSettings.self) private var settings
    @Environment(\.focusedColumn) private var focusedColumn
    @FocusState private var isListFocused: Bool
    @State private var isViewsExpanded = true
    @State private var isDMsExpanded = true
    @State private var isChannelsExpanded = true
    @State private var isMutedChannelsExpanded = false
    @State private var collapsedFolders: Set<String> = []

    public init(store: Store) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Workspace Header
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 1) {
                    Text(store.realmName)
                        .font(.system(size: settings.uiFontSize, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(store.selfEmail)
                            .font(.system(size: settings.uiSecondarySize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Search & Filter Box
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Filter channels", text: $store.channelQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !store.channelQuery.isEmpty {
                    Button {
                        store.channelQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            Divider().opacity(0.6)

            // Navigation List
            List(selection: selection) {
                // Views Section
                Section {
                    navigationRow(
                        title: "Recent conversations",
                        icon: "clock.fill",
                        iconColor: .blue,
                        tag: .recentTopics,
                        unread: store.unread.totalUnread
                    )

                    navigationRow(
                        title: "All messages",
                        icon: "tray.2.fill",
                        iconColor: .indigo,
                        tag: .allMessages,
                        unread: 0
                    )

                    navigationRow(
                        title: "Mentions",
                        icon: "at",
                        iconColor: .orange,
                        tag: .mentions,
                        unread: store.unread.mentionCount,
                        isMention: true
                    )

                    navigationRow(
                        title: "Starred messages",
                        icon: "star.fill",
                        iconColor: .yellow,
                        tag: .starred,
                        unread: 0
                    )
                } header: {
                    Text("FEEDS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                // Direct Messages Section
                Section {
                    navigationRow(
                        title: "Direct messages",
                        icon: "person.2.fill",
                        iconColor: .teal,
                        tag: .directMessages,
                        unread: store.unread.dmTotal
                    )
                } header: {
                    HStack {
                        Text("DIRECT MESSAGES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            store.showNewDMModal = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .padding(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("New direct message (⌘N)")
                    }
                    .padding(.top, 4)
                }

                // Pinned Channels Section
                if !store.pinnedChannels.isEmpty {
                    Section {
                        ForEach(store.pinnedChannels) { channel in
                            let unread = store.unread.channelCount(channel.streamID)
                            channelRow(channel: channel, unread: unread)
                                .tag(SidebarSource.channel(channel.streamID))
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8))
                            Text("PINNED (\(store.pinnedChannels.count))")
                                .font(.system(size: 10, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }

                // Channels Section
                if groupFolders {
                    // Grouped Folders & Channels
                    ForEach(store.unmutedChannelGroups) { group in
                        if group.isFolder {
                            let isCollapsed = collapsedFolders.contains(group.name)
                            Section {
                                if !isCollapsed {
                                    ForEach(group.channels) { channel in
                                        let unread = store.unread.channelCount(channel.streamID)
                                        let subName = channel.name.components(separatedBy: "/").dropFirst().joined(separator: "/")
                                        channelRow(channel: channel, unread: unread, displayName: subName.isEmpty ? channel.name : subName, isNested: true)
                                            .tag(SidebarSource.channel(channel.streamID))
                                    }
                                }
                            } header: {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if isCollapsed {
                                            collapsedFolders.remove(group.name)
                                        } else {
                                            collapsedFolders.insert(group.name)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 10)

                                        Image(systemName: isCollapsed ? "folder.fill" : "folder.badge.gearshape")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.accentColor)

                                        Text(group.name.uppercased())
                                            .font(.system(size: 10, weight: .bold))

                                        Text("(\(group.channels.count))")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        if group.totalUnread > 0 && isCollapsed {
                                            countBadge(group.totalUnread)
                                        }
                                    }
                                    .foregroundStyle(.secondary)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 4)
                            }
                        } else {
                            Section {
                                ForEach(group.channels) { channel in
                                    let unread = store.unread.channelCount(channel.streamID)
                                    channelRow(channel: channel, unread: unread)
                                        .tag(SidebarSource.channel(channel.streamID))
                                }
                            } header: {
                                channelSectionHeader
                            }
                        }
                    }
                } else {
                    // Flat Channels List
                    Section {
                        ForEach(store.unmutedChannels) { channel in
                            let unread = store.unread.channelCount(channel.streamID)
                            channelRow(channel: channel, unread: unread)
                                .tag(SidebarSource.channel(channel.streamID))
                        }
                    } header: {
                        channelSectionHeader
                    }
                }

                // Muted Channels Section
                if !store.mutedChannels.isEmpty {
                    Section(isExpanded: $isMutedChannelsExpanded) {
                        ForEach(store.mutedChannels) { channel in
                            let unread = store.unread.channelCount(channel.streamID)
                            channelRow(channel: channel, unread: unread)
                                .tag(SidebarSource.channel(channel.streamID))
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 8))
                            Text("MUTED CHANNELS (\(store.mutedChannels.count))")
                                .font(.system(size: 10, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
            }
            .listStyle(.sidebar)
            .focused($isListFocused)
            .onChange(of: focusedColumn.wrappedValue) { _, new in
                if new == .sidebar { isListFocused = true }
            }
        }
        .navigationTitle("Zulip")
    }

}

private extension ChannelSidebar {
    private var channelSectionHeader: some View {
        HStack {
            Text("CHANNELS (\(store.unmutedChannels.count))")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation {
                    groupFolders.toggle()
                }
            } label: {
                Image(systemName: groupFolders ? "folder.fill" : "list.bullet")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(groupFolders ? "Switch to flat list view" : "Switch to folder grouped view")

            Button {
                store.showChannelBrowser = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Browse & join channels (⇧⌘L)")
        }
        .padding(.top, 4)
    }

    private func navigationRow(
        title: String,
        icon: String,
        iconColor: Color,
        tag: SidebarSource,
        unread: Int,
        isMention: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: settings.uiSecondarySize))
                .foregroundStyle(iconColor)
                .frame(width: 18)

            Text(title)
                .font(.system(size: settings.uiFontSize, weight: unread > 0 ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            if unread > 0 {
                countBadge(unread, isMention: isMention)
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture {
            switch tag {
            case .recentTopics: store.selectRecentTopics()
            case .allMessages: store.selectAllMessages()
            case .mentions: store.selectMentions()
            case .starred: store.selectStarred()
            case .directMessages: store.selectDMs()
            case .channel(let id): store.selectChannel(id)
            }
            store.focusTopicListTrigger += 1
        }
        .tag(tag)
    }

    private func channelRow(channel: Channel, unread: Int, displayName: String? = nil, isNested: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text("#")
                .font(.system(size: settings.uiFontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: channel.color))
                .frame(width: 14)

            Text(displayName ?? channel.name)
                .font(.system(size: settings.uiFontSize, weight: unread > 0 ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(channel.isMuted ? Color.secondary.opacity(0.65) : Color.primary)

            if channel.inviteOnly {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            if channel.pinToTop {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if unread > 0 {
                countBadge(unread)
            }
        }
        .padding(.vertical, 1)
        .contextMenu {
            Button("Mark channel as read") {
                Task { await store.markChannelRead(streamID: channel.streamID) }
            }
            Divider()
            Button(channel.isMuted ? "Unmute channel" : "Mute channel") {
                Task {
                    try? await store.clientUpdateSubscription(streamID: channel.streamID, isMuted: !channel.isMuted)
                }
            }
            Button(channel.pinToTop ? "Unpin channel" : "Pin to top") {
                Task {
                    try? await store.clientUpdateSubscription(streamID: channel.streamID, pinToTop: !channel.pinToTop)
                }
            }
        }
    }

    private var selection: Binding<SidebarSource?> {
        Binding(
            get: { store.selectedSource },
            set: { source in
                guard let source else { return }
                switch source {
                case .recentTopics: store.selectRecentTopics()
                case .allMessages: store.selectAllMessages()
                case .mentions: store.selectMentions()
                case .starred: store.selectStarred()
                case .directMessages: store.selectDMs()
                case .channel(let id): store.selectChannel(id)
                }
            }
        )
    }

    @ViewBuilder
    private func countBadge(_ value: Int, isMention: Bool = false) -> some View {
        if value > 0 {
            Text("\(value)")
                .font(.system(size: 10.5, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isMention ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.18),
                    in: Capsule()
                )
                .foregroundStyle(isMention ? Color.orange : Color.accentColor)
                .monospacedDigit()
        }
    }
}

