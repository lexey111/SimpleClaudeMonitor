import AppKit
import Combine
import SwiftUI

@main
struct SimpleClaudeMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var floatingWindow: NSPanel!
    private var statusItem: NSStatusItem!
    private var monitor: UsageMonitor!
    private var modeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        monitor = UsageMonitor()
        let contentView = FloatingWidget(monitor: monitor)

        let initialSize = monitor.displayMode.windowSize

        // Floating widget — always visible
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
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

        // Resize window when display mode changes
        modeCancellable = monitor.$displayMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.resizeWindow(to: mode.windowSize)
            }

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "gauge.medium",
                accessibilityDescription: "Claude Monitor"
            )
        }

        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(NSMenuItem(title: "Bars", action: #selector(selectBars), keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "Gauges", action: #selector(selectGauges), keyEquivalent: "2"))
        menu.addItem(NSMenuItem(title: "Mini", action: #selector(selectMini), keyEquivalent: "3"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "About Claude Monitor", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        monitor.startPolling()
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            switch item.action {
            case #selector(selectBars):
                item.state = monitor.displayMode == .bars ? .on : .off
            case #selector(selectGauges):
                item.state = monitor.displayMode == .gauges ? .on : .off
            case #selector(selectMini):
                item.state = monitor.displayMode == .mini ? .on : .off
            default:
                break
            }
        }
    }

    // MARK: - Mode Selection

    @objc private func selectBars() { monitor.setDisplayMode(.bars) }
    @objc private func selectGauges() { monitor.setDisplayMode(.gauges) }
    @objc private func selectMini() { monitor.setDisplayMode(.mini) }

    // MARK: - Window Resize

    private func resizeWindow(to size: CGSize) {
        guard let window = floatingWindow else { return }
        let oldFrame = window.frame
        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let margin: CGFloat = 10

        // Try to keep top edge fixed
        var y = oldFrame.origin.y + oldFrame.height - size.height
        // Clamp: don't go below visible area
        if y < visibleFrame.minY + margin {
            y = visibleFrame.minY + margin
        }
        // Clamp: don't go above visible area
        if y + size.height > visibleFrame.maxY - margin {
            y = visibleFrame.maxY - margin - size.height
        }

        var x = oldFrame.origin.x
        // Clamp horizontal too, in case width changes
        x = min(x, visibleFrame.maxX - margin - size.width)
        x = max(x, visibleFrame.minX + margin)

        let newFrame = NSRect(origin: NSPoint(x: x, y: y), size: NSSize(width: size.width, height: size.height))
        window.setFrame(newFrame, display: true, animate: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Claude Monitor"
        alert.informativeText = """
            Floating widget that displays your Claude API \
            session and weekly usage.

            Three display modes: Bars, Gauges, Mini \
            (switch via menu bar, Cmd+1/2/3).

            Reads the OAuth token from Keychain \
            (stored by Claude Code) and polls the \
            Anthropic usage endpoint every 2 min.

            v1.3
            """
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
