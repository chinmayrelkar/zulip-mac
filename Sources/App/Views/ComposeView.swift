import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ZulipCore

public struct ComposeBar: View {
    @Bindable var store: Store
    let tab: ConversationTab
    @Environment(AppSettings.self) private var settings
    @Environment(\.focusedColumn) private var focusedColumn
    @State private var isDropTargeted = false
    @State private var isPreviewMode = false
    @State private var showEmojiPicker = false
    @FocusState private var isEditorFocused: Bool

    public init(store: Store, tab: ConversationTab) {
        self.store = store
        self.tab = tab
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Typing Indicator Bar
            let typingNames = getTypingUserNames()
            if !typingNames.isEmpty {
                HStack(spacing: 6) {
                    TypingDotsAnimation()
                    Text("\(typingNames.joined(separator: ", ")) \(typingNames.count == 1 ? "is" : "are") typing…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 3)
                .transition(.opacity)
            }

            // Composer Card Container
            VStack(spacing: 0) {
                // Editor or Live Preview Box
                if isPreviewMode {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if currentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Nothing to preview (write some Markdown…)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                            } else {
                                let html = MessageHTML.fromMarkdown(currentDraftText)
                                MessageBody(html: html, site: store.site, media: store.media)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 34, maxHeight: 120)
                } else {
                    TextField(placeholderText, text: draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: settings.fontSize))
                        .lineLimit(1...5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .focused($isEditorFocused)
                        .onSubmit {
                            Task { await store.send() }
                        }
                        .onKeyPress(.return) {
                            if NSEvent.modifierFlags.contains(.shift) {
                                return .ignored
                            } else {
                                Task { await store.send() }
                                return .handled
                            }
                        }
                }

                if showFormatting {
                    // Compact Bottom Toolbar & Actions
                    HStack(spacing: 4) {
                        if !isPreviewMode {
                            toolButton(icon: "bold", help: "Bold (**)") { insertFormatting(prefix: "**", suffix: "**") }
                            toolButton(icon: "italic", help: "Italic (*)") { insertFormatting(prefix: "*", suffix: "*") }
                            toolButton(icon: "strikethrough", help: "Strikethrough (~~)") { insertFormatting(prefix: "~~", suffix: "~~") }
                            toolButton(icon: "chevron.left.forwardslash.chevron.right", help: "Inline code (`)") { insertFormatting(prefix: "`", suffix: "`") }
                            toolButton(icon: "curlybraces", help: "Code block (```)") { insertFormatting(prefix: "```\n", suffix: "\n```") }
                            toolButton(icon: "link", help: "Link ([text](url))") { insertFormatting(prefix: "[", suffix: "](url)") }
                            toolButton(icon: "quote.opening", help: "Quote (> )") { insertFormatting(prefix: "> ", suffix: "") }
                            toolButton(icon: "list.bullet", help: "Bullet list (- )") { insertFormatting(prefix: "- ", suffix: "") }
    
                            Divider().frame(height: 12).padding(.horizontal, 2)
    
                            toolButton(icon: "paperclip", help: "Attach file or image") { selectAndUploadFile() }
    
                            Button {
                                showEmojiPicker.toggle()
                            } label: {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, height: 22)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Insert emoji")
                            .popover(isPresented: $showEmojiPicker, arrowEdge: .top) {
                                EmojiPickerPopover(store: store) { item in
                                    showEmojiPicker = false
                                    insertEmoji(item)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.accentColor)
                                Text("Live Markdown Preview")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        }
    
                        Spacer()
    
                        // Preview Toggle Button
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isPreviewMode.toggle()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: isPreviewMode ? "pencil" : "eye")
                                    .font(.system(size: 9))
                                Text(isPreviewMode ? "Write" : "Preview")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isPreviewMode ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(isPreviewMode ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Markdown live preview")
    
                        // Send Button
                        Button {
                            Task { await store.send() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(currentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary.opacity(0.4) : Color.white)
                                .frame(width: 22, height: 22)
                                .background(
                                    currentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? Color.secondary.opacity(0.15)
                                        : Color.accentColor,
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(currentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Send message (Return or ⌘↵)")
                        .keyboardShortcut(.return, modifiers: [.command])
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDropTargeted ? Color.accentColor : (isEditorFocused ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.2)),
                        lineWidth: isDropTargeted ? 2 : (isEditorFocused ? 1 : 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            .animation(.easeInOut(duration: 0.15), value: showFormatting)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
        }
        .background(focusWatcher)
        .onChange(of: focusedColumn.wrappedValue) { _, new in
            if new == .composer { requestFocus() }
        }
    }

    private var placeholderText: String {
        "Message \(store.tabTitle(tab))…"
    }

    private var currentDraftText: String {
        store.activeTab?.draft ?? tab.draft
    }

    private var showFormatting: Bool {
        isEditorFocused
            || !currentDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isPreviewMode
    }


    public func requestFocus() {
        isEditorFocused = true
    }

    public var focusWatcher: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: store.focusComposerTrigger) { _, _ in
                requestFocus()
            }
    }

    private var draft: Binding<String> {
        Binding(
            get: { store.activeTab?.draft ?? "" },
            set: { store.setDraft($0) }
        )
    }

    private func toolButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func insertFormatting(prefix: String, suffix: String) {
        let current = store.activeTab?.draft ?? ""
        store.setDraft(current + prefix + suffix)
    }

    private func insertEmoji(_ item: EmojiItem) {
        let current = store.activeTab?.draft ?? ""
        let insertion = item.isCustom ? ":\(item.name): " : "\(item.symbol) "
        store.setDraft(current + insertion)
    }

    private func selectAndUploadFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                Task {
                    await store.uploadAttachment(filename: url.lastPathComponent, data: data, mimeType: mime)
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                      let fileData = try? Data(contentsOf: url) else { return }
                let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
                Task { @MainActor in
                    await store.uploadAttachment(filename: url.lastPathComponent, data: fileData, mimeType: mime)
                }
            }
        }
        return true
    }

    private func getTypingUserNames() -> [String] {
        let key: String
        switch tab.narrow {
        case .topic(let streamID, _, let topic):
            key = "s-\(streamID):\(topic)"
        case .dm(let userIDs):
            key = "dm:" + userIDs.sorted().map(String.init).joined(separator: ",")
        default:
            return []
        }
        guard let userIDs = store.typingUsers[key] else { return [] }
        let others = userIDs.filter { $0 != store.selfUserID }
        return others.compactMap { store.user($0)?.fullName }
    }
}

private struct TypingDotsAnimation: View {
    @State private var dotOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.7))
                    .frame(width: 4, height: 4)
                    .offset(y: dotOffset(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                dotOffset = -3
            }
        }
    }

    private func dotOffset(for index: Int) -> CGFloat {
        dotOffset
    }
}
