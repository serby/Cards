import UserNotifications

/// Opens the card when an arrival notification is tapped, and still shows the
/// notification if the app is already open.
@MainActor
public final class ArrivalNotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let openCard: (String) -> Void

    public init(openCard: @escaping (String) -> Void) {
        self.openCard = openCard
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let code = response.notification.request.content.userInfo[ArrivalAlert.codeKey] as? String else {
            return
        }
        await open(code)
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    private func open(_ code: String) {
        openCard(code)
    }
}
