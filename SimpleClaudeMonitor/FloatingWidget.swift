import SwiftUI

// MARK: - Main Widget

struct FloatingWidget: View {
    @ObservedObject var monitor: UsageMonitor
    @State private var tick = false   // drives live countdown re-render

    var body: some View {
        ZStack {
            // Background: dark glass
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            if monitor.isLoading {
                loadingView
            } else if let err = monitor.errorMessage {
                errorView(err)
            } else {
                mainContent
            }
        }
        .frame(width: 280, height: 160)
        .onAppear {
            // 1-second tick for live countdown
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                tick.toggle()
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(monitor.isLimitReached ? Color.red : Color(hex: "1DB954"))
                    .frame(width: 6, height: 6)
                Text("Claude")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(lastUpdatedLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))

                // Refresh button
                Button(action: { Task { await monitor.fetch() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer()

            // Session row
            usageRow(
                label: "session",
                value: monitor.sessionUtilization,
                resetsAt: monitor.sessionResetsAt,
                accentColor: sessionColor,
                isLimit: monitor.isLimitReached,
                tick: tick
            )

            Spacer()

            // Weekly row
            usageRow(
                label: "weekly",
                value: monitor.weeklyUtilization,
                resetsAt: monitor.weeklyResetsAt,
                accentColor: weeklyColor,
                isLimit: false,
                tick: tick
            )

            Spacer()

            // Cooldown banner (shown when session limit hit)
            if monitor.isLimitReached, let resets = monitor.sessionResetsAt {
                cooldownBanner(resets: resets)
            }

            Spacer().frame(height: monitor.isLimitReached ? 8 : 14)
        }
    }

    // MARK: - Usage Row

    private func usageRow(
        label: String,
        value: Double,
        resetsAt: Date?,
        accentColor: Color,
        isLimit: Bool,
        tick: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 48, alignment: .leading)

                Text(verbatim: "\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isLimit ? .red : .white.opacity(0.9))

                Spacer()

                if let date = resetsAt {
                    let _ = tick // force re-render each second
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.2))
                        Text(monitor.countdownString(to: date))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: geo.size.width * min(value, 1.0), height: 3)
                        .animation(.spring(response: 0.6), value: value)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Cooldown Banner

    private func cooldownBanner(resets: Date) -> some View {
        let _ = tick
        return HStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.system(size: 9))
                .foregroundColor(.orange.opacity(0.7))
            Text("limit reached · resets in \(monitor.countdownString(to: resets))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.orange.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(Color.orange.opacity(0.15))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white.opacity(0.4))
            Text("loading...")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
                .foregroundColor(.orange.opacity(0.6))
            Text(message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("retry") {
                Task { await monitor.fetch() }
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.4))
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed

    private var sessionColor: Color {
        switch monitor.sessionUtilization {
        case ..<0.6:  return Color(hex: "1DB954")
        case ..<0.85: return Color(hex: "F59E0B")
        default:      return Color(hex: "EF4444")
        }
    }

    private var weeklyColor: Color {
        switch monitor.weeklyUtilization {
        case ..<0.7:  return Color(hex: "3B82F6")
        case ..<0.9:  return Color(hex: "F59E0B")
        default:      return Color(hex: "EF4444")
        }
    }

    private var lastUpdatedLabel: String {
        guard let d = monitor.lastUpdated else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}

// MARK: - Color hex helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
