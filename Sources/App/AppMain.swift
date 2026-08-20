import SwiftUI
import ZulipCore

@main
struct ZulipMacApp: App {
    @State private var store = Store()
    @State private var settings = AppSettings()

    init() {
        if CommandLine.arguments.contains("--dump") {
            Self.dumpAndExit()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .defaultSize(width: 1280, height: 800)
        .environment(settings)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Quick Open…") {
                    store.showQuickSwitcher.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command])

                Button("Command Palette…") {
                    store.showCommandPalette.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("New Direct Message…") {
                    store.showNewDMModal = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Browse Channels…") {
                    store.showChannelBrowser = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Divider()

                Button("Close Tab") {
                    store.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: [.command])
            }

            CommandMenu("Find") {
                Button("Search Messages…") {
                    store.focusSearchTrigger += 1
                }
                .keyboardShortcut("f", modifiers: [.command])
            }

            CommandMenu("Navigate") {
                ForEach(0..<9, id: \.self) { index in
                    Button("Tab \(index + 1)") {
                        store.selectTab(at: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
                }

                Divider()

                ForEach(0..<9, id: \.self) { index in
                    let title = store.sidebarItemTitle(at: index)
                    if !title.isEmpty {
                        Button(title) {
                            store.selectSidebarItem(at: index)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.option])
                    }
                }

                Divider()

                Button("Next Tab") {
                    store.cycleTab(1)
                }
                .keyboardShortcut(.tab, modifiers: [.control])

                Button("Previous Tab") {
                    store.cycleTab(-1)
                }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])
            }

            CommandMenu("View") {
                Button("Toggle Left Pane") {
                    store.toggleLeftPane()
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Toggle Center Pane") {
                    store.toggleCenterPane()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button("Reload & Sync") {
                    Task { await store.start() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(settings)
        }
    }

    private static func dumpAndExit() -> Never {
        guard let credentials = Auth.loadIncludingEnvironment() else {
            fputs("no credentials (set ZULIP_REST_API__CREDENTIALS or log in once)\n", stderr)
            exit(1)
        }
        let client = ZulipClient(credentials: credentials)
        let sema = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failed: String?
        Task.detached {
            do {
                let snap = try await client.register()
                print("realm\t\(snap.realmName)")
                print("user\t\(snap.selfUserID)\t\(snap.selfEmail)")
                print("channels\t\(snap.channels.count)")
                for channel in snap.channels.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
                    print("channel\t\(channel.streamID)\t\(channel.name)")
                }
                print("dms\t\(snap.recentDMs.count)")
                print("users\t\(snap.users.count)")
                print("mentions\t\(snap.unread.mentionCount)")
            } catch {
                failed = error.localizedDescription
            }
            sema.signal()
        }
        sema.wait()
        if let failed {
            fputs("dump failed: \(failed)\n", stderr)
            exit(1)
        }
        exit(0)
    }
}
