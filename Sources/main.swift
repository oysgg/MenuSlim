import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let root = NSMenuItem()
        menu.addItem(root)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出菜单栏间距", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = appMenu
        NSApp.mainMenu = menu
        let host = NSHostingView(rootView: SettingsView())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 636, height: 520),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "菜单栏间距 · 实验版"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
