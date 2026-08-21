import AppKit
import SwiftUI
import ZulipCore

struct ChannelBrowserRowView: View {
    let channel: Channel
    let isSubscribed: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(spacing: 10) {
                Text("#")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: channel.color))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(channel.name)
                            .font(.system(size: 13, weight: .semibold))

                        if channel.inviteOnly {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !channel.description.isEmpty {
                        Text(channel.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onOpen()
                } label: {
                    Text("Open")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                if isSubscribed {
                    Button(action: onToggle) {
                        Text("Joined")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button(action: onToggle) {
                        Text("Join")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            onSelect()
        })
    }
}

public struct EmojiPickerPopover: View {
    @Bindable var store: Store
    public var onSelect: (EmojiItem) -> Void
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    public init(store: Store, onSelect: @escaping (EmojiItem) -> Void) {
        self.store = store
        self.onSelect = onSelect
    }

    private var allCustomEmojis: [EmojiItem] {
        store.realmEmojis.values.filter { !$0.deactivated }.map { custom in
            EmojiItem(
                name: custom.name,
                code: custom.name,
                symbol: ":\(custom.name):",
                category: "Custom",
                isCustom: true,
                customURL: custom.sourceURL
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredItems: [EmojiItem] {
        let all = allCustomEmojis + EmojiProvider.standardEmojiItems
        if query.isEmpty {
            return all
        }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) }
    }

    private var categorizedGroups: [(category: String, items: [EmojiItem])] {
        let items = filteredItems
        let grouped = Dictionary(grouping: items, by: \.category)
        var result: [(category: String, items: [EmojiItem])] = []
        if let custom = grouped["Custom"], !custom.isEmpty {
            result.append(("Organization (\(store.realmName))", custom))
        }
        for cat in ["Smileys", "People", "Objects"] {
            if let group = grouped[cat], !group.isEmpty {
                result.append((cat, group))
            }
        }
        return result
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search emojis…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                    .onChange(of: query) { _, _ in
                        selectedIndex = 0
                    }
                    .onKeyPress(.rightArrow) {
                        let total = filteredItems.count
                        if total > 0 { selectedIndex = min(selectedIndex + 1, total - 1) }
                        return .handled
                    }
                    .onKeyPress(.leftArrow) {
                        selectedIndex = max(selectedIndex - 1, 0)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        let total = filteredItems.count
                        if total > 0 { selectedIndex = min(selectedIndex + 7, total - 1) }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        selectedIndex = max(selectedIndex - 7, 0)
                        return .handled
                    }
                    .onSubmit {
                        if filteredItems.indices.contains(selectedIndex) {
                            onSelect(filteredItems[selectedIndex])
                        }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            .padding(8)

            Divider().opacity(0.5)

            // Grid of Emojis
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if categorizedGroups.isEmpty {
                            Text("No emojis found")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(categorizedGroups, id: \.category) { section in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(section.category.uppercased())
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 4)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 4)], spacing: 4) {
                                        ForEach(section.items) { item in
                                            let isEmojiSelected = filteredItems.indices.contains(selectedIndex) && filteredItems[selectedIndex].id == item.id

                                            Button {
                                                onSelect(item)
                                            } label: {
                                                if item.isCustom {
                                                    EmojiImageView(rawURL: item.customURL ?? "", site: store.site, loader: store.media, size: 22, fallback: String(item.name.prefix(1)))
                                                        .padding(3)
                                                } else {
                                                    Text(item.symbol)
                                                        .font(.system(size: 18))
                                                        .frame(width: 26, height: 26)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .background(isEmojiSelected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(isEmojiSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                            )
                                            .id(item.id)
                                            .help(":\(item.name):")
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(width: 280, height: 260)
                .onChange(of: selectedIndex) { _, idx in
                    if filteredItems.indices.contains(idx) {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(filteredItems[idx].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}
