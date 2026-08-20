import Foundation

public struct EmojiItem: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var code: String
    public var symbol: String
    public var category: String
    public var isCustom: Bool
    public var customURL: String?

    public init(
        name: String,
        code: String,
        symbol: String,
        category: String = "General",
        isCustom: Bool = false,
        customURL: String? = nil
    ) {
        self.name = name
        self.code = code
        self.symbol = symbol
        self.category = category
        self.isCustom = isCustom
        self.customURL = customURL
    }
}

public struct EmojiProvider: Sendable {
    public static func unicode(fromCode code: String) -> String? {
        let clean = code.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r"))
        if clean.isEmpty { return nil }
        let parts = clean.split(separator: "-")
        var scalars: [UnicodeScalar] = []
        for part in parts {
            guard let val = UInt32(part, radix: 16), let scalar = UnicodeScalar(val) else {
                return nil
            }
            scalars.append(scalar)
        }
        guard !scalars.isEmpty else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    public static func character(for name: String) -> String? {
        let clean = name.trimmingCharacters(in: CharacterSet(charactersIn: ": \t\n\r")).lowercased()
        if let code = nameToCode[clean], let decoded = unicode(fromCode: code) {
            return decoded
        }
        return nil
    }

    public static func display(
        name: String,
        code: String,
        type: String,
        realmEmojis: [String: RealmEmoji] = [:]
    ) -> DisplayEmoji {
        if type == "realm_emoji" || type == "zulip_extra_emoji" {
            if let custom = realmEmojis[code] ?? realmEmojis[name] {
                return .custom(url: custom.sourceURL, name: custom.name)
            }
            // zulip_extra_emoji entries not in the realm emoji list are often
            // plain unicode codepoints — render those as text rather than a gap.
            if type == "zulip_extra_emoji", let decoded = unicode(fromCode: code) {
                return .unicode(decoded)
            }
            return .custom(url: "", name: name)
        }
        if let decoded = unicode(fromCode: code) {
            return .unicode(decoded)
        }
        if let fallbackCode = nameToCode[name.lowercased()], let decoded = unicode(fromCode: fallbackCode) {
            return .unicode(decoded)
        }
        return .unicode(name)
    }

    public enum DisplayEmoji: Equatable, Sendable {
        case unicode(String)
        case custom(url: String, name: String)
    }

    public static let quickReactionNames = [
        "+1", "heart", "tada", "joy", "rocket", "eyes", "thinking", "clap", "fire", "100", "smile", "check"
    ]

    public static let standardEmojiItems: [EmojiItem] = [
        // Smileys & Emotion
        EmojiItem(name: "smile", code: "1f604", symbol: "😄", category: "Smileys"),
        EmojiItem(name: "grinning", code: "1f600", symbol: "😀", category: "Smileys"),
        EmojiItem(name: "joy", code: "1f602", symbol: "😂", category: "Smileys"),
        EmojiItem(name: "rofl", code: "1f923", symbol: "🤣", category: "Smileys"),
        EmojiItem(name: "sweat_smile", code: "1f605", symbol: "😅", category: "Smileys"),
        EmojiItem(name: "blush", code: "1f60a", symbol: "😊", category: "Smileys"),
        EmojiItem(name: "innocent", code: "1f607", symbol: "😇", category: "Smileys"),
        EmojiItem(name: "wink", code: "1f609", symbol: "😉", category: "Smileys"),
        EmojiItem(name: "heart_eyes", code: "1f60d", symbol: "😍", category: "Smileys"),
        EmojiItem(name: "star_struck", code: "1f929", symbol: "🤩", category: "Smileys"),
        EmojiItem(name: "kissing_heart", code: "1f618", symbol: "😘", category: "Smileys"),
        EmojiItem(name: "yum", code: "1f60b", symbol: "😋", category: "Smileys"),
        EmojiItem(name: "sunglasses", code: "1f60e", symbol: "😎", category: "Smileys"),
        EmojiItem(name: "nerd", code: "1f913", symbol: "🤓", category: "Smileys"),
        EmojiItem(name: "partying_face", code: "1f973", symbol: "🥳", category: "Smileys"),
        EmojiItem(name: "smirk", code: "1f60f", symbol: "😏", category: "Smileys"),
        EmojiItem(name: "thinking", code: "1f914", symbol: "🤔", category: "Smileys"),
        EmojiItem(name: "neutral_face", code: "1f610", symbol: "😐", category: "Smileys"),
        EmojiItem(name: "flushed", code: "1f633", symbol: "😳", category: "Smileys"),
        EmojiItem(name: "pleading_face", code: "1f97a", symbol: "🥺", category: "Smileys"),
        EmojiItem(name: "sob", code: "1f62d", symbol: "😭", category: "Smileys"),
        EmojiItem(name: "scream", code: "1f631", symbol: "😱", category: "Smileys"),
        EmojiItem(name: "rage", code: "1f621", symbol: "😡", category: "Smileys"),
        EmojiItem(name: "exploding_head", code: "1f92f", symbol: "🤯", category: "Smileys"),
        EmojiItem(name: "saluting_face", code: "1fae1", symbol: "🫡", category: "Smileys"),
        EmojiItem(name: "skull", code: "1f480", symbol: "💀", category: "Smileys"),

        // Gestures & People
        EmojiItem(name: "+1", code: "1f44d", symbol: "👍", category: "People"),
        EmojiItem(name: "-1", code: "1f44e", symbol: "👎", category: "People"),
        EmojiItem(name: "clap", code: "1f44f", symbol: "👏", category: "People"),
        EmojiItem(name: "wave", code: "1f44b", symbol: "👋", category: "People"),
        EmojiItem(name: "raised_hands", code: "1f64c", symbol: "🙌", category: "People"),
        EmojiItem(name: "pray", code: "1f64f", symbol: "🙏", category: "People"),
        EmojiItem(name: "handshake", code: "1f91d", symbol: "🤝", category: "People"),
        EmojiItem(name: "muscle", code: "1f4aa", symbol: "💪", category: "People"),
        EmojiItem(name: "point_up", code: "261d", symbol: "☝️", category: "People"),
        EmojiItem(name: "point_right", code: "1f449", symbol: "👉", category: "People"),
        EmojiItem(name: "point_left", code: "1f448", symbol: "👈", category: "People"),
        EmojiItem(name: "ok_hand", code: "1f44c", symbol: "👌", category: "People"),
        EmojiItem(name: "peace", code: "270c", symbol: "✌️", category: "People"),
        EmojiItem(name: "pinched_fingers", code: "1f90f", symbol: "🤌", category: "People"),
        EmojiItem(name: "eyes", code: "1f440", symbol: "👀", category: "People"),

        // Objects & Symbols
        EmojiItem(name: "heart", code: "2764", symbol: "❤️", category: "Objects"),
        EmojiItem(name: "fire", code: "1f525", symbol: "🔥", category: "Objects"),
        EmojiItem(name: "100", code: "1f4af", symbol: "💯", category: "Objects"),
        EmojiItem(name: "sparkles", code: "2728", symbol: "✨", category: "Objects"),
        EmojiItem(name: "zap", code: "26a1", symbol: "⚡", category: "Objects"),
        EmojiItem(name: "star", code: "2b50", symbol: "⭐", category: "Objects"),
        EmojiItem(name: "tada", code: "1f389", symbol: "🎉", category: "Objects"),
        EmojiItem(name: "rocket", code: "1f680", symbol: "🚀", category: "Objects"),
        EmojiItem(name: "bulb", code: "1f4a1", symbol: "💡", category: "Objects"),
        EmojiItem(name: "check", code: "2705", symbol: "✅", category: "Objects"),
        EmojiItem(name: "x", code: "274c", symbol: "❌", category: "Objects"),
        EmojiItem(name: "warning", code: "26a0", symbol: "⚠️", category: "Objects"),
        EmojiItem(name: "lock", code: "1f512", symbol: "🔒", category: "Objects"),
        EmojiItem(name: "key", code: "1f511", symbol: "🔑", category: "Objects"),
        EmojiItem(name: "hammer", code: "1f528", symbol: "🔨", category: "Objects"),
        EmojiItem(name: "wrench", code: "1f527", symbol: "🔧", category: "Objects"),
        EmojiItem(name: "package", code: "1f4e6", symbol: "📦", category: "Objects"),
        EmojiItem(name: "memo", code: "1f4dd", symbol: "📝", category: "Objects"),
        EmojiItem(name: "calendar", code: "1f4c5", symbol: "📅", category: "Objects"),
        EmojiItem(name: "chart_with_upwards_trend", code: "1f4c8", symbol: "📈", category: "Objects"),
        EmojiItem(name: "bug", code: "1f41b", symbol: "🐛", category: "Objects"),
        EmojiItem(name: "coffee", code: "2615", symbol: "☕", category: "Objects"),
        EmojiItem(name: "beer", code: "1f37a", symbol: "🍺", category: "Objects"),
        EmojiItem(name: "pizza", code: "1f355", symbol: "🍕", category: "Objects"),
        EmojiItem(name: "robot", code: "1f916", symbol: "🤖", category: "Objects")
    ]

    public static let nameToCode: [String: String] = [
        "+1": "1f44d",
        "thumbs_up": "1f44d",
        "thumbsup": "1f44d",
        "-1": "1f44e",
        "thumbs_down": "1f44e",
        "heart": "2764",
        "red_heart": "2764",
        "tada": "1f389",
        "party": "1f389",
        "joy": "1f602",
        "rocket": "1f680",
        "eyes": "1f440",
        "thinking": "1f914",
        "thinking_face": "1f914",
        "clap": "1f44f",
        "fire": "1f525",
        "100": "1f4af",
        "smile": "1f604",
        "grinning": "1f600",
        "sweat_smile": "1f605",
        "rofl": "1f923",
        "wink": "1f609",
        "blush": "1f60a",
        "innocent": "1f607",
        "heart_eyes": "1f60d",
        "star_struck": "1f929",
        "kissing_heart": "1f618",
        "yum": "1f60b",
        "sunglasses": "1f60e",
        "nerd": "1f913",
        "partying_face": "1f973",
        "smirk": "1f60f",
        "neutral_face": "1f610",
        "flushed": "1f633",
        "pleading_face": "1f97a",
        "sob": "1f62d",
        "scream": "1f631",
        "rage": "1f621",
        "exploding_head": "1f92f",
        "saluting_face": "1fae1",
        "skull": "1f480",
        "wave": "1f44b",
        "raised_hands": "1f64c",
        "pray": "1f64f",
        "handshake": "1f91d",
        "muscle": "1f4aa",
        "point_up": "261d",
        "point_right": "1f449",
        "point_left": "1f448",
        "ok_hand": "1f44c",
        "peace": "270c",
        "pinched_fingers": "1f90f",
        "sparkles": "2728",
        "zap": "26a1",
        "star": "2b50",
        "check": "2705",
        "white_check_mark": "2705",
        "x": "274c",
        "warning": "26a0",
        "question": "2753",
        "exclamation": "2757",
        "bulb": "1f4a1",
        "lock": "1f512",
        "key": "1f511",
        "hammer": "1f528",
        "wrench": "1f527",
        "package": "1f4e6",
        "memo": "1f4dd",
        "calendar": "1f4c5",
        "chart_with_upwards_trend": "1f4c8",
        "bug": "1f41b",
        "coffee": "2615",
        "beer": "1f37a",
        "pizza": "1f355",
        "popcorn": "1f37f",
        "robot": "1f916",
        "shipit": "1f43f"
    ]
}
