import AppKit
import Combine
import SwiftUI
import Charts

@main struct DXStatusApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        MenuBarExtra("DX Status", systemImage: "chart.bar.xaxis") {
            StatusView(store: store)
        }.menuBarExtraStyle(.window)
    }
}
struct StatusView: View {
    @ObservedObject var store: Store
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var accounts: [Account] {
        (store.dashboard?.credentials ?? []).filter { store.filter == "All" || $0.title == store.filter }
            .sorted { a, b in a.title == b.title ? (a.email ?? a.name) < (b.email ?? b.name) : a.title < b.title }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Proxy Status").font(.system(size: 19, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle().fill(store.error == nil ? Color.green : Color.orange).frame(width: 6, height: 6)
                        Text("CLI Proxy API").font(.caption).foregroundStyle(.secondary)
                        if let date = store.fetchedAt { Text(date, style: .relative).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                Spacer()
                if store.loading { ProgressView().controlSize(.small) }
                Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("Refresh proxy data").accessibilityLabel("Refresh proxy data").disabled(store.loading)
            }.padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = store.error { notice(error) }
                    if let costs = store.costs { spending(costs) }
                    if let error = store.costError { notice("Spending: " + error) }
                    if store.dashboard == nil && store.loading { Text("Reading your proxy accounts…").foregroundStyle(.secondary) }
                    if let dashboard = store.dashboard {
                        HStack {
                            Text("Accounts").font(.headline)
                            Text("\(dashboard.credentials.count)").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(dashboard.credentials.filter { !$0.unavailable }.count) available").font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("Provider", selection: $store.filter) {
                            Text("All").tag("All")
                            ForEach(Array(Set(dashboard.credentials.map(\.title))).sorted(), id: \.self) { Text($0).tag($0) }
                        }.pickerStyle(.segmented)
                        if dashboard.credentials.isEmpty { Text("No accounts are connected to the proxy.").foregroundStyle(.secondary) }
                        ForEach(accounts) { account in
                            AccountView(account: account)
                            Divider()
                        }
                        if !dashboard.errors.isEmpty {
                            DisclosureGroup("Proxy notices (\(dashboard.errors.count))") {
                                ForEach(dashboard.errors, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                            }
                        }
                    }
                }.padding(20)
            }.frame(height: 590)
            Divider()
            HStack {
                Link("Open proxy dashboard", destination: URL(string: "https://devbox.buildwithharbor.com/dash/cpa")!)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.borderless)
            }.font(.caption).padding(.horizontal, 20).padding(.vertical, 14)
        }.frame(width: 440)
            .task { await store.refresh() }
            .onReceive(timer) { _ in Task { await store.refresh() } }
    }
    func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
    }
    func spending(_ costs: Costs) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proxy usage").font(.headline)
                Spacer()
                Text("30 days").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text((costs.complete ? "" : "≥ ") + money(costs.total)).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(compact(costs.tokens) + " tokens").font(.subheadline).monospacedDigit()
                    Text(compact(costs.requests) + " requests").font(.caption).foregroundStyle(.secondary)
                }
            }
            Chart(costs.daily) { day in
                BarMark(x: .value("Date", String(day.at.prefix(10))), y: .value("Estimated USD", day.estimatedUsd))
                    .foregroundStyle(Color.accentColor.opacity(0.8)).cornerRadius(2)
            }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 46)
                .accessibilityLabel("Daily estimated proxy spending over the last 30 days")
            if let today = costs.today {
                HStack { Text("Today"); Spacer(); Text((today.complete ? "" : "≥ ") + money(today.estimatedUsd)); Text("· " + compact(today.tokens) + " tokens").foregroundStyle(.secondary) }.font(.caption).monospacedDigit()
            }
            Text("API-rate estimate · shared proxy traffic, not your subscription bill" + (costs.complete ? "" : " · some models unpriced"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if costs.stale || store.costError != nil { notice("Showing previously collected spending.") }
            DisclosureGroup("Spending by model") {
                VStack(spacing: 10) {
                    ForEach(costs.models) { model in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(model.model); Text(compact(model.tokens) + " tokens").foregroundStyle(.secondary) }
                            Spacer()
                            Text(model.estimatedUsd.map { (model.complete ? "" : "≥ ") + money($0) } ?? "Unpriced").monospacedDigit()
                        }.font(.caption)
                    }
                }.padding(.top, 8)
            }.font(.caption)
        }
    }
}
struct AccountView: View {
    let account: Account
    var accent: Color { account.provider == "claude" ? .orange : account.provider == "codex" ? .teal : .purple }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.title).font(.system(size: 15, weight: .semibold))
                    Text(account.email ?? account.name).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(account.status.capitalized).foregroundStyle(account.unavailable ? Color.secondary : Color.green)
                    Text(account.plan).foregroundStyle(.secondary)
                }.font(.caption)
            }
            if account.unavailable { Text("Unavailable for routing · quota is the last reported value").font(.caption).foregroundStyle(.secondary) }
            ForEach(account.windows) { quota in
                VStack(spacing: 5) {
                    HStack {
                        Text(quota.label).font(.caption)
                        Spacer()
                        Text("\(Int((quota.fraction * 100).rounded()))% left").font(.caption.weight(.semibold)).monospacedDigit()
                    }
                    ProgressView(value: quota.fraction).tint(quota.fraction <= 0.1 ? .red : accent)
                        .accessibilityLabel(quota.label).accessibilityValue("\(Int((quota.fraction * 100).rounded())) percent remaining")
                    HStack { Spacer(); Text(resetLabel(quota.resetAt)).font(.system(size: 11)).foregroundStyle(.secondary) }
                }
            }
            if account.windows.isEmpty { Text("Quota not reported by the proxy").font(.caption).foregroundStyle(.secondary) }
            if let billing = account.billing {
                if let balance = billing.prepaidBalanceUsd { detail("Prepaid balance", money(balance)) }
                if let used = billing.onDemandUsedUsd { detail("On-demand used", money(used)) }
                if let limit = billing.onDemandLimitUsd { detail("On-demand limit", money(limit)) }
            }
            if let usage = account.cursorUsage {
                DisclosureGroup("Cursor usage") {
                    VStack(spacing: 8) {
                        detail("Today", money(usage.today.costUsd) + " · " + compact(usage.today.tokens) + " tokens")
                        detail("30 days", money(usage.last30Days.costUsd) + " · " + compact(usage.last30Days.tokens) + " tokens")
                        if let error = usage.error { Text(error).font(.caption).foregroundStyle(.secondary) }
                    }.padding(.top, 8)
                }.font(.caption)
            }
            if let message = account.statusMessage, !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            if let retry = account.nextRetryAfter { Text("Retry: " + retry).font(.caption).foregroundStyle(.secondary) }
        }
    }
    func detail(_ label: String, _ value: String) -> some View {
        HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }.font(.caption)
    }
}
