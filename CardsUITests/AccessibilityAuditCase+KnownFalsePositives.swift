import XCTest

extension AccessibilityAuditCase {
    /// Keeps a record of an issue the audit ignored as a known false positive,
    /// in the result bundle, whether the test passes or not, so every run says
    /// which exceptions it used: `run-tests.ts` lists them in its summary.
    @MainActor
    func recordIgnored(_ issue: XCUIAccessibilityAuditIssue, line: String) {
        let element = issue.element
        let attachment = XCTAttachment(string: line)
        let what = element?.identifier.nilIfEmpty ?? element?.label ?? "no element"
        attachment.name = "Ignored audit issue: \(Self.checkName(issue.auditType)) \(what)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The audit check's name, as "dynamicType", for the log.
    static func checkName(_ type: XCUIAccessibilityAuditType) -> String {
        let names: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"), (.elementDetection, "elementDetection"), (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"), (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"), (.trait, "trait")
        ]
        return names.first { type.contains($0.0) }?.1 ?? "check \(type.rawValue)"
    }

    /// Elements the Dynamic Type check calls "partially unsupported" on iOS 18
    /// only, at the default size: the Add Location panel's name field, Radius
    /// and the radius itself, on iOS 18.5 (CI, 8 November 2026). The audit's
    /// screen recording shows all three shrink at the smallest size and grow at
    /// every larger one, the name wrapping onto two lines, and the same views
    /// pass on iOS 18.1, 26 and 27.
    static let growsInFullOnIOS18: Set<String> = ["locationNameField", "radiusLabel", "radiusValue"]

    /// Accepted by Paul on 8 November 2026, rather than changing the views
    /// (`growsInFull`): the caption under the Maps menu (SET-5), which the
    /// Dynamic Type check calls "partially unsupported" at the default size on
    /// the iPad mini (A17 Pro) on iOS 26.5 and the iPhone 16 on iOS 18.1, and
    /// the Privacy heading, the same on the iPad only; the iPhone 17 on iOS
    /// 26.5 reports neither. `make capture-l10n` at AX5 on that iPad shows the
    /// caption grown and wrapped on three lines and the heading grown.
    static let growsInFullInSettings: Set<String> = ["mapsAppFooter", "privacySectionHeader"]

    /// Accepted by Paul on 8 November 2026 (`wholeAtTheLargestSize`): Version
    /// and its number at the foot of Settings, which the clipping check says
    /// may be cut off on the iPad mini (A17 Pro) on iOS 26.5 at the default
    /// size. The Arabic audit's screenshot at the largest size on that iPad,
    /// and `make capture-l10n` at AX5 in English, show both grown, stacked and
    /// whole.
    static let wholeAtTheFootOfSettings: Set<String> = ["versionRow"]

    /// Whether the tests are running on iOS 18.
    static var isOnIOS18: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
