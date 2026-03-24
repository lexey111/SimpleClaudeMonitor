import SwiftUI

// MARK: - Main Widget

struct FloatingWidget: View {
    @ObservedObject var monitor: UsageMonitor
    @State private var tick = false   // drives live countdown re-render

    var body: some View {
        let mode = monitor.displayMode
        let cornerRadius: CGFloat = mode == .mini ? 8 : 14

        ZStack {
            // Solid dark translucent background — no blur, no flash
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(white: 0.12, opacity: 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            if monitor.isLoading {
                if mode == .mini { miniLoadingView } else { loadingView }
            } else if let err = monitor.errorMessage {
                if mode == .mini { miniErrorView(err) } else { errorView(err) }
            } else {
                switch mode {
                case .bars:   barsContent
                case .gauges: gaugesContent
                case .mini:   miniContent
                }
            }

            // Stale data warning overlay at bottom (not for mini — dot turns yellow)
            if mode != .mini, monitor.isDataStale, let warning = monitor.warningMessage {
                VStack {
                    Spacer()
                    staleBanner(warning)
                }
            }
        }
        .frame(width: mode.windowSize.width, height: mode.windowSize.height)
        .onAppear {
            // 1-second tick for live countdown
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                tick.toggle()
            }
        }
    }

    // MARK: - Shared Header

    private var header: some View {
        HStack {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)
            Text("Claude")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(lastUpdatedLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(monitor.isDataStale ? .yellow.opacity(0.6) : .white.opacity(0.25))

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
    }

    // MARK: - Bars Mode

    private var barsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer()

            // Session row
            usageRow(
                label: "session",
                value: monitor.sessionUtilization,
                resetsAt: monitor.sessionResetsAt,
                isLimit: monitor.isLimitReached
            )

            Spacer()

            // Weekly row
            usageRow(
                label: "weekly",
                value: monitor.weeklyUtilization,
                resetsAt: monitor.weeklyResetsAt,
                isLimit: false
            )

            Spacer()

            // Cooldown banner (shown when session limit hit)
            if monitor.isLimitReached, let resets = monitor.sessionResetsAt {
                cooldownBanner(resets: resets)
            }

            Spacer().frame(height: monitor.isLimitReached ? 8 : 14)
        }
    }

    // MARK: - Gauges Mode

    private var gaugesContent: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            HStack(spacing: 24) {
                arcGauge(
                    value: monitor.sessionUtilization,
                    label: "session",
                    resetsAt: monitor.sessionResetsAt
                )
                arcGauge(
                    value: monitor.weeklyUtilization,
                    label: "weekly",
                    resetsAt: monitor.weeklyResetsAt
                )
            }

            Spacer()

            if monitor.isLimitReached, let resets = monitor.sessionResetsAt {
                cooldownBanner(resets: resets)
            }

            Spacer().frame(height: monitor.isLimitReached ? 8 : 14)
        }
    }

    private func arcGauge(value: Double, label: String, resetsAt: Date?) -> some View {
        let color = colorForUtilization(value)
        return VStack(spacing: 4) {
            ZStack {
                // Background arc (270°)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .rotation(.degrees(135))
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)

                // Value arc
                Circle()
                    .trim(from: 0, to: 0.75 * min(value, 1.0))
                    .rotation(.degrees(135))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .animation(.spring(response: 0.6), value: value)

                // Center text
                VStack(spacing: 2) {
                    Text("\(Int(value * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                    if value >= 0.8, let date = resetsAt {
                        let _ = tick
                        Text(monitor.countdownString(to: date))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Mini Mode

    private var miniContent: some View {
        let _ = tick
        return HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 6, height: 6)

            Text("S \(Int(monitor.sessionUtilization * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(colorForUtilization(monitor.sessionUtilization))
            segmentedBar(value: monitor.sessionUtilization)

            Text("W \(Int(monitor.weeklyUtilization * 100))%")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(colorForUtilization(monitor.weeklyUtilization))
            segmentedBar(value: monitor.weeklyUtilization)

            Spacer()

            if monitor.isLimitReached {
                Text("limit")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
            } else if monitor.sessionUtilization >= 0.8, let resets = monitor.sessionResetsAt {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.2))
                    Text(monitor.countdownString(to: resets))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var miniLoadingView: some View {
        Text(monitor.isWaitingForKeychain ? "keychain..." : "loading...")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
    }

    private func miniErrorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundColor(.orange.opacity(0.6))
            Text(message.components(separatedBy: "\n").first ?? message)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
            Spacer()
            Button("retry") {
                Task { await monitor.fetch() }
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.white.opacity(0.4))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Segmented Bar (Mini)

    private func segmentedBar(value: Double, segments: Int = 5) -> some View {
        let filled = Int((min(value, 1.0) * Double(segments)).rounded(.up))
        let color = colorForUtilization(value)
        return HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < filled ? color : Color.white.opacity(0.1))
                    .frame(width: 4, height: 10)
            }
        }
    }

    // MARK: - Usage Row

    private func usageRow(
        label: String,
        value: Double,
        resetsAt: Date?,
        isLimit: Bool
    ) -> some View {
        let color = colorForUtilization(value)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 48, alignment: .leading)

                Text(verbatim: "\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isLimit ? .red : color)

                Spacer()

                if value >= 0.8, let date = resetsAt {
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
                        .fill(color)
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

    // MARK: - Stale Data Banner

    private func staleBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 9))
                .foregroundColor(.yellow.opacity(0.7))
            Text("stale · \(message)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.yellow.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(Color.yellow.opacity(0.08))
        .overlay(
            Rectangle()
                .fill(Color.yellow.opacity(0.15))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        Text(monitor.isWaitingForKeychain ? "waiting for keychain access..." : "loading...")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
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

    private var statusDotColor: Color {
        if monitor.isDataStale { return .yellow }
        if monitor.isLimitReached { return .red }
        return Color(hex: "1DB954")
    }

    private func colorForUtilization(_ value: Double) -> Color {
        let pct = value * 100
        switch pct {
        case ..<25:   return Color(hex: "3B82F6")   // blue
        case ..<50:   return Color(hex: "1DB954")   // green
        case ..<75:   return Color(hex: "A3E635")   // greenyellow
        case ..<85:   return Color(hex: "F59E0B")   // yellow
        case ..<95:   return Color(hex: "F97316")   // orange
        default:      return Color(hex: "EF4444")   // red
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
