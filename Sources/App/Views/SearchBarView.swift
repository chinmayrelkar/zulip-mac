import AppKit
import SwiftUI
import ZulipCore

public struct GlobalSearchBarView: View {
    @Bindable var store: Store
    @Binding var query: String
    @State private var isFieldFocused = false
    @State private var showSuggestions = false

    public init(store: Store, query: Binding<String>, isFocused: FocusState<Bool>.Binding? = nil) {
        self.store = store
        self._query = query
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFieldFocused ? Color.accentColor : Color.secondary)

            NativeSearchTextField(
                text: $query,
                placeholder: "Search messages, channels, people…",
                focusTrigger: store.focusSearchTrigger,
                isFocused: $isFieldFocused,
                onCommit: {
                    showSuggestions = false
                    store.submitSearch(query)
                },
                onCancel: {
                    showSuggestions = false
                },
                onTextChange: { _ in
                    if isFieldFocused && !showSuggestions {
                        showSuggestions = true
                    }
                }
            )
            .frame(height: 20)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    showSuggestions = false
                    store.submitSearch(query)
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Search")
            } else {
                Text("⌘F")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 3.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4.5)
        .frame(minWidth: 260, idealWidth: 320, maxWidth: 440)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isFieldFocused ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: isFieldFocused ? 1.2 : 0.5)
        )
        .onChange(of: store.focusSearchTrigger) { _, _ in
            showSuggestions = true
        }
        .popover(isPresented: $showSuggestions, arrowEdge: .bottom) {
            searchSuggestionsPopover
        }
    }

    private var searchSuggestionsPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick Filter Chips Header
            VStack(alignment: .leading, spacing: 6) {
                Text("SEARCH OPERATORS")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        filterChip("channel:", hint: "filter by channel", icon: "number")
                        filterChip("topic:", hint: "filter by topic", icon: "bubble.left")
                        filterChip("sender:me", hint: "sent by you", icon: "person")
                        filterChip("is:mentioned", hint: "mentions you", icon: "at")
                        filterChip("is:starred", hint: "starred messages", icon: "star.fill")
                        filterChip("is:unread", hint: "unread messages", icon: "envelope.badge")
                        filterChip("has:attachment", hint: "with files", icon: "paperclip")
                        filterChip("has:image", hint: "with images", icon: "photo")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider().opacity(0.4)

            // Autocomplete Results
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if !matchingChannels.isEmpty {
                        suggestionSectionHeader("CHANNELS")
                        ForEach(matchingChannels.prefix(4)) { channel in
                            Button {
                                appendToken("channel:\"\(channel.name)\" ")
                            } label: {
                                HStack(spacing: 6) {
                                    Text("#")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color(hex: channel.color))
                                    Text(channel.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text("channel")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !matchingUsers.isEmpty {
                        suggestionSectionHeader("PEOPLE")
                        ForEach(matchingUsers.prefix(4)) { user in
                            Button {
                                appendToken("sender:\"\(user.email)\" ")
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.accentColor)
                                    Text(user.fullName)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(user.email)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("sender")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    suggestionSectionHeader("SEARCH IN MESSAGES")
                    Button {
                        showSuggestions = false
                        store.submitSearch(query)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.accentColor)
                            Text("Search messages for \"\(query.isEmpty ? "..." : query)\"")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("Return ↵")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 220)
        }
        .frame(width: 380)
    }

    private func filterChip(_ text: String, hint: String, icon: String) -> some View {
        Button {
            appendToken(text + " ")
        } label: {
            HStack(spacing: 3.5) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(text)
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4.5))
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(.plain)
        .help(hint)
    }

    private func suggestionSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }

    private func appendToken(_ token: String) {
        if query.isEmpty {
            query = token
        } else if query.hasSuffix(" ") {
            query += token
        } else {
            query += " " + token
        }
        store.focusSearchTrigger += 1
    }

    private var matchingChannels: [Channel] {
        guard !query.isEmpty else { return Array(store.channels.prefix(5)) }
        let term = query.lowercased()
        return store.channels.filter { $0.name.lowercased().contains(term) }
    }

    private var matchingUsers: [User] {
        guard !query.isEmpty else { return [] }
        let term = query.lowercased()
        return Array(store.users.values).filter {
            $0.fullName.lowercased().contains(term) || $0.email.lowercased().contains(term)
        }
    }
}

// MARK: - Native Search Field with Guaranteed AppKit Focus

public struct NativeSearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusTrigger: Int
    @Binding var isFocused: Bool
    var onCommit: () -> Void
    var onCancel: () -> Void
    var onTextChange: ((String) -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        focusTrigger: Int,
        isFocused: Binding<Bool>,
        onCommit: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.focusTrigger = focusTrigger
        self._isFocused = isFocused
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.onTextChange = onTextChange
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> CustomFocusTextField {
        let tf = CustomFocusTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = NSFont.systemFont(ofSize: 12)
        tf.placeholderString = placeholder
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.onAction(_:))
        tf.onFocusChange = { focused in
            DispatchQueue.main.async {
                self.isFocused = focused
            }
        }
        tf.onEscape = {
            self.onCancel()
        }
        context.coordinator.textField = tf
        return tf
    }

    public func updateNSView(_ nsView: CustomFocusTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                    nsView.currentEditor()?.selectAll(nil)
                }
            }
            // Ensure focus is retained even when popover window appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }

    @MainActor
    public class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeSearchTextField
        var lastFocusTrigger: Int = 0
        weak var textField: CustomFocusTextField?

        init(_ parent: NativeSearchTextField) {
            self.parent = parent
            self.lastFocusTrigger = parent.focusTrigger
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
            parent.onTextChange?(tf.stringValue)
        }

        @objc func onAction(_ sender: Any?) {
            parent.onCommit()
        }
    }
}

public class CustomFocusTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?
    var onEscape: (() -> Void)?

    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            onFocusChange?(true)
        }
        return result
    }

    public override func cancelOperation(_ sender: Any?) {
        onEscape?()
        window?.makeFirstResponder(nil)
    }

    public override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        onFocusChange?(false)
    }
}
