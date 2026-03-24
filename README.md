# Simple Claude Monitor

A lightweight macOS menu bar app that displays your Claude API usage as a floating desktop widget.

![macOS](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## Download

**[Download SimpleClaudeMonitor-1.0.dmg](https://github.com/lexey111/SimpleClaudeMonitor/releases/latest/download/SimpleClaudeMonitor-1.0.dmg)**

### Install

1. Open the DMG and drag **SimpleClaudeMonitor** to **Applications**
2. **Important — the app is not notarized**, so macOS will block it on first launch:
   - Open **System Settings → Privacy & Security**
   - Scroll down to the Security section — you'll see a message about SimpleClaudeMonitor being blocked
   - Click **Open Anyway**, then confirm in the dialog
   - Alternatively: right-click the app in Applications → **Open** → **Open** in the dialog
3. On first launch, allow Keychain access to "Claude Code-credentials" when prompted

> Requires macOS 15.0+ and [Claude Code](https://docs.anthropic.com/en/docs/claude-code) logged in (`claude login`).

## Features

- **Floating widget** — always-on-top translucent panel showing session (5-hour) and weekly (7-day) usage
- **Live countdown** — real-time timers showing when each usage window resets
- **Menu bar icon** — gauge icon in the macOS menu bar with About and Quit actions
- **Auto-polling** — refreshes usage data every 2 minutes, with a manual refresh button
- **Limit detection** — visual warning when session usage hits 100%

## How It Works

The app reads the OAuth token that [Claude Code](https://docs.anthropic.com/en/docs/claude-code) stores in the macOS Keychain (`Claude Code-credentials`), then polls the Anthropic usage API to retrieve current utilization percentages.

## Prerequisites

- macOS 15.0+
- Xcode 26+
- **Claude Code** must be installed and logged in (`claude login`) so the OAuth token exists in Keychain

## Setup

1. Clone the repository
2. Open `SimpleClaudeMonitor.xcodeproj` in Xcode
3. Build and run (Cmd+R)

On first launch the system will ask for Keychain access to "Claude Code-credentials" — click **Always Allow** to avoid repeated prompts.

> **Note:** The app is signed locally ("Sign to Run Locally"). After each rebuild the Keychain prompt may appear once because the code signature changes.

## Architecture

| File | Purpose |
|---|---|
| `SimpleClaudeMonitorApp.swift` | App entry point, `AppDelegate` that creates the floating `NSPanel`, `NSStatusItem` menu bar icon, and About dialog |
| `FloatingWidget.swift` | SwiftUI view — dark translucent widget with usage bars, countdown timers, and status indicators |
| `UsageMonitor.swift` | `ObservableObject` that reads the Keychain token, polls the Anthropic API, and publishes usage state |

## Configuration

The app runs as a background accessory (no Dock icon). It is controlled entirely through:

- **The floating widget** — drag to reposition, click the refresh button for an immediate update
- **The menu bar icon** — click for About / Quit

## License

MIT
