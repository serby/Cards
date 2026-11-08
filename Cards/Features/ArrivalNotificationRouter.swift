import UserNotifications

/// Opens the card when an arrival notification is tapped, and still shows the
/// notification if the app is already open.
///
/// The completion-handler forms, not the async ones: iOS wants the handler on
/// the main thread, and the async form's handler is called wherever the method
/// ends, which crashed the app when a notification was tapped (UIKit asserts
/// from `_performBlockAfterCATransactionCommitSynchronizes:`).
@MainActor
public final class ArrivalNotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    private let openCard: (String) -> Void

    public init(openCard: @escaping (String) -> Void) {
        self.openCard = openCard
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let code = Self.code(in: response.notification.request.content.userInfo)
        // The SDK doesn't mark the handler Sendable; it is only called here, on the main actor.
        nonisolated(unsafe) let completionHandler = completionHandler
        Task { @MainActor in
            if let code {
                self.openCard(code)
            }
            completionHandler()
        }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    /// The card's code in an arrival notification's user info, if it has one.
    nonisolated static func code(in userInfo: [AnyHashable: Any]) -> String? {
        userInfo[ArrivalAlert.codeKey] as? String
    }
}
