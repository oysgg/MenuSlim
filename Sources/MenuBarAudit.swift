import AppKit
import ApplicationServices

struct MenuBarMeasurement: Codable {
    let name: String
    let identity: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    var gapAfter: Double?
    var nextIdentity: String?
    var obscured: Bool
}

struct AuditComparison {
    enum Status: String { case changed = "检测到变化", unchanged = "未检测到变化", unmeasurable = "无法可靠比较" }
    let name: String
    let status: Status
    var beforeWidth: Double?
    var afterWidth: Double?
    var beforeGap: Double?
    var afterGap: Double?
}

enum MenuBarAudit {
    static func compare(_ before: [MenuBarMeasurement], _ after: [MenuBarMeasurement]) -> [AuditComparison] {
        let old = Dictionary(grouping: before, by: \.identity)
        let new = Dictionary(grouping: after, by: \.identity)
        return Set(old.keys).union(new.keys).sorted().map { id in
            let a = old[id] ?? [], b = new[id] ?? []
            let name = (b.first ?? a.first)!.name
            guard a.count == 1, b.count == 1, !id.contains("unknown:"),
                  !a[0].obscured, !b[0].obscured else {
                return AuditComparison(name: name, status: .unmeasurable)
            }
            let sameNeighbor = a[0].nextIdentity != nil && a[0].nextIdentity == b[0].nextIdentity
                && !(a[0].nextIdentity?.contains("unknown:") ?? true)
                && old[a[0].nextIdentity!]?.count == 1 && new[b[0].nextIdentity!]?.count == 1
                && old[a[0].nextIdentity!]?[0].obscured == false && new[b[0].nextIdentity!]?[0].obscured == false
            let ag = sameNeighbor ? a[0].gapAfter : nil, bg = sameNeighbor ? b[0].gapAfter : nil
            let changed = abs(a[0].width - b[0].width) > 0.5 || (ag != nil && bg != nil && abs(ag! - bg!) > 0.5)
            return AuditComparison(name: name, status: changed ? .changed : .unchanged,
                beforeWidth: a[0].width, afterWidth: b[0].width, beforeGap: ag, afterGap: bg)
        }
    }

    static func report(_ before: [MenuBarMeasurement], _ after: [MenuBarMeasurement]) -> String {
        func number(_ value: Double?) -> String { value.map { String(format: "%g", $0) } ?? "—" }
        let lines = compare(before, after).map { row in
            "\(row.name)：\(row.status.rawValue)\n  占位 \(number(row.beforeWidth)) → \(number(row.afterWidth)) pt；右侧空隙 \(number(row.beforeGap)) → \(number(row.afterGap)) pt"
        }
        return "测量的是系统提供的占位边界，不能拆分图标内部留白。变化也可能来自温度、时间等内容。未变化不等于不支持；未识别、遮挡、消失或重名项目不计为通过。\n\n" + lines.joined(separator: "\n\n")
    }
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = attribute(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: origin, size: size)
    }
    static func label(_ element: AXUIElement, depth: Int = 0) -> (String, String)? {
        if depth > 4 { return nil }
        let identifier = attribute(element, kAXIdentifierAttribute) as? String ?? ""
        let description = attribute(element, kAXDescriptionAttribute) as? String ?? ""
        let title = attribute(element, kAXTitleAttribute) as? String ?? ""
        if !identifier.isEmpty { return (description.isEmpty ? identifier : description, identifier) }
        // Do not collect AXValue/AXHelp: they can contain live app content.
        if !title.isEmpty && title.count < 50 && !title.contains("\n") { return (title, "title:" + title) }
        if !description.isEmpty && description.count < 50 { return (description, "description:" + description) }
        for child in children(element) { if let found = label(child, depth: depth + 1) { return found } }
        return nil
    }

    static func capture() throws -> [MenuBarMeasurement] {
        guard AXIsProcessTrusted() else { throw NSError(domain: "MenuBarAudit", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "检测需要辅助功能访问权限；本次没有测量，也没有请求或更改权限。"] ) }
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first else {
            throw NSError(domain: "MenuBarAudit", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到 MenuBarAgent，此检测器目前只适配 macOS 27。"])
        }
        let root = AXUIElementCreateApplication(agent.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 2)
        var rows: [MenuBarMeasurement] = []
        var windowNumber = 0
        for window in children(root) where attribute(window, kAXRoleAttribute) as? String == kAXWindowRole {
            guard let windowFrame = frame(window), windowFrame.height < 100 else { continue }
            windowNumber += 1
            var unknown = 0
            var items: [MenuBarMeasurement] = []
            for item in children(window) {
                guard let rect = frame(item) else { continue }
                let role = attribute(item, kAXRoleAttribute) as? String
                if role == kAXButtonRole { continue } // Overflow button is not a status item.
                let descriptor = label(item)
                unknown += 1
                items.append(MenuBarMeasurement(name: descriptor?.0 ?? "未识别项目 \(unknown)",
                    identity: "screen\(windowNumber):" + (descriptor?.1 ?? "unknown:\(unknown)"),
                    x: rect.minX, y: rect.minY, width: rect.width, height: rect.height,
                    gapAfter: nil, obscured: !windowFrame.contains(rect)))
            }
            items.sort { $0.x < $1.x }
            for i in items.indices where i + 1 < items.count {
                let gap = items[i + 1].x - items[i].x - items[i].width
                if gap < -0.5 { items[i].obscured = true; items[i + 1].obscured = true }
                else { items[i].gapAfter = gap; items[i].nextIdentity = items[i + 1].identity }
            }
            rows.append(contentsOf: items)
        }
        guard !rows.isEmpty else { throw NSError(domain: "MenuBarAudit", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "系统未提供可测量的菜单项目，不能判为通过。"] ) }
        return rows
    }

    static func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return String(decoding: try encoder.encode(capture()), as: UTF8.self)
    }
}
