import CoreLocation
import SwiftUI
import UserNotifications

/// The local notifications the app schedules, injected so the arrival schedule
/// can be tested without iOS delivering anything.
public struct NotificationClient: Sendable {
    /// Schedules `alert` to show each time you enter its place.
    public var add: @MainActor @Sendable (ArrivalAlert) async throws -> Void
    /// Schedules `alert` to show once, after a delay in seconds (more than
    /// zero), wherever you are. The request takes the alert's `id`, so an alert
    /// with a watched place's id would replace that place's arrival.
    public var addAfter: @MainActor @Sendable (ArrivalAlert, TimeInterval) async throws -> Void
    /// Cancels every notification that has not been delivered yet.
    public var removeAllPending: @MainActor @Sendable () -> Void
    /// Asks to show alerts and play sounds, prompting only the first time.
    /// True if they are allowed.
    public var requestAuthorization: @MainActor @Sendable () async throws -> Bool
    /// Whether the app may notify, as set in the Settings app.
    public var authorizationStatus: @MainActor @Sendable () async -> UNAuthorizationStatus

    public init(
        add: @escaping @MainActor @Sendable (ArrivalAlert) async throws -> Void,
        addAfter: @escaping @MainActor @Sendable (ArrivalAlert, TimeInterval) async throws -> Void,
        removeAllPending: @escaping @MainActor @Sendable () -> Void,
        requestAuthorization: @escaping @MainActor @Sendable () async throws -> Bool,
        authorizationStatus: @escaping @MainActor @Sendable () async -> UNAuthorizationStatus
    ) {
        self.add = add
        self.addAfter = addAfter
        self.removeAllPending = removeAllPending
        self.requestAuthorization = requestAuthorization
        self.authorizationStatus = authorizationStatus
    }
}

public extension NotificationClient {
    /// The device's notification centre.
    static let live = Self(
        add: { alert in
            try await UNUserNotificationCenter.current().add(request(for: alert, trigger: arrivalTrigger(for: alert.place)))
        },
        addAfter: { alert, delay in
            try await UNUserNotificationCenter.current().add(request(for: alert, trigger: delayTrigger(delay)))
        },
        removeAllPending: {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        },
        requestAuthorization: {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        },
        authorizationStatus: {
            await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    )
}

extension NotificationClient {
    /// `alert` as a request that shows when `trigger` fires. The content is the
    /// same whatever the trigger, so a delayed alert looks like an arrival.
    static func request(for alert: ArrivalAlert, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.threadIdentifier = alert.code
        content.userInfo = [ArrivalAlert.codeKey: alert.code]
        content.relevanceScore = 1
        content.sound = .default
        if let attachment = attachment(alert.barcodePNG) {
            content.attachments = [attachment]
        }
        return UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
    }

    /// Fires each time you enter `place`, never on leaving it.
    static func arrivalTrigger(for place: CardLocation) -> UNLocationNotificationTrigger {
        let region = CLCircularRegion(center: place.coordinate, radius: place.radius, identifier: place.id.uuidString)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return UNLocationNotificationTrigger(region: region, repeats: true)
    }

    /// Fires once, `delay` seconds from now.
    static func delayTrigger(_ delay: TimeInterval) -> UNTimeIntervalNotificationTrigger {
        UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    }

    /// The barcode as an image file. iOS moves the file into its own store when
    /// the request is added, so each request gets a fresh one.
    private static func attachment(_ png: Data?) -> UNNotificationAttachment? {
        guard let png else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("barcode-\(UUID().uuidString).png")
        guard (try? png.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "barcode", url: url)
    }
}

private struct NotificationClientKey: EnvironmentKey {
    static let defaultValue = NotificationClient.live
}

public extension EnvironmentValues {
    /// The notification client, for screens that schedule a notification
    /// themselves rather than through `ArrivalScheduler`.
    var notificationClient: NotificationClient {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
}
