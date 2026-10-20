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
extension Account {
    var cursorCost: Double { cursorUsage?.last30Days.costUsd ?? 0 }
    var shortEmail: String {
        let text = email ?? name
        guard let at = text.firstIndex(of: "@") else { return text }
        let local = text[..<at]
        return local.count > 4 ? local.prefix(3) + "…" + text[at...] : text
    }
}
extension Quota {
    var shortLabel: String {
        ["5-hour limit": "5h", "7-day limit": "Week", "7-day credits": "Week", "Cloud session credits": "Cloud", "7-day Fable": "Fable"][label] ?? label
    }
    var percent: String { "\(Int((fraction * 100).rounded()))%" }
}
/// Proxy spending plus usage that Cursor-priced accounts report directly.
func usageTotal(_ costs: Costs?, _ accounts: [Account]) -> Double {
    (costs?.total ?? 0) + accounts.map(\.cursorCost).reduce(0, +)
}
func usageToday(_ costs: Costs?, _ accounts: [Account]) -> Double {
    (costs?.today?.estimatedUsd ?? 0) + accounts.compactMap { $0.cursorUsage?.today.costUsd }.reduce(0, +)
}
func shortReset(_ value: String?) -> String {
    let label = resetLabel(value)
    return label.hasPrefix("Resets in ") ? String(label.dropFirst(10)) : "—"
}
extension Account {
    /// Windows worth showing; Claude's Fable and cloud-session credits are noise.
    var shownWindows: [Quota] { windows.filter { !$0.label.contains("Fable") && !$0.label.hasPrefix("Cloud") } }
    var weekly: Quota? { windows.first { $0.label == "7-day limit" || $0.label == "7-day credits" } }
}
/// Combined weekly quota per provider: remaining over cap, pooled across every account, disabled ones included.
struct Headroom: Identifiable {
    let id, name: String
    let fraction: Double
    static func from(_ accounts: [Account]) -> [Headroom] {
        [("claude", "Claude"), ("codex", "Codex"), ("xai", "Grok")].compactMap { provider, name in
            let weekly = accounts.filter { $0.provider == provider }.compactMap(\.weekly).filter { $0.cap > 0 && $0.cap.isFinite }
            guard !weekly.isEmpty else { return nil }
            let remaining = weekly.map { min($0.cap, max(0, $0.remaining.isFinite ? $0.remaining : 0)) }.reduce(0, +)
            return Headroom(id: provider, name: name, fraction: remaining / weekly.map(\.cap).reduce(0, +))
        }
    }
}
