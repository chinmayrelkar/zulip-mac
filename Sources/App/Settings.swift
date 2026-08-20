import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
public final class AppSettings {
    public static let fontFamilies: [String] = {
        let families = NSFontManager.shared.availableFontFamilies
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return ["System Default"] + families
    }()

    public var fontFamily: String {
        didSet { UserDefaults.standard.set(fontFamily, forKey: "settings.fontFamily") }
    }
    public var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "settings.fontSize") }
    }
    public var density: MessageDensity {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: "settings.density") }
    }
    public var translucency: Double {
        didSet { UserDefaults.standard.set(translucency, forKey: "settings.translucency.v2") }
    }

    /// Main UI text size (rows, headers, composer).
    public var uiFontSize: CGFloat { fontSize }
    /// Secondary labels (stream names, subtitles).
    public var uiSecondarySize: CGFloat { max(10, fontSize - 2) }
    /// Small labels (section headers, badges, timestamps).
    public var uiSmallSize: CGFloat { max(9, fontSize - 3) }

    public init() {
        let defaults = UserDefaults.standard
        fontFamily = defaults.string(forKey: "settings.fontFamily") ?? "System Default"
        fontSize = defaults.object(forKey: "settings.fontSize") as? Double ?? 13.5
        density = MessageDensity(rawValue: defaults.string(forKey: "settings.density") ?? "") ?? .cozy
        translucency = defaults.object(forKey: "settings.translucency.v2") as? Double ?? 0.0
    }
}

public enum MessageDensity: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case cozy = "Cozy"
    case roomy = "Roomy"

    public var id: String { rawValue }

    public var listSpacing: CGFloat {
        switch self {
        case .compact: 1
        case .cozy: 2
        case .roomy: 4
        }
    }

    public func rowSpacing(isFirst: Bool) -> CGFloat {
        switch self {
        case .compact: isFirst ? 2 : 1.5
        case .cozy: isFirst ? 4 : 3
        case .roomy: isFirst ? 7 : 5
        }
    }
}

public struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    public init() {}
    public var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Message Text") {
                Picker("Font", selection: $settings.fontFamily) {
                    ForEach(AppSettings.fontFamilies, id: \.self) { family in
                        Text(family).font(family == "System Default" ? .system(size: 13) : .custom(family, size: 13))
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Font size")
                    Slider(value: $settings.fontSize, in: 10...17, step: 0.5)
                    Text(settings.fontSize, format: .number.precision(.fractionLength(0...1)))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
            }

            Section("Layout") {
                Picker("Message density", selection: $settings.density) {
                    ForEach(MessageDensity.allCases) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                HStack {
                    Text("Translucency")
                    Slider(value: $settings.translucency, in: 0...1, step: 0.05)
                    Text(settings.translucency, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(.vertical, 8)
    }
}
