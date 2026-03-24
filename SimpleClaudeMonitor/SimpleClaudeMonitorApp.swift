import AppKit
import SwiftUI

@main
struct SimpleClaudeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindow: NSPanel!
    private var statusItem: NSStatusItem!
    private var monitor: UsageMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = UsageMonitor()
        let contentView = FloatingWidget(monitor: monitor)

        // Floating widget — always visible
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isFloatingPanel = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isOpaque = false
        window.contentView = NSHostingView(rootView: contentView)

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let winSize = window.frame.size
            let x = screenFrame.maxX - winSize.width - 20
            let y = screenFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.makeKeyAndOrderFront(nil)
        floatingWindow = window

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "gauge.medium",
                accessibilityDescription: "Claude Monitor"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Claude Monitor", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.startPolling()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Claude Monitor"
        alert.informativeText = """
            Floating widget that displays your Claude API \
            session and weekly usage.

            Reads the OAuth token from Keychain \
            (stored by Claude Code) and polls the \
            Anthropic usage endpoint every 30 s.

            v1.0
            """
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
