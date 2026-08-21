import SwiftUI

private struct ShortcutGroup: Identifiable {
    var id: String { title }
    let title: String
    let rows: [ShortcutRow]
}

private struct ShortcutRow: Identifiable {
    var id: String { action }
    let keys: [String]
    let action: String
}

public struct ShortcutHelpView: View {
    public var embedded: Bool = false
    public var onClose: (() -> Void)? = nil

    public init(embedded: Bool = false, onClose: (() -> Void)? = nil) {
        self.embedded = embedded
        self.onClose = onClose
    }

    private static let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Navigation & Panes", rows: [
            ShortcutRow(keys: ["↑", "↓"], action: "Move selection in focused pane / message list"),
            ShortcutRow(keys: ["j", "k"], action: "Next / previous item or message (vim-style)"),
            ShortcutRow(keys: ["↵"], action: "Open selected topic or quote message"),
            ShortcutRow(keys: ["←", "→"], action: "Navigate between panes (Sidebar ↔ Topics ↔ Messages)"),
            ShortcutRow(keys: ["Esc"], action: "Back to previous pane / dismiss overlay"),
            ShortcutRow(keys: ["⌘", "1-9"], action: "Select open tab by number"),
            ShortcutRow(keys: ["⌥", "1-9"], action: "Select sidebar item by number"),
            ShortcutRow(keys: ["⌃", "Tab"], action: "Next tab"),
            ShortcutRow(keys: ["⌃", "⇧", "Tab"], action: "Previous tab"),
            ShortcutRow(keys: ["⌘", "B"], action: "Toggle Left Pane (Channels & Feeds)"),
            ShortcutRow(keys: ["⇧", "⌘", "B"], action: "Toggle Center Pane (Topics & DMs)"),
        ]),
        ShortcutGroup(title: "Messages & Conversations", rows: [
            ShortcutRow(keys: ["r", "↵"], action: "Quote and reply to selected message"),
            ShortcutRow(keys: ["i", "a"], action: "Focus composer to write message"),
            ShortcutRow(keys: ["+", ":"], action: "Add emoji reaction to selected message"),
            ShortcutRow(keys: ["1-5"], action: "Quick react (👍, ❤️, 😂, 🚀, 💡)"),
            ShortcutRow(keys: ["s"], action: "Star / unstar selected message"),
            ShortcutRow(keys: ["e"], action: "Edit selected message (if sent by you)"),
            ShortcutRow(keys: ["d", "⌫"], action: "Delete selected message (if sent by you)"),
            ShortcutRow(keys: ["c", "⌘C"], action: "Copy message plain text"),
            ShortcutRow(keys: ["l"], action: "Copy link to message"),
            ShortcutRow(keys: ["Space"], action: "Open media / image in lightbox"),
            ShortcutRow(keys: ["h"], action: "View edit history"),
            ShortcutRow(keys: ["v", "g"], action: "Go to message topic (in stream feeds)"),
            ShortcutRow(keys: ["m"], action: "Mute / unmute topic"),
        ]),
        ShortcutGroup(title: "Composer", rows: [
            ShortcutRow(keys: ["↵", "⌘↵"], action: "Send message"),
            ShortcutRow(keys: ["⇧↵"], action: "Insert new line"),
            ShortcutRow(keys: ["↑"], action: "Focus messages / edit last sent message (when empty)"),
            ShortcutRow(keys: ["⌘", "B"], action: "Format bold (**text**)"),
            ShortcutRow(keys: ["⌘", "I"], action: "Format italic (*text*)"),
            ShortcutRow(keys: ["⌘", "E"], action: "Toggle Markdown live preview"),
            ShortcutRow(keys: ["Esc"], action: "Focus message list"),
        ]),
        ShortcutGroup(title: "Quick Actions & Modals", rows: [
            ShortcutRow(keys: ["⌘", "P", "/", "⌘K"], action: "Quick Open — jump to channel, topic, or person"),
            ShortcutRow(keys: ["⇧", "⌘", "P"], action: "Command Palette"),
            ShortcutRow(keys: ["⌘", "F", "/", "/"], action: "Search messages"),
            ShortcutRow(keys: ["⌘", "N"], action: "New Direct Message"),
            ShortcutRow(keys: ["⇧", "⌘", "L"], action: "Browse Channels (Space to join/leave)"),
            ShortcutRow(keys: ["⌘", "/"], action: "Keyboard Shortcuts Help"),
            ShortcutRow(keys: ["⌘", "W"], action: "Close active tab"),
            ShortcutRow(keys: ["⌘", "R"], action: "Reload & Sync"),
            ShortcutRow(keys: ["⌘", ","], action: "Settings"),
        ]),
    ]

    public var body: some View {
        if embedded {
            embeddedContent
        } else {
            modalContent
        }
    }

    private var embeddedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 18, weight: .bold))
                    Text("Pick a conversation from the sidebar to get started — or use these shortcuts.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)

                shortcutList
            }
            .padding(24)
            .frame(maxWidth: 580, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var modalContent: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 16, weight: .bold))
                    Text("Complete keyboard navigation guide for ZulipMac.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.5)

            ScrollView {
                shortcutList
                    .padding(20)
            }
            .frame(maxHeight: 520)

            Divider().opacity(0.5)

            HStack {
                Text("Press esc to close")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onClose {
                    Button("Done", action: onClose)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        }
        .frame(width: 580)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }

    private var shortcutList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Self.groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.title.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                            HStack(spacing: 12) {
                                HStack(spacing: 3) {
                                    ForEach(row.keys, id: \.self) { key in
                                        Text(key)
                                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                                .frame(minWidth: 90, alignment: .leading)

                                Text(row.action)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)

                            if index < group.rows.count - 1 {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    )
                }
            }
        }
    }
}
