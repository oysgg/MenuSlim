import Foundation

enum Localization {
    static let choices = ["system", "zh-Hans", "en"]
    static let changed = Notification.Name("MenuSlimLanguageChanged")
    static var selection: String {
        get {
            let value = UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "system"
            return choices.contains(value) ? value : "system"
        }
        set {
            UserDefaults.standard.set(
                choices.contains(newValue) ? newValue : "system", forKey: "interfaceLanguage")
        }
    }
    static func resolve(_ choice: String, preferred: [String] = Locale.preferredLanguages) -> String {
        if choice == "en" || choice == "zh-Hans" { return choice }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: preferred).first ?? "en"
    }
    static var language: String { resolve(selection) }
    static func string(_ key: String, language: String, resources: URL) -> String {
        let localized = Bundle(url: resources.appendingPathComponent(language + ".lproj"))
        let fallback = Bundle(url: resources.appendingPathComponent("en.lproj"))
        let fallbackValue = fallback?.localizedString(forKey: key, value: key, table: nil) ?? key
        return localized?.localizedString(forKey: key, value: fallbackValue, table: nil) ?? fallbackValue
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let value = Localization.string(
        key, language: Localization.language, resources: Bundle.main.resourceURL ?? Bundle.main.bundleURL)
    return arguments.isEmpty
        ? value
        : String(format: value, locale: Locale(identifier: Localization.language), arguments: arguments)
}
