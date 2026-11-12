import UIKit

public extension UIScreen {
    /// The screen the app is on: its active scene's, or else one that is on
    /// its way in or out of the foreground, as when the app is leaving and
    /// puts the brightness back (BAR-4), or else any of its scenes'.
    static var current: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let order: [UIScene.ActivationState] = [.foregroundActive, .foregroundInactive, .background]
        return order.lazy.compactMap { state in scenes.first { $0.activationState == state } }.first?.screen
            ?? scenes.first?.screen
    }
}
