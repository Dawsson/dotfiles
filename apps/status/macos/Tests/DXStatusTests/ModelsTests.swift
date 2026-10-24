import Foundation
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b) }
func XCTAssertFalse(_ a: Bool) { precondition(!a) }
func XCTAssertTrue(_ a: Bool) { precondition(a) }
func XCTAssertNil<T>(_ a: T?) { precondition(a == nil) }

@main struct ModelsTests {
    static func main() throws {
        let tests = ModelsTests()
        try tests.testQuotaClampingAndMissingReset()
        try tests.testUnknownCostIsNotZeroOrComplete()
        try tests.testMissingPlanAndDisabledAccountPreserved()
        try tests.testProxyTotalsExcludeCursorUsage()
        try tests.testHeadroomPoolsWeeklyAcrossAllAccounts()
        try tests.testForecastAndStaleness()
        tests.testRecentTokenRate()
        print("7 model checks passed")
    }
    func testRecentTokenRate() {
        var rate = TokenRate()
        let start = Date(timeIntervalSince1970: 1000)
        func record(_ tokens: Double, _ seconds: Double) {
            let at = start.addingTimeInterval(seconds)
            rate.record(tokens: tokens, at: at, now: at)
        }
        record(1000, 0); XCTAssertNil(rate.perMinute)
        record(1600, 60); XCTAssertEqual(rate.perMinute, 600)
        record(1600, 60); XCTAssertEqual(rate.perMinute, 600)
        record(1600, 120); XCTAssertEqual(rate.perMinute, 0)
        record(2000, 3720); XCTAssertNil(rate.perMinute) // Never average an hour away.
        record(2700, 3790); XCTAssertEqual(rate.perMinute, 600)
        record(100, 3850); XCTAssertNil(rate.perMinute) // Corrected history.
        rate.reset(); record(1000, 3910); XCTAssertNil(rate.perMinute)
        rate.record(tokens: 2000, at: start, now: start.addingTimeInterval(120))
        XCTAssertNil(rate.perMinute)
    }
    func testQuotaClampingAndMissingReset() throws {
        let quota = try JSONDecoder().decode(Quota.self, from: Data(#"{"id":"week","label":"Weekly","remaining":-0.2,"cap":1,"resetAt":null}"#.utf8))
        XCTAssertEqual(quota.fraction, 0)
        XCTAssertEqual(resetLabel(quota.resetAt), "Reset not reported")
        XCTAssertEqual(resetLabel("2020-01-01T00:00:00Z"), "Reset pending update")
    }
    func testUnknownCostIsNotZeroOrComplete() throws {
        let costs = try JSONDecoder().decode(Costs.self, from: Data(#"{"observedAt":"2026-10-20T00:00:00Z","timezone":"UTC","complete":false,"stale":false,"models":[{"model":"priced","tokens":20,"requests":1,"estimatedUsd":2.5,"complete":true},{"model":"unknown","tokens":10,"requests":1,"estimatedUsd":null,"complete":false}],"daily":[]}"#.utf8))
        XCTAssertEqual(costs.total, 2.5)
        XCTAssertEqual(costs.tokens, 30)
        XCTAssertFalse(costs.complete)
        XCTAssertNil(costs.models.last?.estimatedUsd)
    }
    func testMissingPlanAndDisabledAccountPreserved() throws {
        let account = try JSONDecoder().decode(Account.self, from: Data(#"{"authIndex":"test","name":"account.json","provider":"codex","email":"test@example.com","status":"disabled","unavailable":true,"windows":[]}"#.utf8))
        XCTAssertEqual(account.plan, "Plan not reported")
        XCTAssertTrue(account.unavailable)
        XCTAssertEqual(account.title, "Codex")
    }
    func testProxyTotalsExcludeCursorUsage() throws {
        let account = try JSONDecoder().decode(Account.self, from: Data(#"{"authIndex":"x","name":"x.json","provider":"xai","email":"hello@dawson.gg","status":"active","unavailable":false,"windows":[],"cursorUsage":{"today":{"costUsd":1.5,"tokens":10},"last30Days":{"costUsd":100,"tokens":1000},"error":null}}"#.utf8))
        let costs = try JSONDecoder().decode(Costs.self, from: Data(#"{"observedAt":"2026-10-20T00:00:00Z","timezone":"UTC","complete":false,"stale":false,"models":[{"model":"priced","tokens":20,"requests":1,"estimatedUsd":2.5,"complete":true}],"daily":[]}"#.utf8))
        XCTAssertEqual(costs.total, 2.5)
        XCTAssertEqual(account.cursorCost, 100)
        XCTAssertEqual(account.shortEmail, "hel…@dawson.gg")
    }
    func testHeadroomPoolsWeeklyAcrossAllAccounts() throws {
        func account(_ id: String, _ unavailable: Bool, _ windows: [(String, Double, Double)]) throws -> Account {
            let json = windows.map { #"{"id":"\#($0.0)","label":"\#($0.0)","remaining":\#($0.1),"cap":\#($0.2),"resetAt":null}"# }.joined(separator: ",")
            return try JSONDecoder().decode(Account.self, from: Data(#"{"authIndex":"\#(id)","name":"\#(id)","provider":"claude","status":"x","unavailable":\#(unavailable),"windows":[\#(json)]}"#.utf8))
        }
        let accounts = [
            try account("a", false, [("5-hour limit", 0, 1), ("7-day limit", 0.2, 1), ("7-day Fable", 1, 1)]),
            try account("b", true, [("7-day limit", 3, 3), ("Cloud session credits", 0, 1)]),
        ]
        let headroom = Headroom.from(accounts)
        XCTAssertEqual(headroom.count, 1)
        XCTAssertTrue(abs(headroom[0].fraction - 0.8) < 1e-9)
        XCTAssertEqual(accounts[0].shownWindows.map(\.label), ["5-hour limit", "7-day limit"])
        XCTAssertEqual(accounts[1].shownWindows.map(\.label), ["7-day limit"])
    }
    func testForecastAndStaleness() throws {
        let now = instant("2026-10-20T12:00:00Z")!
        func quota(_ remaining: Double, _ reset: String?, label: String = "7-day limit") -> Quota {
            Quota(id: "w", label: label, remaining: remaining, cap: 1, resetAt: reset)
        }
        // One day into a week: 35% spent exceeds the expected 14.3%.
        let fast = usagePace(quota(0.65, "2026-10-26T12:00:00Z"), now: now)!
        XCTAssertTrue(abs(fast.expectedRemaining - 6.0 / 7) < 1e-9)
        XCTAssertFalse(fast.lastsUntilReset)
        XCTAssertEqual(fast.outlook, "Runs out in 1d 20h")
        XCTAssertEqual(fast.balance, "21% in deficit")
        let slow = usagePace(quota(0.92, "2026-10-26T12:00:00Z"), now: now)!
        XCTAssertTrue(slow.lastsUntilReset)
        XCTAssertNil(slow.eta)
        XCTAssertEqual(slow.outlook, "Lasts until reset")
        XCTAssertNil(usagePace(quota(0.5, nil), now: now))
        XCTAssertNil(usagePace(quota(0.5, "2026-10-20T11:00:00Z"), now: now))
        XCTAssertNil(usagePace(quota(0.5, "2026-10-28T12:00:00Z"), now: now))
        XCTAssertNil(usagePace(quota(0.5, "2026-10-26T12:00:00Z", label: "Unknown"), now: now))
        XCTAssertFalse(usagePace(quota(1, "2026-10-20T16:59:00Z", label: "5-hour limit"), now: now)!.showOutlook)
        XCTAssertEqual(usagePace(quota(0, "2026-10-26T12:00:00Z"), now: now)!.outlook, "Runs out now")
        XCTAssertEqual(shortDuration(7 * 3600 + 41 * 60), "7h 41m")
        XCTAssertTrue(isStale(observedAt: "2026-10-20T11:40:00Z", now: now))
        XCTAssertFalse(isStale(observedAt: "2026-10-20T11:58:00Z", now: now))
        let credits = try JSONDecoder().decode(ResetCredits.self, from: Data(#"{"available":2,"credits":[{"status":"used","expiresAt":"2026-10-21T00:00:00Z"},{"status":"available","expiresAt":"2026-10-29T00:00:00Z"},{"status":"available","expiresAt":"2026-10-22T00:00:00Z"}]}"#.utf8))
        XCTAssertEqual(credits.nextExpiry, instant("2026-10-22T00:00:00Z"))
    }
}
