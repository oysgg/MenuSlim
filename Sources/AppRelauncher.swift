import AppKit

@MainActor enum AppRelauncher {
    static var isRunning = false
    struct Candidate {
        let app: NSRunningApplication
        let url: URL
        let name: String
    }

    static func candidates() -> [Candidate] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.processIdentifier != ownPID, !app.isTerminated,
                app.activationPolicy != .prohibited,
                let currentURL = app.bundleURL, currentURL.pathExtension == "app",
                app.bundleIdentifier != "com.apple.finder" else { return nil }
            // Launchd-owned services and nested login helpers cannot reliably be
            // reopened as user apps. Their parent app or the system owns them.
            let path = currentURL.path
            guard !path.hasPrefix("/System/Library/"), !path.hasPrefix("/usr/"),
                !path.hasPrefix("/Library/Apple/"), !path.contains(".app/Contents/") else { return nil }
            let registeredURL = app.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            let url = registeredURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? currentURL
            return Candidate(app: app, url: url, name: app.localizedName ?? currentURL.deletingPathExtension().lastPathComponent)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func run(_ targets: [Candidate], progress: (String) -> Void) async -> String {
        guard !isRunning else { return "已有重启任务正在进行。" }
        isRunning = true
        defer { isRunning = false }
        var pending: [Candidate] = []
        var failures: [String] = []
        var completed = 0
        for target in targets {
            if target.app.isTerminated { failures.append("\(target.name)：已自行退出，跳过"); continue }
            if target.app.terminate() { pending.append(target) }
            else { failures.append("\(target.name)：未同意退出") }
        }
        let deadline = Date().addingTimeInterval(30)
        while !pending.isEmpty {
            let finished = pending.filter { $0.app.isTerminated }
            pending.removeAll { $0.app.isTerminated }
            for target in finished {
                progress("正在重新打开 \(target.name)…")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = false
                configuration.addsToRecentItems = false
                let failure: String? = await withCheckedContinuation { continuation in
                    NSWorkspace.shared.openApplication(at: target.url, configuration: configuration) { app, error in
                        continuation.resume(returning: error?.localizedDescription ?? (app == nil ? "未能确认应用启动" : nil))
                    }
                }
                if let failure { failures.append("\(target.name)：\(failure)") }
                else { completed += 1 }
            }
            if Date() >= deadline {
                failures += pending.map { "\($0.name)：仍在运行（可能正在等待保存）；如稍后才退出，请手动重新打开" }
                break
            }
            if !pending.isEmpty {
                progress("等待 \(pending.count) 个应用退出，请处理它们的保存提示…")
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        return "已重新打开 \(completed) 个应用。" + (failures.isEmpty ? "" : "\n\n未完成项目：\n" + failures.joined(separator: "\n"))
    }
}
