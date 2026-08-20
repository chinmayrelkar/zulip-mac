import SwiftUI
import ZulipCore

public struct UserProfilePopover: View {
    let user: User
    var presence: UserPresence?
    var status: UserStatus?
    var site: URL
    var loader: MediaLoader?
    var onSendDM: () -> Void

    public init(user: User, presence: UserPresence? = nil, status: UserStatus? = nil, site: URL, loader: MediaLoader? = nil, onSendDM: @escaping () -> Void) {
        self.user = user
        self.presence = presence
        self.status = status
        self.site = site
        self.loader = loader
        self.onSendDM = onSendDM
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(userID: user.userID, avatarURL: user.avatarURL, email: user.email, site: site, loader: loader, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.fullName)
                        .font(.system(size: 15, weight: .bold))

                    Text(user.email)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(presence?.status == .active ? Color.green : (presence?.status == .idle ? Color.orange : Color.secondary.opacity(0.4)))
                            .frame(width: 7, height: 7)
                        Text(presence?.status.rawValue.capitalized ?? "Offline")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let st = status?.statusText, !st.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(st)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            Button {
                onSendDM()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Direct Message")
                }
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(16)
        .frame(width: 260)
    }
}
