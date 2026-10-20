import Foundation

struct Dashboard: Decodable {
    let observedAt: String
    let credentials: [Account]
    let errors: [String]
}
struct Account: Decodable, Identifiable {
    var id: String { authIndex }
    let authIndex, name, provider, status: String
    let email, statusMessage, nextRetryAfter: String?
    let unavailable: Bool
    let windows: [Quota]
    let billing: Billing?
    let cursorUsage: CursorUsage?
    var title: String { ["codex": "Codex", "claude": "Claude", "xai": "Grok"][provider] ?? provider.capitalized }
    var plan: String { billing?.plan ?? "Plan not reported" }
}
struct Billing: Decodable {
    let plan: String?
    let prepaidBalanceUsd, onDemandUsedUsd, onDemandLimitUsd: Double?
}
struct CursorUsage: Decodable {
    struct Total: Decodable { let costUsd, tokens: Double }
    let today, last30Days: Total
    let error: String?
}
struct Quota: Decodable, Identifiable {
    let id, label: String
    let remaining, cap: Double
    let resetAt: String?
    var fraction: Double { cap > 0 && remaining.isFinite && cap.isFinite ? min(1, max(0, remaining / cap)) : 0 }
}
struct Costs: Decodable {
    let observedAt, timezone: String
    let complete, stale: Bool
    let models: [ModelCost]
    let daily: [DayCost]
    var total: Double { models.compactMap(\.estimatedUsd).reduce(0, +) }
    var tokens: Double { models.map(\.tokens).reduce(0, +) }
    var requests: Double { models.map(\.requests).reduce(0, +) }
    var today: DayCost? {
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: timezone); f.dateFormat = "yyyy-MM-dd"
        return daily.first { $0.at.hasPrefix(f.string(from: Date())) }
    }
}
struct ModelCost: Decodable, Identifiable {
    var id: String { model }
    let model: String
    let tokens, requests: Double
    let estimatedUsd: Double?
    let complete: Bool
}
struct DayCost: Decodable, Identifiable {
    var id: String { at }
    let at: String
    let estimatedUsd, tokens, requests: Double
    let complete: Bool
}
func money(_ amount: Double) -> String { amount.formatted(.currency(code: "USD")) }
func compact(_ amount: Double) -> String { amount.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))) }
func instant(_ text: String) -> Date? {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: text) ?? ISO8601DateFormatter().date(from: text)
}
func resetLabel(_ value: String?) -> String {
    guard let value, let date = instant(value) else { return "Reset not reported" }
    let seconds = Int(date.timeIntervalSinceNow)
    guard seconds > 0 else { return "Reset pending update" }
    let minutes = max(1, seconds / 60), hours = seconds / 3600, days = seconds / 86400
    if days > 0 { return "Resets in \(days)d \(hours % 24)h" }
    if hours > 0 { return "Resets in \(hours)h \(minutes % 60)m" }
    return "Resets in \(minutes)m"
}
