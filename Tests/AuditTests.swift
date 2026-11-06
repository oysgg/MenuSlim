import Foundation
@main struct AuditTests {
    static func main() {
        func item(_ id: String, _ width: Double = 30, _ gap: Double = 8, _ next: String? = "battery", _ obscured: Bool = false) -> MenuBarMeasurement {
            MenuBarMeasurement(name: id, identity: id, x: 0, y: 0, width: width, height: 24,
                               gapAfter: gap, nextIdentity: next, obscured: obscured)
        }
        func result(_ before: [MenuBarMeasurement], _ after: [MenuBarMeasurement]) -> AuditComparison {
            MenuBarAudit.compare(before, after).first { $0.name == "weather" || $0.name == "unknown:1" }!
        }
        assert(result([item("weather",78)], [item("weather",54)]).status == .changed)
        assert(result([item("weather")], [item("weather")]).status == .unchanged)
        assert(result([item("unknown:1")], [item("unknown:1",50)]).status == .unmeasurable)
        assert(result([item("weather")], [item("weather",50,8,"battery",true)]).status == .unmeasurable)
        assert(result([item("weather"),item("weather")], [item("weather",50)]).status == .unmeasurable)
        assert(result([item("weather")], []).status == .unmeasurable)
        let changedNeighbor = result([item("weather")], [item("weather",30,24,"clock")])
        assert(changedNeighbor.status == .unchanged && changedNeighbor.afterGap == nil)
        assert(result([item("weather"), item("battery")], [item("weather",30,24), item("battery")]).status == .changed)
        print("8 layout comparison cases passed")
    }
}
