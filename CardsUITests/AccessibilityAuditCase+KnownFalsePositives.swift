import Foundation

extension AccessibilityAuditCase {
    /// The rows at the foot of Settings since it gained iCloud, Privacy and
    /// Acknowledgements (DATA-8, PLAT-11, PLAT-12): the library rows, the
    /// Acknowledgements footer and Version with its number. At the default
    /// size the check calls them "unsupported" and "may be clipped"; the
    /// right-to-left audit's screenshot at the largest size shows all of them
    /// grown and whole, the footer wrapped on six lines, as the rows below
    /// them were before (`growsInFull`, `wholeAtTheLargestSize`).
    static let atTheFootOfSettings: Set<String> = ["libraryRow", "acknowledgementsFooter", "versionRow"]

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
