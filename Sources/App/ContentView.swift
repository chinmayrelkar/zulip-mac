import AppKit
import SwiftUI
import ZulipCore

enum FocusedColumn: String {
    case sidebar, topics, messages, composer
}

struct FocusedColumnKey: EnvironmentKey {
    static let defaultValue = Binding<FocusedColumn>.constant(.sidebar)
}

extension EnvironmentValues {
    var focusedColumn: Binding<FocusedColumn> {
        get { self[FocusedColumnKey.self] }
        set { self[FocusedColumnKey.self] = newValue }
    }
}

struct ContentView: View {
    @Bindable var store: Store
    @Environment(AppSettings.self) private var settings
    @AppStorage("sidebar_channel_width") private var channelWidth: Double = 250
    @AppStorage("sidebar_topic_width") private var topicWidth: Double = 280
    @State private var searchDraft = ""
    @State private var focusedColumn: FocusedColumn = .sidebar
    @FocusState private var searchFocused: Bool

    init(store: Store = Store()) {
        self.store = store
    }

    var body: some View {
        Group {
            switch store.session {
            case .loggedOut:
                LoginView(store: store)
            case .connecting:
                ProgressView("Connecting…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                workspace
                    .overlay {
                        if let item = store.lightbox {
                            LightboxView(item: item, loader: store.media, onClose: { store.lightbox = nil })
                        }
                    }
                    .overlay {
                        if store.showShortcutHelp {
                            ZStack {
                                Color.black.opacity(0.4)
                                    .ignoresSafeArea()
                                    .onTapGesture { store.showShortcutHelp = false }
                                ShortcutHelpView(onClose: { store.showShortcutHelp = false })
                            }
                            .onExitCommand { store.showShortcutHelp = false }
                        }
                        if store.showQuickSwitcher {
                            ZStack {
                                Color.black.opacity(0.4)
                                    .ignoresSafeArea()
                                    .onTapGesture { store.showQuickSwitcher = false }
                                QuickSwitcherView(store: store)
                            }
                            .onExitCommand { store.showQuickSwitcher = false }
                        }
                        if store.showCommandPalette {
                            ZStack {
                                Color.black.opacity(0.4)
                                    .ignoresSafeArea()
                                    .onTapGesture { store.showCommandPalette = false }
                                CommandPaletteView(store: store)
                            }
                            .onExitCommand { store.showCommandPalette = false }
                        }
                    }
                    .sheet(isPresented: $store.showNewDMModal) {
                        NewDMModal(store: store)
                    }
                    .sheet(isPresented: $store.showChannelBrowser) {
                        ChannelBrowserModal(store: store)
                    }
                    .sheet(item: $store.editingMessage) { msg in
                        MessageEditSheet(store: store, message: msg)
                    }
                    .sheet(item: $store.viewingHistoryForMessage) { msg in
                        MessageHistorySheet(store: store, message: msg)
                    }
                    .popover(item: $store.selectedUserForProfile) { user in
                        UserProfilePopover(
                            user: user,
                            presence: store.presences[user.userID],
                            status: store.userStatuses[user.userID],
                            site: store.site,
                            loader: store.media
                        ) {
                            store.selectedUserForProfile = nil
                            store.openDM(with: [user.userID])
                            store.focusComposerTrigger += 1
                        }
                    }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task { await store.start() }
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
        .background(
            ZStack {
                if settings.translucency > 0 {
                    VisualEffectBackground(material: .underWindowBackground)
                }
                Color(nsColor: .windowBackgroundColor)
                    .opacity(settings.translucency > 0 ? (1 - settings.translucency) : 1.0)
            }
            .ignoresSafeArea()
        )
        .onAppear { updateWindowTranslucency() }
        .onChange(of: settings.translucency) { _, _ in updateWindowTranslucency() }
    }

    private func updateWindowTranslucency() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else { return }
        if settings.translucency > 0 {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.titlebarAppearsTransparent = false
        }
    }

    private var workspace: some View {
        HStack(spacing: 0) {
            if store.showLeftPane {
                ChannelSidebar(store: store)
                    .frame(width: CGFloat(channelWidth))
                ResizeHandle(width: $channelWidth, minWidth: 190, maxWidth: 380)
            }
            if store.showCenterPane {
                TopicSidebar(store: store)
                    .frame(width: CGFloat(topicWidth))
                ResizeHandle(width: $topicWidth, minWidth: 220, maxWidth: 460)
            }
            MessageColumn(store: store)
                .frame(maxWidth: .infinity)
        }
        .environment(\.focusedColumn, $focusedColumn)
        .background {
            // ⌘K is an alias for Quick Open (⌘P); kept out of the File menu so it isn't listed twice.
            Button("") { store.showQuickSwitcher.toggle() }
                .keyboardShortcut("k", modifiers: [.command])
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .toolbar { toolbar }
        .onKeyPress(.escape) {
            if searchFocused {
                searchFocused = false
                return .handled
            }
            if store.showShortcutHelp {
                store.showShortcutHelp = false
                return .handled
            }
            if store.showQuickSwitcher {
                store.showQuickSwitcher = false
                return .handled
            }
            if store.showCommandPalette {
                store.showCommandPalette = false
                return .handled
            }
            if store.lightbox != nil {
                store.lightbox = nil
                return .handled
            }
            if focusedColumn == .composer {
                focusedColumn = .messages
                store.focusMessagesTrigger += 1
                return .handled
            }
            if focusedColumn == .messages {
                if store.showCenterPane && store.hasTopicsForSelectedSource {
                    focusedColumn = .topics
                    store.focusTopicListTrigger += 1
                    return .handled
                } else {
                    focusedColumn = .sidebar
                    return .handled
                }
            }
            if focusedColumn == .topics {
                focusedColumn = .sidebar
                return .handled
            }
            return .ignored
        }
        .onChange(of: store.focusSearchTrigger) { _, _ in
            searchFocused = true
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 3) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.toggleLeftPane()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .foregroundStyle(store.showLeftPane ? Color.accentColor : Color.secondary)
                }
                .help(store.showLeftPane ? "Hide channels (⌘B)" : "Show channels (⌘B)")

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.toggleCenterPane()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .foregroundStyle(store.showCenterPane ? Color.accentColor : Color.secondary)
                }
                .help(store.showCenterPane ? "Hide topics (⇧⌘B)" : "Show topics (⇧⌘B)")
            }
        }

        ToolbarItem(placement: .navigation) {
            Button {
                store.showQuickSwitcher = true
            } label: {
                Label("Quick Switcher", systemImage: "command")
            }
            .help("Jump to conversation (⌘K or ⌘P)")
        }

        ToolbarItem(placement: .principal) {
            GlobalSearchBarView(store: store, query: $searchDraft)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await store.start() }
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .disabled(store.isBusy)
            .help(store.status ?? "Reload & sync (⌘R)")
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let me = store.user(store.selfUserID) {
                    Text(me.fullName)
                        .font(.headline)
                    Text(store.selfEmail)
                        .font(.caption)
                    Divider()
                    Button("View Profile") {
                        store.selectedUserForProfile = me
                    }
                }
                SettingsLink {
                    Text("Preferences…")
                }
                Divider()
                Button("Log Out", role: .destructive) {
                    store.logout()
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(store.selfEmail)
                        .font(.system(size: settings.uiSecondarySize))
                        .foregroundStyle(.secondary)
                }
            }
            .help("Account: \(store.selfEmail)")
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
    }
}

struct ResizeHandle: View {
    @Binding var width: Double
    var minWidth: Double
    var maxWidth: Double
    @State private var initialWidth: Double?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
            Rectangle()
                .fill(Color.clear)
                .frame(width: 8)
                .contentShape(Rectangle())
        }
        .frame(width: 8)
        .onContinuousHover { phase in
            if case .active = phase {
                NSCursor.resizeLeftRight.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .onDisappear {
            NSCursor.arrow.set()
        }
        .gesture(
            // Global space: the handle moves with the width, so local translation would feed back on itself.
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if initialWidth == nil {
                        initialWidth = width
                    }
                    if let start = initialWidth {
                        let target = start + Double(value.translation.width)
                        width = min(max(target, minWidth), maxWidth)
                    }
                }
                .onEnded { _ in
                    initialWidth = nil
                }
        )
    }
}

struct LoginView: View {
    @Bindable var store: Store
    @State private var site = Auth.defaultSite.absoluteString
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zulip")
                .font(.largeTitle.weight(.semibold))
            Text("Sign in with your Clarisights Zulip email and password.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420, alignment: .leading)
            TextField("Site", text: $site)
            TextField("Email", text: $email)
                .textContentType(.username)
            SecureField("Password", text: $password)
                .textContentType(.password)
            Button("Sign in") {
                Task { await store.login(site: site, email: email, password: password) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(email.isEmpty || password.isEmpty)
        }
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 420)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else {
            self = .secondary
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension RecentDM {
    var key: String { userIDs.sorted().map(String.init).joined(separator: ",") }
}
