import Foundation
import AppKit

// MARK: - Data Models

struct CopilotUsageData {
    let planType: String
    let nextBillingDate: String
    let subscriptionCost: Double
    let premiumUnitPrice: Double
    let premiumUsed: Int
    let premiumIncluded: Int

    var overageCount: Int { max(0, premiumUsed - premiumIncluded) }
    var overageCost: Double { Double(overageCount) * premiumUnitPrice }
    var usagePercent: Int {
        guard premiumIncluded > 0 else { return 0 }
        return Int(Double(premiumUsed) / Double(premiumIncluded) * 100)
    }
}

struct AppSettings: Codable {
    var githubToken: String
    var premiumIncluded: Int
    var subscriptionCost: Double
    var premiumUnitPrice: Double
    var cnyRate: Double

    static let `default` = AppSettings(
        githubToken: "",
        premiumIncluded: 300,
        subscriptionCost: 19.0,
        premiumUnitPrice: 0.04,
        cnyRate: 7.2
    )
}

// MARK: - GitHub Device Flow

struct DeviceCodeResponse: Codable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct AccessTokenResponse: Codable {
    let accessToken: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
    }
}

// MARK: - GitHub Copilot Internal API

struct CopilotInternalResponse: Codable {
    let copilotPlan: String?
    let quotaResetDate: String?
    let quotaSnapshots: [String: QuotaSnapshot]?

    enum CodingKeys: String, CodingKey {
        case copilotPlan = "copilot_plan"
        case quotaResetDate = "quota_reset_date"
        case quotaSnapshots = "quota_snapshots"
    }
}

struct QuotaSnapshot: Codable {
    let entitlement: Double?
    let remaining: Double?
    let unlimited: Bool?
    let overagePermitted: Bool?

    enum CodingKeys: String, CodingKey {
        case entitlement
        case remaining
        case unlimited
        case overagePermitted = "overage_permitted"
    }
}

// MARK: - Service

enum AuthState {
    case notAuthorized
    case authorizing(userCode: String, verificationUri: String)
    case authorized
}

struct ReleaseInfo {
    let version: String
    let url: String
}

@MainActor
class GitHubCopilotService: ObservableObject {
    @Published var usageData: CopilotUsageData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authState: AuthState = .notAuthorized
    @Published var settings: AppSettings = .default
    @Published var newRelease: ReleaseInfo?

    static let currentVersion = "1.0.0"

    // GitHub Copilot for Neovim — publicly known client_id, used for Device Flow
    private let clientId = "Iv1.b507a08c87ecfe98"

    nonisolated(unsafe) private var refreshTimer: Timer?
    nonisolated(unsafe) private var pollTask: Task<Void, Never>?

    nonisolated init() {
        Task { @MainActor in self.loadSettings() }
    }

    func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "app_settings"),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        }
        authState = settings.githubToken.isEmpty ? .notAuthorized : .authorized
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "app_settings")
        }
    }

    // MARK: - Device Flow Login

    func startDeviceFlow() async {
        pollTask?.cancel()
        errorMessage = nil

        guard let url = URL(string: "https://github.com/login/device/code") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "client_id=\(clientId)&scope=read:user".data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(DeviceCodeResponse.self, from: data)

            authState = .authorizing(
                userCode: decoded.userCode,
                verificationUri: decoded.verificationUri
            )

            // Open browser
            if let uri = URL(string: decoded.verificationUri) {
                NSWorkspace.shared.open(uri)
            }

            // Start polling
            pollTask = Task {
                await pollForToken(
                    deviceCode: decoded.deviceCode,
                    interval: decoded.interval,
                    expiresIn: decoded.expiresIn
                )
            }
        } catch {
            errorMessage = "获取验证码失败：\(error.localizedDescription)"
        }
    }

    private func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        let pollInterval = max(interval, 5)

        while Date() < deadline {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
            if Task.isCancelled { return }

            guard let url = URL(string: "https://github.com/login/oauth/access_token") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                let decoded = try JSONDecoder().decode(AccessTokenResponse.self, from: data)

                if let token = decoded.accessToken, !token.isEmpty {
                    await MainActor.run {
                        self.settings.githubToken = token
                        self.saveSettings()
                        self.authState = .authorized
                    }
                    await fetchUsage()
                    return
                }

                if let err = decoded.error {
                    if err == "authorization_pending" { continue }
                    if err == "slow_down" {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        continue
                    }
                    // access_denied or expired_token
                    await MainActor.run {
                        self.authState = .notAuthorized
                        self.errorMessage = "授权失败：\(err)"
                    }
                    return
                }
            } catch {
                continue
            }
        }

        await MainActor.run {
            self.authState = .notAuthorized
            self.errorMessage = "验证码已过期，请重试"
        }
    }

    func logout() {
        pollTask?.cancel()
        settings.githubToken = ""
        saveSettings()
        authState = .notAuthorized
        usageData = nil
        errorMessage = nil
    }

    // MARK: - Fetch Usage

    func fetchUsage() async {
        guard !settings.githubToken.isEmpty else {
            authState = .notAuthorized
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let data = try await fetchCopilotInternal(token: settings.githubToken)
            usageData = data
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchCopilotInternal(token: String) async throws -> CopilotUsageData {
        guard let url = URL(string: "https://api.github.com/copilot_internal/user") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("openclawpanel/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 {
                await MainActor.run {
                    self.settings.githubToken = ""
                    self.saveSettings()
                    self.authState = .notAuthorized
                }
                throw NSError(domain: "CopilotUsage", code: 401,
                             userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新授权"])
            }
            guard http.statusCode == 200 else {
                throw NSError(domain: "CopilotUsage", code: http.statusCode,
                             userInfo: [NSLocalizedDescriptionKey: "API 错误 \(http.statusCode)"])
            }
        }

        let parsed = try JSONDecoder().decode(CopilotInternalResponse.self, from: data)
        let snapshots = parsed.quotaSnapshots ?? [:]

        // Find premium_interactions window
        let premiumSnap = snapshots["premium_interactions"]
        let entitlement = Int(premiumSnap?.entitlement ?? Double(settings.premiumIncluded))
        let remaining = Int(premiumSnap?.remaining ?? 0)
        let used = max(0, entitlement - remaining)

        return CopilotUsageData(
            planType: parsed.copilotPlan ?? "business",
            nextBillingDate: parsed.quotaResetDate ?? "未知",
            subscriptionCost: settings.subscriptionCost,
            premiumUnitPrice: settings.premiumUnitPrice,
            premiumUsed: used,
            premiumIncluded: entitlement
        )
    }

    func startAutoRefresh(interval: TimeInterval = 300) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchUsage() }
        }
        if !settings.githubToken.isEmpty {
            Task { await fetchUsage() }
        }
        Task { await checkForUpdate() }
    }

    func checkForUpdate() async {
        guard let url = URL(string: "https://api.github.com/repos/bknds/CopilotUsage/releases/latest") else { return }
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlUrl = json["html_url"] as? String else { return }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        if latest.compare(Self.currentVersion, options: .numeric) == .orderedDescending {
            newRelease = ReleaseInfo(version: latest, url: htmlUrl)
        }
    }
}
