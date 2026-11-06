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
    @MainActor static private(set) var isRefreshing = false
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

    @MainActor func refreshSystemItems() async -> [String] {
        guard !Self.isRefreshing else { return ["已有系统项目刷新任务"] }
        Self.isRefreshing = true
        defer { Self.isRefreshing = false }
        var failures: [String] = []
        // Weather is a nested login item, not covered by ControlCenter or the
        // normal app relaunch list. Never start it if the user has disabled it.
        let weather = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.weather.menu")
        for bundle in ["com.apple.controlcenter", "com.apple.systemuiserver", "com.apple.TextInputMenuAgent"] {
            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
            if apps.isEmpty && bundle != "com.apple.TextInputMenuAgent" { failures.append("未找到进程：\(bundle)") }
            for app in apps where kill(app.processIdentifier, SIGTERM) != 0 { failures.append("无法刷新：\(bundle)，errno=\(errno)") }
        }
        if !weather.isEmpty {
            guard weather.allSatisfy({ $0.bundleURL?.path == "/System/Applications/Weather.app/Contents/Library/LoginItems/WeatherMenu.app" }) else {
                return failures + ["天气组件路径不匹配"]
            }
            let oldPIDs = Set(weather.map(\.processIdentifier))
            for app in weather where kill(app.processIdentifier, SIGTERM) != 0 {
                failures.append("天气退出请求失败")
            }
            // macOS relaunches this enabled login item itself. An explicit open
            // races that relaunch and can create duplicate weather icons.
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline {
                let live = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.weather.menu")
                    .filter { !$0.isTerminated }
                if live.count == 1 && !oldPIDs.contains(live[0].processIdentifier) { return failures }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            failures.append("天气未恢复为单个运行实例；可在系统设置重新打开天气开关")
        }
        return failures
    }

    func restore() throws {
        let original = try backup()
        let before = try read()
        do { try write(original) }
        catch { try? write(before); throw error }
    }

}
