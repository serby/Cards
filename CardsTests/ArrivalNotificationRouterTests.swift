@testable import Cards
import Testing

/// ARR-2: tapping an arrival notification opens its card, found by the code the
/// notification carries.
struct ArrivalNotificationRouterTests {
    @Test func aNotificationNamesItsCardByCode() {
        #expect(ArrivalNotificationRouter.code(in: [ArrivalAlert.codeKey: "482019375610284"]) == "482019375610284")
    }

    @Test func aNotificationWithoutACodeOpensNothing() {
        #expect(ArrivalNotificationRouter.code(in: [:]) == nil)
        #expect(ArrivalNotificationRouter.code(in: [ArrivalAlert.codeKey: 42]) == nil)
    }
}
