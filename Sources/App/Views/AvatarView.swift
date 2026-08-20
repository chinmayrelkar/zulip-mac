import AppKit
import SwiftUI
import ZulipCore

/// Auth-aware, locally-cached avatar. Fetches through `MediaLoader` (sends the
/// Zulip Basic auth header, which `AsyncImage` cannot) and persists each user's
/// picture to disk under `~/.config/zulip-mac/cache/avatars/`.
public struct AvatarView: View {
    let userID: Int
    let avatarURL: String?
    let email: String
    let site: URL
    var loader: MediaLoader?
    let size: CGFloat

    @State private var image: NSImage?

    public init(userID: Int, avatarURL: String?, email: String, site: URL, loader: MediaLoader?, size: CGFloat) {
        self.userID = userID
        self.avatarURL = avatarURL
        self.email = email
        self.site = site
        self.loader = loader
        self.size = size
    }

    public var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: userID) { await load() }
    }

    private func load() async {
        if let cached = LocalCache.loadAvatar(userID), let img = NSImage(data: cached) {
            image = img
            return
        }
        guard let loader, let url = Avatar.url(avatar: avatarURL, email: email, site: site) else { return }
        if let data = await loader.data(for: url.absoluteString), let img = NSImage(data: data) {
            LocalCache.saveAvatar(data, userID: userID)
            image = img
        }
    }
}
