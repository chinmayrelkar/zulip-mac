import AppKit
import SwiftUI
import ZulipCore

enum FocusedColumn: String {
    case sidebar, topics, composer
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
                VisualEffectBackground(material: .underWindowBackground)
                Color(nsColor: .windowBackgroundColor)
                    .opacity(1 - settings.translucency)
            }
        )
        .onAppear { makeWindowTranslucent() }
    }

    private func makeWindowTranslucent() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
    }

    private var workspace: some View {
        HStack(spacing: 0) {
            if store.showLeftPane {
                ChannelSidebar(store: store)
                    .frame(width: 255)
                Divider()
            }
            if store.showCenterPane {
                TopicSidebar(store: store)
                    .frame(width: 280)
                Divider()
            }
            MessageColumn(store: store)
                .frame(maxWidth: .infinity)
        }
        .environment(\.focusedColumn, $focusedColumn)
        .toolbar { toolbar }
        .focusable()
        .onKeyPress(keys: ["f"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.focusSearchTrigger += 1
            return .handled
        }
        .onKeyPress(keys: ["k"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.showQuickSwitcher = true
            return .handled
        }
        .onKeyPress(keys: ["/"]) { press in
            guard !press.modifiers.contains(.command) else { return .ignored }
            store.focusSearchTrigger += 1
            return .handled
        }
        .onKeyPress(keys: ["n"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.showNewDMModal = true
            return .handled
        }
        .onKeyPress(keys: ["1"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.selectRecentTopics()
            return .handled
        }
        .onKeyPress(keys: ["2"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.selectAllMessages()
            return .handled
        }
        .onKeyPress(keys: ["3"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.selectMentions()
            return .handled
        }
        .onKeyPress(keys: ["4"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.selectStarred()
            return .handled
        }
        .onKeyPress(keys: ["w"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            store.closeActiveTab()
            return .handled
        }
        .onKeyPress(keys: [.tab]) { press in
            guard press.modifiers.contains(.control) else { return .ignored }
            store.cycleTab(press.modifiers.contains(.shift) ? -1 : 1)
            return .handled
        }
        .onKeyPress(keys: [.tab]) { press in
            guard !press.modifiers.contains(.command), !press.modifiers.contains(.control) else { return .ignored }
            let order: [FocusedColumn] = [.sidebar, .topics, .composer].filter { column in
                switch column {
                case .sidebar: return store.showLeftPane
                case .topics: return store.showCenterPane
                case .composer: return true
                }
            }
            guard !order.isEmpty else { return .handled }
            let current = focusedColumn
            let idx = order.firstIndex(of: current) ?? 0
            let next = press.modifiers.contains(.shift)
                ? order[(idx - 1 + order.count) % order.count]
                : order[(idx + 1) % order.count]
            focusedColumn = next
            return .handled
        }
        .onKeyPress(.escape) {
            if searchFocused {
                searchFocused = false
                return .handled
            }
            if store.showQuickSwitcher {
                store.showQuickSwitcher = false
                return .handled
            }
            if store.lightbox != nil {
                store.lightbox = nil
                return .handled
            }
            if focusedColumn != .sidebar {
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
            Button {
                store.showQuickSwitcher = true
            } label: {
                Label("Quick Switcher", systemImage: "command")
            }
            .help("Jump to conversation (⌘K)")
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
            .help(store.status ?? "Reconnect")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                if let me = store.user(store.selfUserID) {
                    store.selectedUserForProfile = me
                }
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text(store.selfEmail)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help("Signed in as \(store.selfEmail)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button("Log out", action: store.logout)
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
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
