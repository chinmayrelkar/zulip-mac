import CryptoKit
import Foundation

public enum Avatar {
    public static func url(avatar: String?, email: String, site: URL) -> URL? {
        if let avatar, !avatar.isEmpty {
            if let absolute = URL(string: avatar), absolute.scheme != nil {
                return absolute
            }
            if avatar.hasPrefix("/") {
                var base = site.absoluteString
                while base.hasSuffix("/") { base.removeLast() }
                return URL(string: base + avatar)
            }
            return URL(string: avatar)
        }
        return gravatar(email: email)
    }

    public static func gravatar(email: String) -> URL? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let digest = Insecure.MD5.hash(data: Data(trimmed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return URL(string: "https://secure.gravatar.com/avatar/\(hex)?d=identicon&s=64")
    }
}
