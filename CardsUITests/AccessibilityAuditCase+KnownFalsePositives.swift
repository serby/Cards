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

    /// Text the clipping check says may be cut off at larger sizes, since the
    /// tests run on iOS 26 and 27, which the largest-size screenshots show
    /// grown and whole (`growsInFull`): Delete Card and Created by, the last
    /// rows of a screen scrolled to its end, and the add form's Locations
    /// heading, on iOS 26 only; and a card's notes and the form's Notes
    /// caption, whole and wrapped at the largest size (Paul agreed, 8 November 2026).
    static let wholeAtTheLargestSize = Set([
        "deleteCardButton", "authorLink", "locationsSectionHeader", "cardNotesText", "notesFooter"
    ]).union(wholeAtTheFootOfSettings)

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

    /// Accepted by Paul on 9 November 2026: an empty field's prompt
    /// (`wrappingPrompt`), which the contrast check failed on the iPad mini
    /// (A17 Pro) on iOS 26.5 in CI run 42605129365, on both attempts: the
    /// Notes prompt "Add a note" at the end of Add Card. The audit's own
    /// screenshot measures it #636366 on #FFFFFF, 6.0:1, the footer below it
    /// in the same colour passes, and so does the same prompt on the iPhone
    /// on iOS 26.5. Most likely the check measures it through the empty text
    /// field drawn over it (`WrappingPrompt`).
    static let readableUnderTheirField: Set<String> = ["wrappingPrompt"]

    /// Accepted by Paul on 9 November 2026: text the Dynamic Type check calls
    /// "partially unsupported" on the iPad mini (A17 Pro) on iOS 26.5 in CI run
    /// 42649546139, on both attempts, though the audit's own element
    /// screenshots show it grown. In Arabic at the largest size, on a card's
    /// screen: the Notes heading and text, the card's name and the distance to
    /// the nearest place, all at that size and wrapped. At the default size, on
    /// the edit form: the barcode type's value ("EAN-13") and the Notes field,
    /// standard SwiftUI text the same audit passes on the iPhone.
    static let growsInFullOnTheIPadIdentifiers: Set<String> = [
        "cardNotesHeading", "cardNotesText", "cardNameText", "notesTextField"
    ]

    /// Whether `element` is one of `growsInFullOnTheIPadIdentifiers`, or the
    /// text inside the nearest-place link or the barcode type menu, which the
    /// check reports with no identifier. The link reaches 13 pt above and below
    /// its text (`CardFaceView.linkReach`), so the text may sit that far out.
    @MainActor
    static func growsInFullOnTheIPad(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if growsInFullOnTheIPadIdentifiers.contains(element.identifier) { return true }
        let frame = element.frame
        return ["cardProximityText", "barcodeTypePicker"].contains { identifier in
            app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex.contains { container in
                container.frame.insetBy(dx: -14, dy: -14).contains(frame)
            }
        }
    }

    /// Accepted by Paul on 9 November 2026: an element that runs past the edge
    /// of the screen, whose contrast the check measures from pixels that are
    /// not there. In CI run 42649546139, on the iPad mini (A17 Pro) on iOS
    /// 26.5, in Arabic at the largest size, it failed "Add current location"
    /// at the foot of a card's screen on both attempts (and on 522da74): its
    /// frame runs from y 1121 to 1179.5 pt on a screen 1133 pt tall, and the
    /// audit's screenshot of it is half solid black.
    @MainActor
    static func isPartlyOffScreen(_ frame: CGRect, in app: XCUIApplication) -> Bool {
        !app.frame.insetBy(dx: -0.5, dy: -0.5).contains(frame)
    }

    /// The checks left out at the end of the Add Card form, Notes on screen, on
    /// iOS 18 only. There the contrast check takes the whole 15 s the audit is
    /// given and fails "Audit failed to complete in time", every attempt, with
    /// no issue found first; at the top of the form it takes 1.7 s, and every
    /// other named check takes under 3 s at the end (timed one check at a time
    /// on an iPhone 16 with iOS 18.1, and seen on CI's iOS 18.5 run
    /// 42605129365). It still runs there on iOS 26.5 and 27, and at the top of
    /// the form on 18. Paul agreed on 9 Nov 2026.
    static var skippedAtTheAddFormsEnd: XCUIAccessibilityAuditType {
        isOnIOS18 ? .contrast : []
    }

    /// Notes `skipped` checks as ignored audit issues, so the run's summary
    /// lists them with the other exceptions.
    func recordSkipped(_ skipped: XCUIAccessibilityAuditType) {
        let attachment = XCTAttachment(string: "AUDIT[\(name)] skipped \(Self.checkName(skipped))")
        attachment.name = "Ignored audit issue: \(Self.checkName(skipped)) check skipped"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Whether the tests are running on iOS 18.
    static var isOnIOS18: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
