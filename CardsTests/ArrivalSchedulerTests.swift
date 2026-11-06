@testable import Cards
import CoreLocation
import Foundation
import Testing
import UserNotifications

/// The arrival schedule, driven through a stand-in notification client, so
/// nothing is scheduled with iOS and nothing waits on a real delivery.
@MainActor
struct ArrivalSchedulerTests {
    private let westway = CardLocation(name: "Westway", latitude: 51.5203, longitude: -0.2094, radius: 150)
    private let wembley = CardLocation(name: "IKEA Wembley", latitude: 51.5560, longitude: -0.2796, radius: 400)
    private let library = CardLocation(name: "Library", latitude: 51.5091, longitude: -0.1963)
    private let notifications = NotificationCenterStandIn()

    private func card(_ name: String, _ locations: [CardLocation], notifies: Bool = true) -> ArrivalPlan.Card {
        ArrivalPlan.Card(name: name, code: name.lowercased(), barcodeType: .code128, locations: locations, notifies: notifies)
    }

    private func scheduler() -> ArrivalScheduler {
        ArrivalScheduler(notifications: notifications.client)
    }

    @Test func addsOneRequestPerPlannedPlace() async {
        await scheduler().reschedule([card("Climbing", [westway, wembley]), card("Library", [library])], near: nil)
        #expect(notifications.added.map(\.place) == [westway, wembley, library])
        #expect(notifications.added.map(\.id) == [westway, wembley, library].map { "arrival.\($0.id.uuidString)" })
        #expect(notifications.added.map(\.code) == ["climbing", "climbing", "library"])
    }

    @Test func doesNothingWhenThePlacesToWatchHaveNotChanged() async {
        let scheduler = scheduler()
        let cards = [card("Climbing", [westway, wembley])]
        await scheduler.reschedule(cards, near: nil)
        await scheduler.reschedule(cards, near: nil)
        // Moving reorders the places, but the same ones are still watched.
        await scheduler.reschedule(cards, near: CLLocation(latitude: 51.5560, longitude: -0.2796))
        #expect(notifications.removals == 1)
        #expect(notifications.authorizationRequests == 1)
        #expect(notifications.added.count == 2)
    }

    @Test func removesThePendingRequestsWhenThePlacesChange() async {
        let scheduler = scheduler()
        await scheduler.reschedule([card("Climbing", [westway])], near: nil)
        await scheduler.reschedule([card("Climbing", [westway, wembley])], near: nil)
        #expect(notifications.removals == 2)
        #expect(notifications.added.map(\.place) == [westway, westway, wembley])
    }

    @Test func removesThePendingRequestsWhenNothingIsLeftToWatch() async {
        let scheduler = scheduler()
        await scheduler.reschedule([card("Climbing", [westway])], near: nil)
        await scheduler.reschedule([], near: nil)
        #expect(notifications.removals == 2)
        #expect(notifications.authorizationRequests == 1)
        #expect(notifications.added.count == 1)
    }

    @Test func clearsWhatAnEarlierLaunchScheduledEvenWithNothingToWatch() async {
        await scheduler().reschedule([card("Library", [])], near: nil)
        #expect(notifications.removals == 1)
        #expect(notifications.added.isEmpty)
    }

    @Test func asksForPermissionOnlyWhenThereIsSomethingToSchedule() async {
        let scheduler = scheduler()
        await scheduler.reschedule([card("Library", []), card("Pool", [westway], notifies: false)], near: nil)
        #expect(notifications.authorizationRequests == 0)
        await scheduler.reschedule([card("Library", [library])], near: nil)
        #expect(notifications.authorizationRequests == 1)
    }

    @Test func addsNothingWithoutPermission() async {
        notifications.allowed = false
        await scheduler().reschedule([card("Climbing", [westway])], near: nil)
        #expect(notifications.authorizationRequests == 1)
        #expect(notifications.added.isEmpty)
    }

    @Test(arguments: [
        (UNAuthorizationStatus.denied, true),
        (.authorized, false),
        (.notDetermined, false),
        (.provisional, false)
    ])
    func blockedInSettingsFollowsTheAuthorisationStatus(status: UNAuthorizationStatus, blocked: Bool) async {
        notifications.status = status
        #expect(await scheduler().isBlockedInSettings() == blocked)
    }
}

/// Records what the scheduler asks of the notification centre, and answers as
/// each test sets it up.
@MainActor
private final class NotificationCenterStandIn {
    var added: [ArrivalAlert] = []
    var removals = 0
    var authorizationRequests = 0
    var allowed = true
    var status: UNAuthorizationStatus = .notDetermined

    var client: NotificationClient {
        NotificationClient(
            add: { [self] alert in added.append(alert) },
            removeAllPending: { [self] in removals += 1 },
            requestAuthorization: { [self] in
                authorizationRequests += 1
                return allowed
            },
            authorizationStatus: { [self] in status }
        )
    }
}
