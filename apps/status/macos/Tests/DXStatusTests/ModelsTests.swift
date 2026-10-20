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
        print("3 model checks passed")
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
}
