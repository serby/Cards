@testable import Cards
import CoreLocation
import Foundation
import Testing
import UserNotifications

/// The requests the live notification client hands iOS, built here without
/// adding them, so nothing is scheduled or delivered.
struct NotificationClientTests {
    private let boulderBarn = CardLocation(name: "Boulder Barn", latitude: 51.5203, longitude: -0.2094, radius: 150)

    private var alert: ArrivalAlert {
        ArrivalAlert(
            id: "arrival.boulderbarn",
            title: "Climbing",
            body: "You're at Boulder Barn. Your barcode is ready.",
            code: "climb-42",
            barcodePNG: BarcodeImage.pngOnWhite("climb-42", type: .code128),
            place: boulderBarn
        )
    }

    @Test func aDelayedAlertFiresOnceAfterItsDelay() throws {
        let request = NotificationClient.request(for: alert, trigger: NotificationClient.delayTrigger(5))
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(trigger.timeInterval == 5)
        #expect(!trigger.repeats)
    }

    @Test func anArrivalFiresEachTimeYouEnterThePlace() throws {
        let request = NotificationClient.request(for: alert, trigger: NotificationClient.arrivalTrigger(for: boulderBarn))
        let trigger = try #require(request.trigger as? UNLocationNotificationTrigger)
        let region = try #require(trigger.region as? CLCircularRegion)
        #expect(trigger.repeats)
        #expect(region.notifyOnEntry)
        #expect(!region.notifyOnExit)
        #expect(region.identifier == boulderBarn.id.uuidString)
        #expect(region.radius == 150)
        #expect(region.center.latitude == 51.5203)
        #expect(region.center.longitude == -0.2094)
    }

    @Test func aDelayedAlertSaysWhatAnArrivalSays() {
        let arrival = NotificationClient.request(for: alert, trigger: NotificationClient.arrivalTrigger(for: boulderBarn))
        let delayed = NotificationClient.request(for: alert, trigger: NotificationClient.delayTrigger(5))
        for request in [arrival, delayed] {
            #expect(request.identifier == "arrival.boulderbarn")
            #expect(request.content.title == "Climbing")
            #expect(request.content.body == "You're at Boulder Barn. Your barcode is ready.")
            #expect(request.content.threadIdentifier == "climb-42")
            // What the router reads to open the card when the notification is tapped.
            #expect(request.content.userInfo[ArrivalAlert.codeKey] as? String == "climb-42")
            #expect(request.content.sound == .default)
            #expect(request.content.attachments.map(\.identifier) == ["barcode"])
        }
    }
}
