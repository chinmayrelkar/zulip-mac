import Foundation

public enum MessageTime {
    public static func dayStart(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func dayLabel(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        }
        return formatter.string(from: date)
    }

    public static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    public static func fullLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public enum HTMLRewrite {
    public static func resolve(_ html: String, site: URL) -> String {
        var base = site.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        var result = html
        for attr in ["src", "href"] {
            result = result.replacingOccurrences(
                of: "\(attr)=\"/",
                with: "\(attr)=\"\(base)/"
            )
            result = result.replacingOccurrences(
                of: "\(attr)='/",
                with: "\(attr)='\(base)/"
            )
        }
        return result
    }
}
