import AppKit
import SwiftUI

public enum PaletteCommand: String, CaseIterable, Identifiable {
    case quickOpen = "Quick Open"
    case newDM = "New Direct Message"
    case browseChannels = "Browse Channels"
    case closeTab = "Close Tab"
    case searchMessages = "Search Messages"
    case recentConversations = "Recent Conversations"
    case allMessages = "All Messages"
    case mentions = "Mentions"
    case starred = "Starred Messages"
    case nextTab = "Next Tab"
    case previousTab = "Previous Tab"
    case reload = "Reload & Sync"
    case settings = "Settings"

    public var id: String { rawValue }

    var keyHint: String {
        switch self {
        case .quickOpen: "⌘P"
        case .newDM: "⌘N"
        case .browseChannels: "⇧⌘L"
        case .closeTab: "⌘W"
        case .searchMessages: "⌘F"
        case .recentConversations: "⌘1"
        case .allMessages: "⌘2"
        case .mentions: "⌘3"
        case .starred: "⌘4"
        case .nextTab: "⌃Tab"
        case .previousTab: "⌃⇧Tab"
        case .reload: "⌘R"
        case .settings: "⌘,"
        }
    }

    var group: String {
        switch self {
        case .quickOpen, .newDM, .browseChannels, .closeTab: "File"
        case .searchMessages, .recentConversations, .allMessages, .mentions, .starred, .nextTab, .previousTab: "Navigate"
        case .reload, .settings: "Preferences"
        }
    }

    @MainActor
    func run(_ store: Store) {
        store.showCommandPalette = false
        switch self {
        case .quickOpen:
            store.showQuickSwitcher = true
        case .newDM:
            store.showNewDMModal = true
        case .browseChannels:
            store.showChannelBrowser = true
        case .closeTab:
            store.closeActiveTab()
        case .searchMessages:
            store.focusSearchTrigger += 1
        case .recentConversations:
            store.selectRecentTopics()
        case .allMessages:
            store.selectAllMessages()
        case .mentions:
            store.selectMentions()
        case .starred:
            store.selectStarred()
        case .nextTab:
            store.cycleTab(1)
        case .previousTab:
            store.cycleTab(-1)
        case .reload:
            Task { await store.start() }
        case .settings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}

public struct CommandPaletteView: View {
    @Bindable var store: Store
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    public init(store: Store) {
        self.store = store
    }

    private var filteredCommands: [PaletteCommand] {
        let all = PaletteCommand.allCases
        guard !query.isEmpty else { return all }
        let term = query.lowercased()
        return all.filter {
            $0.rawValue.lowercased().contains(term)
                || $0.group.lowercased().contains(term)
                || $0.keyHint.lowercased().contains(term)
        }
    }

    private var groupedCommands: [(group: String, commands: [PaletteCommand])] {
        let items = filteredCommands
        let byGroup = Dictionary(grouping: items, by: \.group)
        var result: [(group: String, commands: [PaletteCommand])] = []
        for group in ["File", "Navigate", "Preferences"] {
            if let commands = byGroup[group], !commands.isEmpty {
                result.append((group, commands))
            }
        }
        for (group, commands) in byGroup where !result.contains(where: { $0.group == group }) {
            result.append((group, commands))
        }
        return result
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 10) {
                Image(systemName: "command")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)

                TextField("Type a command…", text: $query)
                    .font(.system(size: 14))
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        activateCurrentSelection()
                    }
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                    .onKeyPress(.downArrow) {
                        let total = filteredCommands.count
                        if total > 0 {
                            selectedIndex = min(selectedIndex + 1, total - 1)
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        store.showCommandPalette = false
                        return .handled
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    store.showCommandPalette = false
                } label: {
                    Text("esc")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(.regularMaterial)

            Divider().opacity(0.6)

            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if filteredCommands.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "command")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .padding(.top, 24)
                                Text("No commands found for \"\(query)\"")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("Try searching for an action, like “new”, “mention”, or “reload”")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                    .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(groupedCommands, id: \.group) { section in
                                Text(section.group.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 8)
                                    .padding(.bottom, 2)

                                ForEach(Array(section.commands.enumerated()), id: \.element.id) { _, command in
                                    commandRow(command)
                                        .id(command.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 320)
                .onChange(of: selectedIndex) { _, idx in
                    if idx >= 0 && idx < filteredCommands.count {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(filteredCommands[idx].id, anchor: .center)
                        }
                    }
                }
            }

            Divider().opacity(0.6)

            // Footer Shortcuts
            HStack(spacing: 12) {
                shortcutHint("↑↓", "Navigate")
                shortcutHint("↵", "Run")
                shortcutHint("esc", "Close")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        }
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .onAppear {
            selectedIndex = 0
            isFocused = true
        }
        .onExitCommand { store.showCommandPalette = false }
    }

    private func activateCurrentSelection() {
        guard selectedIndex >= 0 && selectedIndex < filteredCommands.count else { return }
        filteredCommands[selectedIndex].run(store)
    }

    private func commandRow(_ command: PaletteCommand) -> some View {
        let isSelected = selectedIndex < filteredCommands.count
            && filteredCommands[selectedIndex].id == command.id
        return Button {
            command.run(store)
        } label: {
            HStack(spacing: 10) {
                Text(command.rawValue)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(command.keyHint)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shortcutHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
