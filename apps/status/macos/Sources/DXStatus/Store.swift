import Foundation
import SwiftUI

@MainActor final class Store: ObservableObject {
    @Published var filter = "All"
    @Published var showTokens = false
    @Published var dashboard: Dashboard?
    @Published var costs: Costs?
    @Published var tokenRate = TokenRate(peak: UserDefaults.standard.object(forKey: "proxyPeakTokensPerMinute") as? Double)
    @Published var loading = false
    @Published var error: String?
    @Published var costError: String?
    @Published var fetchedAt: Date?
    /// Banked ChatGPT resets by authIndex. The server caches these for 30 minutes.
    @Published var resets: [String: ResetCredits] = [:]
    private var resetsFetchedAt = Date.distantPast
    private var lastAttempt = Date.distantPast
    private let session = URLSession(configuration: .ephemeral)
    // Poll independently of the window so the menu bar label stays current.
    init() {
        Task { [weak self] in
            while let self {
                await self.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
    // The existing Devbox credential authorizes its CPA facade. Provider tokens and
    // the proxy management credential stay on the server.
    func request<T: Decodable>(_ path: String, as: T.Type) async throws -> T {
        let keyURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/devbox/api-key")
        let key = try String(contentsOf: keyURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw FetchError.missingKey }
        var request = URLRequest(url: URL(string: "https://api.devbox.harbr.run/api/v1/cpa" + path)!)
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 40
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw FetchError.invalid }
        guard response.statusCode == 200 else { throw FetchError.http(response.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func refresh() async {
        guard !loading, Date().timeIntervalSince(lastAttempt) > 15 else { return }
        loading = true; lastAttempt = Date()
        defer { loading = false }
        do {
            dashboard = try await request("", as: Dashboard.self)
            fetchedAt = Date(); error = nil
        } catch { self.error = message(error) }
        if Date().timeIntervalSince(resetsFetchedAt) > 600, let accounts = dashboard?.credentials {
            resetsFetchedAt = Date()
            for account in accounts where account.provider == "codex" {
                // Accounts ChatGPT will not list simply show no resets.
                resets[account.authIndex] = try? await request("/reset-credits?authIndex=" + account.authIndex, as: ResetCredits.self)
            }
        }
        do {
            let fresh = try await request("/costs?days=lifetime", as: Costs.self)
            costs = fresh; costError = nil
            if !fresh.stale, let at = instant(fresh.observedAt) {
                let previousPeak = tokenRate.peak
                tokenRate.record(tokens: fresh.tokens, at: at)
                if let peak = tokenRate.peak, peak != previousPeak {
                    UserDefaults.standard.set(peak, forKey: "proxyPeakTokensPerMinute")
                }
            } else { tokenRate.reset() }
        } catch { costError = message(error); tokenRate.reset() }
    }
    private func message(_ error: Error) -> String {
        if let e = error as? FetchError { return e.localizedDescription }
        if error is DecodingError { return "The proxy returned an unsupported response. Last data is retained." }
        if (error as NSError).domain == NSCocoaErrorDomain { return "Devbox API key is missing. Run dt auth login in Terminal." }
        return "Could not reach the proxy. Check your connection and refresh."
    }
    enum FetchError: LocalizedError {
        case missingKey, invalid, http(Int)
        var errorDescription: String? {
            switch self {
            case .missingKey: return "Devbox API key is missing. Run dt auth login in Terminal."
            case .invalid: return "The proxy returned an invalid response."
            case .http(let code): return code == 401 || code == 403 ? "Devbox access expired. Run dt auth login in Terminal." : "Proxy unavailable (HTTP \(code)). Last data is retained."
            }
        }
    }
}
