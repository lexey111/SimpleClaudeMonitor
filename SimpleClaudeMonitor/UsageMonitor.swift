import Combine
import Foundation
import Security

// MARK: - API Response Models

struct UsageResponse: Codable {
    let fiveHour: UsagePeriod?
    let sevenDay: UsagePeriod?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct UsagePeriod: Codable {
    let utilization: Double    // 0.0 – 1.0
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let s = resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: s) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)
    }
}

struct ClaudeCredentials: Codable {
    let claudeAiOauth: OAuthCredentials
}

struct OAuthCredentials: Codable {
    let accessToken: String
    let subscriptionType: String?
}

// MARK: - Monitor

@MainActor
class UsageMonitor: ObservableObject {
    @Published var sessionUtilization: Double = 0
    @Published var weeklyUtilization: Double = 0
    @Published var sessionResetsAt: Date? = nil
    @Published var weeklyResetsAt: Date? = nil
    @Published var isLimitReached: Bool = false
    @Published var lastUpdated: Date? = nil
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = true

    private var timer: Timer?
    private let pollInterval: TimeInterval = 120
    private var cachedToken: String?

    // MARK: - Keychain

    private func readToken() -> String? {
        if let token = cachedToken { return token }

        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      "Claude Code-credentials",
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            if let creds = try? JSONDecoder().decode(ClaudeCredentials.self, from: data) {
                cachedToken = creds.claudeAiOauth.accessToken
                return cachedToken
            }
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            cachedToken = raw
            return cachedToken
        }

        cachedToken = ProcessInfo.processInfo.environment["CLAUDE_API_TOKEN"]
        return cachedToken
    }

    // MARK: - Fetch

    func fetch() async {
        guard let token = readToken() else {
            errorMessage = "Token not found in Keychain.\nRun: claude login"
            isLoading = false
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.0.31", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("gzip, compress, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 {
                    cachedToken = nil
                    errorMessage = "Token expired.\nRun: claude login"
                    isLoading = false
                    return
                }
                if http.statusCode == 429 {
                    errorMessage = "Rate limited.\nRetry in a couple of minutes."
                    isLoading = false
                    return
                }
                if http.statusCode != 200 {
                    errorMessage = "HTTP \(http.statusCode)"
                    isLoading = false
                    return
                }
            }

            let usage = try JSONDecoder().decode(UsageResponse.self, from: data)

            sessionUtilization = usage.fiveHour?.utilization ?? 0
            weeklyUtilization  = usage.sevenDay?.utilization ?? 0
            sessionResetsAt    = usage.fiveHour?.resetsAtDate
            weeklyResetsAt     = usage.sevenDay?.resetsAtDate
            isLimitReached     = sessionUtilization >= 1.0
            lastUpdated        = Date()
            errorMessage       = nil
            isLoading          = false

        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Polling

    func startPolling() {
        Task { await fetch() }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { await self?.fetch() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helpers

    func countdownString(to date: Date) -> String {
        let diff = date.timeIntervalSinceNow
        guard diff > 0 else { return "resetting..." }
        let h = Int(diff) / 3600
        let m = (Int(diff) % 3600) / 60
        let s = Int(diff) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
