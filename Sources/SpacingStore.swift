import AppKit
import Foundation

struct SpacingState: Codable, Equatable {
    var spacing: Int?
    var padding: Int?
}

enum SpacingError: LocalizedError {
    case invalidValue, unsupportedPreference, writeFailed, noBackup
    var errorDescription: String? {
        switch self {
        case .invalidValue: return "间距需要在 0–40 pt 之间。"
        case .unsupportedPreference: return "当前间距设置的格式无法识别，未修改系统设置。"
        case .writeFailed: return "系统设置写入或核对失败，请重试。"
        case .noBackup: return "还没有原设置备份。首次应用时会自动保存。"
        }
    }
}

struct SpacingStore {
    static let keys = ["NSStatusItemSpacing", "NSStatusItemSelectionPadding"]
    let backupURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("com.yangshuai.MenuSpacing/original.plist")

    func read() throws -> SpacingState {
        let values: [Int?] = try Self.keys.map { key in
            guard let value = CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else { return nil }
            guard CFGetTypeID(value) == CFNumberGetTypeID(), let number = value as? NSNumber,
                number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
                abs(number.doubleValue) < 10000 else { throw SpacingError.unsupportedPreference }
            return number.intValue
        }
        return SpacingState(spacing: values[0], padding: values[1])
    }

    func backup() throws -> SpacingState {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { throw SpacingError.noBackup }
        return try PropertyListDecoder().decode(SpacingState.self, from: Data(contentsOf: backupURL))
    }

    private func write(_ state: SpacingState) throws {
        for (key, value) in zip(Self.keys, [state.spacing, state.padding]) {
            CFPreferencesSetValue(key as CFString, value.map { NSNumber(value: $0) },
                kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        }
        guard CFPreferencesSynchronize(kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser, kCFPreferencesCurrentHost), try read() == state else {
            throw SpacingError.writeFailed
        }
    }

    func apply(_ value: Int) throws {
        guard (0...40).contains(value) else { throw SpacingError.invalidValue }
        let before = try read()
        if !FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListEncoder().encode(before).write(to: backupURL, options: .atomic)
        } else {
            _ = try backup() // Never overwrite a backup we cannot read.
        }
        // Match Menu Bar Spacing 1.2.2; >= 16 removes the padding override.
        let padding = value < 16 ? max(2, min(value - 2, 10)) : nil
        do { try write(SpacingState(spacing: value, padding: padding)) }
        catch { try? write(before); throw error }
    }

    func refreshSystemItems() -> Bool {
        var succeeded = true
        for bundle in ["com.apple.controlcenter", "com.apple.systemuiserver", "com.apple.TextInputMenuAgent"] {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
            // Input-menu agent is optional if the input menu is not enabled.
            if apps.isEmpty && bundle != "com.apple.TextInputMenuAgent" { succeeded = false }
            for app in apps where kill(app.processIdentifier, SIGTERM) != 0 { succeeded = false }
        }
        return succeeded
    }

    func restore() throws {
        let original = try backup()
        let before = try read()
        do { try write(original) }
        catch { try? write(before); throw error }
    }

}
