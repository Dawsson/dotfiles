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
        try tests.testCursorUsageCountsTowardTotal()
        try tests.testHeadroomPoolsWeeklyAcrossAllAccounts()
        print("5 model checks passed")
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
    func testCursorUsageCountsTowardTotal() throws {
        let account = try JSONDecoder().decode(Account.self, from: Data(#"{"authIndex":"x","name":"x.json","provider":"xai","email":"hello@dawson.gg","status":"active","unavailable":false,"windows":[],"cursorUsage":{"today":{"costUsd":1.5,"tokens":10},"last30Days":{"costUsd":100,"tokens":1000},"error":null}}"#.utf8))
        let costs = try JSONDecoder().decode(Costs.self, from: Data(#"{"observedAt":"2026-10-20T00:00:00Z","timezone":"UTC","complete":false,"stale":false,"models":[{"model":"priced","tokens":20,"requests":1,"estimatedUsd":2.5,"complete":true}],"daily":[]}"#.utf8))
        XCTAssertEqual(usageTotal(costs, [account]), 102.5)
        XCTAssertEqual(usageToday(costs, [account]), 1.5)
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
}
