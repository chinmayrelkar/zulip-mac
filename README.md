# ZulipMac

A native macOS Zulip client. Not a web wrapper — SwiftUI + Zulip's real-time events API.

```
[ channels + DMs ]  [ topics | DM list ]  [ tabbed conversation ]
```

A tab is one topic, one DM, or one search. Clicking something already open focuses that tab; clicking something new replaces the current unpinned tab (⌘-click opens another).

## Features

- Real-time messaging via the Zulip event API (long-poll), typing indicators, presence
- Tabs: one per topic / DM / search — pin, close, cycle
- Markdown rendering (bold, code, quotes, tables, spoilers, links open in the browser)
- Custom emoji (realm + zulip-extra) inline in messages, reactions, and the picker
- Reactions with hover tooltips showing who reacted
- **Read receipts** — who has seen each message (click the avatars)
- Full **keyboard navigation**: ⌘P quick open, ⇧⌘P command palette, Tab cycles panes, ⌘1-9 / ⌥1-9 select tabs / sidebar items
- **Settings (⌘,):** font family, font size (scales the whole UI), message density, translucency
- Channel-colored hover, recency/relevance-sorted sidebar, native macOS translucency
- Offline cache for state, threads, and avatars

## Run

```
make run        # build + launch dist/ZulipMac.app
make test
make dump       # print channels, no secrets
```

Sign in with your Zulip email and password. The app exchanges it for an API key and writes it to `~/.config/zulip-mac/credentials` (mode 600). The password is not kept; no keychain. Do not use `ZULIP_REST_API__CREDENTIALS` for the GUI — that env var is for tooling.

## Keys

| Shortcut | Action |
| --- | --- |
| ⌘P / ⇧⌘P | Quick open / command palette |
| ⌘B / ⇧⌘B | Toggle left (channels) / center (topics) pane |
| ⌘1-9 | Select open tab |
| ⌥1-9 | Select sidebar item |
| Tab | Cycle focus: sidebar → topics → composer |
| Enter | Send (⇧Enter newline) |
| ⌘W | Close tab |
| ⌃Tab / ⌃⇧Tab | Cycle tabs |
| ⌘F | Search |
| ⌘, | Settings |
| Esc | Back to sidebar / close overlays |

Search is the Zulip narrow language (`channel:`, `topic:`, `sender:me`, `is:mentioned`, `is:starred`, `has:image`, `-is:resolved`, `near:12345`, …).

## Build

Swift 6, macOS 14+. `swift build && ./scripts/package.sh` produces `dist/ZulipMac.app` (ad-hoc signed).
