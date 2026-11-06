import Foundation

@main struct LocalizationTests {
    static func main() throws {
        let resources = URL(fileURLWithPath: CommandLine.arguments[1])
        func text(_ key: String, _ language: String) -> String {
            Localization.string(key, language: language, resources: resources)
        }
        func catalog(_ language: String) throws -> [String: String] {
            let data = try Data(
                contentsOf: resources.appendingPathComponent("\(language).lproj/Localizable.strings"))
            return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
        }
        let english = try catalog("en")
        let chinese = try catalog("zh-Hans")
        assert(Set(english.keys) == Set(chinese.keys))
        let placeholders = try NSRegularExpression(pattern: "%[0-9$]*[ld@fg]+")
        func formats(_ string: String) -> [String] {
            placeholders.matches(in: string, range: NSRange(string.startIndex..., in: string))
                .map { (string as NSString).substring(with: $0.range) }
        }
        for key in english.keys {
            assert(!english[key]!.isEmpty && !chinese[key]!.isEmpty, key)
            assert(formats(english[key]!) == formats(chinese[key]!), key)
            assert(text(key, "en") == english[key]!, key)
            assert(text(key, "zh-Hans") == chinese[key]!, key)
        }
        assert(text("菜单栏间距", "en") == "MenuSlim")
        assert(text("菜单栏间距", "zh-Hans") == "菜单栏瘦身")
        assert(text("菜单栏间距", "fr") == "MenuSlim")
        assert(Localization.resolve("system", preferred: ["zh-CN", "en-US"]) == "zh-Hans")
        assert(Localization.resolve("system", preferred: ["en-US"]) == "en")
        assert(Localization.resolve("system", preferred: ["de-DE"]) == "en")
        assert(Localization.resolve("en", preferred: ["zh-CN"]) == "en")
        print(
            "\(english.count) translation pairs, format placeholders, language selection and fallback passed")
    }
}
