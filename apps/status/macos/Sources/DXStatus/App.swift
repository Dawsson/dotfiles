import AppKit
import Charts
import Combine
import ServiceManagement
import SwiftUI

@main struct DXStatusApp: App {
    @StateObject private var store = Store()
    @StateObject private var login = LoginItem()
    var body: some Scene {
        MenuBarExtra {
            StatusView(store: store, login: login)
        } label: {
            MenuBarLabel(store: store)
        }.menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: Store
    var body: some View {
        let items = Headroom.from(store.dashboard?.credentials ?? [])
        if items.isEmpty {
            Image(systemName: "gauge.with.dots.needle.33percent")
        } else {
            let stale = isStale(observedAt: store.dashboard?.observedAt)
            Image(nsImage: render(items, stale: stale))
                .accessibilityLabel(items.map { "\($0.name) \(Int(($0.fraction * 100).rounded())) percent" }.joined(separator: ", ") + (stale ? ", out of date" : ""))
        }
    }
    /// Stale data draws at reduced opacity, which a template image keeps in the menu bar.
    @MainActor func render(_ items: [Headroom], stale: Bool) -> NSImage {
        let view = HStack(spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 3) {
                    if let logo = Logo.image(item.id, size: 14) { Image(nsImage: logo).resizable().frame(width: 14, height: 14) }
                    Text("\(Int((item.fraction * 100).rounded()))%").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                }
            }
        }.foregroundStyle(.black.opacity(stale ? 0.4 : 1)).frame(height: 22)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

struct StatusView: View {
    @ObservedObject var store: Store
    @ObservedObject var login: LoginItem
    var credentials: [Account] { store.dashboard?.credentials ?? [] }
    var groups: [(title: String, accounts: [Account])] {
        Dictionary(grouping: credentials, by: \.title).sorted { $0.key < $1.key }
            .map { ($0.key, $0.value.sorted { ($0.unavailable ? 1 : 0, $0.shortEmail) < ($1.unavailable ? 1 : 0, $1.shortEmail) }) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
            if let error = store.error { notice(error).padding(.horizontal, 16).padding(.bottom, 10) }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                if store.dashboard == nil && store.loading { Text("Reading your accounts…").font(.callout).foregroundStyle(.secondary) }
                if store.dashboard != nil && credentials.isEmpty { Text("No accounts are connected.").font(.callout).foregroundStyle(.secondary) }
                ForEach(groups, id: \.title) { group in
                    ProviderSection(title: group.title, accounts: group.accounts, history: store.dashboard?.history ?? [], resets: store.resets)
                }
            }.padding(16)
            Divider()
            HStack {
                Link("Open dashboard", destination: URL(string: "https://devbox.buildwithharbor.com/dash/cpa")!)
                Spacer()
                Toggle("Open at login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
                    .toggleStyle(.checkbox).controlSize(.small)
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless)
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
        }.frame(width: 420)
            .task { await store.refresh() }
    }
    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Usage · 30 days").font(.caption).foregroundStyle(.secondary)
                Text(money(usageTotal(store.costs, credentials)))
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Text("Today " + money(usageToday(store.costs, credentials)))
                    if let costs = store.costs { Text("· " + compact(costs.tokens) + " tokens") }
                }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if let observed = store.dashboard?.observedAt, isStale(observedAt: observed), let date = instant(observed) {
                    Text("Quotas from \(shortDuration(Date().timeIntervalSince(date))) ago").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Button { Task { await store.refresh() } } label: {
                    if store.loading { ProgressView().controlSize(.mini) } else { Image(systemName: "arrow.clockwise") }
                }.buttonStyle(.borderless).frame(width: 16, height: 16)
                    .help("Refresh").accessibilityLabel("Refresh").disabled(store.loading)
                if let costs = store.costs, !costs.daily.isEmpty {
                    Chart(costs.daily) { day in
                        BarMark(x: .value("Date", String(day.at.prefix(10))), y: .value("USD", day.estimatedUsd))
                            .foregroundStyle(Color.primary.opacity(0.35)).cornerRadius(1.5)
                    }.chartXAxis(.hidden).chartYAxis(.hidden).frame(width: 150, height: 34)
                        .accessibilityLabel("Daily usage over the last 30 days")
                }
            }
        }
    }
    func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
    }
}

struct ProviderSection: View {
    let title: String
    let accounts: [Account]
    let history: [Sample]
    let resets: [String: ResetCredits]
    var hasResets: Bool { accounts.contains { resets[$0.authIndex] != nil } }
    var accent: Color { accounts.first.map { $0.provider == "claude" ? .orange : $0.provider == "codex" ? .teal : .purple } ?? .accentColor }
    /// Union of window ids in first-seen order, so meters line up across accounts.
    var slots: [String] {
        var seen: [String] = []
        for quota in accounts.flatMap(\.shownWindows) where !seen.contains(quota.id) { seen.append(quota.id) }
        return seen
    }
    func column(_ label: String) -> some View {
        Text(label).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 6) {
                    if let provider = accounts.first?.provider { LogoView(provider: provider, size: 13) }
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text("\(accounts.count)").font(.caption).foregroundStyle(.tertiary)
                }.frame(width: 118, alignment: .leading)
                HStack(spacing: 10) {
                    ForEach(slots, id: \.self) { slot in column(accounts.flatMap(\.shownWindows).first { $0.id == slot }?.shortLabel ?? slot) }
                    if accounts.contains(where: { $0.cursorUsage != nil }) { column("30 days") }
                    if hasResets { column("Resets") }
                }
            }
            VStack(spacing: 10) {
                ForEach(accounts) { account in AccountRow(account: account, slots: slots, accent: accent, history: history,
                                                              resets: resets[account.authIndex], resetColumn: hasResets) }
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let slots: [String]
    let accent: Color
    let history: [Sample]
    let resets: ResetCredits?
    let resetColumn: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.shortEmail).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                    .help(account.email ?? account.name)
                HStack(spacing: 4) {
                    Circle().fill(account.unavailable ? Color.secondary : Color.green).frame(width: 5, height: 5)
                    Text(account.unavailable ? account.status.capitalized : account.billing?.plan ?? "Active")
                        .lineLimit(1)
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(width: 118, alignment: .leading)
            HStack(alignment: .top, spacing: 10) {
                ForEach(slots, id: \.self) { slot in
                    if let quota = account.shownWindows.first(where: { $0.id == slot }) {
                        Meter(quota: quota, accent: accent, runsOut: runsOut(quota, authIndex: account.authIndex, history: history))
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
                if let usage = account.cursorUsage {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(money(usage.last30Days.costUsd)).font(.system(size: 11, weight: .semibold))
                        Text(compact(usage.last30Days.tokens) + " tokens").font(.system(size: 10)).foregroundStyle(.secondary)
                    }.monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
                }
                if resetColumn {
                    VStack(alignment: .leading, spacing: 4) {
                        if let resets {
                            Text("\(resets.available)").font(.system(size: 11, weight: .semibold))
                            if let next = resets.nextExpiry {
                                Text("next \(shortDuration(next.timeIntervalSinceNow))").font(.system(size: 10))
                                    .foregroundStyle(next.timeIntervalSinceNow < 3 * 86400 ? Color.orange : Color.secondary)
                            }
                        } else {
                            Text("—").font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                    }.monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine).accessibilityLabel("Banked resets")
                }
                if slots.isEmpty && account.cursorUsage == nil {
                    Text("Quota not reported").font(.system(size: 10)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.opacity(account.unavailable ? 0.5 : 1)
    }
}

struct Meter: View {
    let quota: Quota
    let accent: Color
    let runsOut: Date?
    var outLabel: String? { runsOut.map { "Out in " + shortDuration($0.timeIntervalSinceNow) } }
    var low: Bool { quota.fraction <= 0.1 }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(quota.percent).font(.system(size: 11, weight: .semibold)).foregroundStyle(low ? Color.red : Color.primary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.1))
                    Capsule().fill(low ? Color.red : accent).frame(width: max(quota.fraction > 0 ? 3 : 0, proxy.size.width * quota.fraction))
                }
            }.frame(height: 4)
            if let outLabel {
                // Running dry before the reset matters more than when the reset is.
                Text(outLabel).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(1)
            } else {
                Text(shortReset(quota.resetAt)).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
            }
        }.monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(quota.label).accessibilityValue("\(quota.percent) remaining, resets in \(shortReset(quota.resetAt))" + (outLabel.map { ", runs out in " + $0.dropFirst(7) } ?? ""))
    }
}

/// Opens at login by default; unchecking the footer toggle records an opt-out.
@MainActor final class LoginItem: ObservableObject {
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled
    init() {
        guard !UserDefaults.standard.bool(forKey: "loginItemConfigured") else { return }
        UserDefaults.standard.set(true, forKey: "loginItemConfigured")
        set(true)
    }
    func set(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        enabled = SMAppService.mainApp.status == .enabled
    }
}
