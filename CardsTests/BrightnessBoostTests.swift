@testable import Cards
import SwiftUI
import Testing

/// Brightness Boost turns the screen up at once and puts back what it found (BAR-4).
@MainActor
struct BrightnessBoostTests {
    @Test func startingGoesToFullAndEndingPutsTheBrightnessBack() {
        let box = BrightnessBox(level: 0.3)
        let screen = ScreenBrightness.simulated(box)
        var boost = BrightnessBoost()
        boost.start(on: screen)
        #expect(box.level == 1)
        #expect(boost.isOn)
        boost.end(on: screen)
        #expect(box.level == 0.3)
        #expect(!boost.isOn)
    }

    /// Opening a card and the app becoming active can both start it.
    @Test func startingTwiceStillPutsBackTheFirstBrightness() {
        let box = BrightnessBox(level: 0.4)
        let screen = ScreenBrightness.simulated(box)
        var boost = BrightnessBoost()
        boost.start(on: screen)
        boost.start(on: screen)
        boost.end(on: screen)
        #expect(box.level == 0.4)
    }

    /// Leaving the app and then closing the card ends it twice: the second
    /// leaves alone a brightness set meanwhile, which the next boost keeps.
    @Test func endingTwiceLeavesALaterBrightnessAlone() {
        let box = BrightnessBox(level: 0.6)
        let screen = ScreenBrightness.simulated(box)
        var boost = BrightnessBoost()
        boost.start(on: screen)
        boost.end(on: screen)
        box.level = 0.2
        boost.end(on: screen)
        #expect(box.level == 0.2)
        boost.start(on: screen)
        boost.end(on: screen)
        #expect(box.level == 0.2)
    }

    /// Leaving the app with a card open puts the brightness back, and coming
    /// back turns it up again, the bug 1.4 had.
    @Test(arguments: [ScenePhase.inactive, .background])
    func leavingTheAppPutsTheBrightnessBack(_ phase: ScenePhase) {
        let box = BrightnessBox(level: 0.35)
        let screen = ScreenBrightness.simulated(box)
        var boost = BrightnessBoost()
        boost.start(on: screen)
        boost.follow(phase, enabled: true, on: screen)
        #expect(box.level == 0.35)
        box.level = 0.5
        boost.follow(.active, enabled: true, on: screen)
        #expect(box.level == 1)
        boost.end(on: screen)
        #expect(box.level == 0.5)
    }

    @Test func comingBackWithTheBoostOffLeavesTheBrightnessAlone() {
        let box = BrightnessBox(level: 0.35)
        var boost = BrightnessBoost()
        boost.follow(.active, enabled: false, on: .simulated(box))
        #expect(box.level == 0.35)
        #expect(!boost.isOn)
    }
}
