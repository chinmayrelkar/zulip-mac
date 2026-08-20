import Foundation
import Security

public struct Credentials: Sendable, Equatable {
    public var email: String
    public var apiKey: String
    public var site: URL

    public init(email: String, apiKey: String, site: URL) {
        self.email = email
        self.apiKey = apiKey
        self.site = site
    }

    public var basicToken: String {
        Data("\(email):\(apiKey)".utf8).base64EncodedString()
    }
}

public enum Auth {
    public static let defaultSite = URL(string: "https://zulip.clarisights.com")!

    public static var storeURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config/zulip-mac/credentials", directoryHint: .notDirectory)
    }

    public static func load(from url: URL = storeURL) -> Credentials? {
        loadFile(url) ?? loadZuliprc()
    }

    public static func loadIncludingEnvironment() -> Credentials? {
        load() ?? loadEnvironment()
    }

    public static func loadEnvironment() -> Credentials? {
        let raw = ProcessInfo.processInfo.environment["ZULIP_REST_API__CREDENTIALS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, let colon = raw.firstIndex(of: ":") else { return nil }
        let email = String(raw[..<colon])
        let key = String(raw[raw.index(after: colon)...])
        guard !email.isEmpty, !key.isEmpty else { return nil }
        let siteRaw = ProcessInfo.processInfo.environment["ZULIP_SITE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let site = siteRaw.flatMap(Self.siteURL) ?? defaultSite
        return Credentials(email: email, apiKey: key, site: site)
    }

    public static func loadZuliprc(at path: String = NSHomeDirectory() + "/.zuliprc") -> Credentials? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var email = ""
        var key = ""
        var site = defaultSite
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("email=") {
                email = String(trimmed.dropFirst(6))
            } else if trimmed.hasPrefix("key=") {
                key = String(trimmed.dropFirst(4))
            } else if trimmed.hasPrefix("site=") {
                site = siteURL(String(trimmed.dropFirst(5))) ?? site
            }
        }
        guard !email.isEmpty, !key.isEmpty else { return nil }
        return Credentials(email: email, apiKey: key, site: site)
    }

    public static func save(_ credentials: Credentials, to url: URL = storeURL) throws {
        dropLegacyKeychain()
        let payload = [
            "email": credentials.email,
            "apiKey": credentials.apiKey,
            "site": credentials.site.absoluteString,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func clear(at url: URL = storeURL) {
        dropLegacyKeychain()
        try? FileManager.default.removeItem(at: url)
    }

    public static func siteURL(_ raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !value.contains("://") {
            value = "https://\(value)"
        }
        return URL(string: value)
    }

    private static func loadFile(_ url: URL) -> Credentials? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let email = object["email"], let key = object["apiKey"],
              let site = object["site"].flatMap(URL.init(string:))
        else { return nil }
        return Credentials(email: email, apiKey: key, site: site)
    }

    private static func dropLegacyKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.chinmayrelkar.ZulipMac",
            kSecAttrAccount as String: "credentials",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
