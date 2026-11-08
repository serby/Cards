import Foundation

extension AccessibilityAuditCase {
    /// Elements the Dynamic Type check calls "partially unsupported" on iOS 18
    /// only, at the default size: the Add Location panel's name field, Radius
    /// and the radius itself, on iOS 18.5 (CI, 8 November 2026). The audit's
    /// screen recording shows all three shrink at the smallest size and grow at
    /// every larger one, the name wrapping onto two lines, and the same views
    /// pass on iOS 18.1, 26 and 27.
    static let growsInFullOnIOS18: Set<String> = ["locationNameField", "radiusLabel", "radiusValue"]

    /// Whether the tests are running on iOS 18.
    static var isOnIOS18: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
    }
}
