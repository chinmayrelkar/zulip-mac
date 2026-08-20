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
    public init() {}

    private static let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "General", rows: [
            ShortcutRow(keys: ["⌘", "P"], action: "Quick Open — jump to channel, topic, or person"),
            ShortcutRow(keys: ["⇧", "⌘", "P"], action: "Command Palette"),
            ShortcutRow(keys: ["⌘", "N"], action: "New Direct Message"),
            ShortcutRow(keys: ["⇧", "⌘", "L"], action: "Browse Channels"),
            ShortcutRow(keys: ["⌘", "W"], action: "Close Tab"),
        ]),
        ShortcutGroup(title: "Navigate", rows: [
            ShortcutRow(keys: ["⌘", "F"], action: "Search Messages"),
            ShortcutRow(keys: ["⌘", "1-9"], action: "Select open tab by number"),
            ShortcutRow(keys: ["⌥", "1-9"], action: "Select sidebar item by number"),
            ShortcutRow(keys: ["Tab"], action: "Cycle focus: sidebar → topics → composer"),
            ShortcutRow(keys: ["↑", "↓"], action: "Move selection in focused list"),
            ShortcutRow(keys: ["↵"], action: "Open selected topic / DM"),
            ShortcutRow(keys: ["⌃", "Tab"], action: "Next Tab"),
            ShortcutRow(keys: ["⌃", "⇧", "Tab"], action: "Previous Tab"),
        ]),
        ShortcutGroup(title: "App", rows: [
            ShortcutRow(keys: ["⌘", "R"], action: "Reload & Sync"),
            ShortcutRow(keys: ["⌘", ","], action: "Settings"),
        ]),
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Pick a conversation from the sidebar to get started — or use these shortcuts.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 2)

                ForEach(Self.groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

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
                                    .frame(width: 110, alignment: .leading)

                                    Text(row.action)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)

                                if index < group.rows.count - 1 {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
