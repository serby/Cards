import SwiftUI

/// Choose Photo and Choose File. The pickers are real, so a photo or file can
/// be chosen, but the stand-in reader gives back what the Reads knob says.
@MainActor
let barcodeImportStory = Story(
    id: "barcode-import",
    title: "BarcodeImportSection",
    section: "Components",
    galleryLayout: .oneAtATime,
    knobs: [
        .options("Status", BarcodeImportKind.allCases.map(\.rawValue), BarcodeImportKind.ready.rawValue),
        .options("Reads", StoryReading.allCases.map(\.rawValue), StoryReading.one.rawValue)
    ],
    gallery: BarcodeImportKind.allCases.map { kind in
        (name: kind.rawValue, view: AnyView(barcodeImportForm(status: kind.status, reads: .one)))
    }
) { knobs in
    let kind = BarcodeImportKind(rawValue: knobs.option("Status")) ?? .ready
    let reads = StoryReading(rawValue: knobs.option("Reads")) ?? .one
    // The status is where the section starts, so a new one rebuilds it.
    return AnyView(barcodeImportForm(status: kind.status, reads: reads).id("\(kind.rawValue) \(reads.rawValue)"))
}

/// The list of barcodes to choose from, as the sheet shows it.
@MainActor
let barcodeChoiceStory = Story(
    id: "barcode-choice-list",
    title: "BarcodeChoiceList",
    section: "Components",
    knobs: [
        .number("Barcodes", 2, in: 1...Double(FoundBarcode.samples.count), step: 1),
        .toggle("A long code", false)
    ],
    gallery: [
        (name: "Two barcodes", view: AnyView(BarcodeChoiceList(barcodes: Array(FoundBarcode.samples.prefix(2))).frame(height: 240))),
        (name: "A long code first", view: AnyView(BarcodeChoiceList(barcodes: [.longCode] + FoundBarcode.samples).frame(height: 400)))
    ]
) { knobs in
    let barcodes = (knobs.bool("A long code") ? [.longCode] : []) + FoundBarcode.samples.prefix(knobs.integer("Barcodes"))
    return AnyView(BarcodeChoiceList(barcodes: barcodes))
}

/// The section in a form, as the add form shows it, with what it filled in below.
@MainActor
private func barcodeImportForm(status: BarcodeImportStatus, reads: StoryReading) -> some View {
    Stateful(FoundBarcode?.none) { filled in
        Form {
            BarcodeImportSection(actions: .always(reads.reading), status: status) { filled.wrappedValue = $0 }
            Section {
                LabeledContent {
                    Text(verbatim: filled.wrappedValue?.code ?? "Nothing yet")
                } label: {
                    Text(verbatim: "Code")
                }
                LabeledContent {
                    Text(verbatim: filled.wrappedValue?.type.rawValue ?? "Nothing yet")
                } label: {
                    Text(verbatim: "Type")
                }
            } header: {
                Text(verbatim: "Filled in")
            }
        }
        .environment(\.accessibilityAnnouncer, .silent)
    }
}

/// Where the section starts, for the Status knob.
private enum BarcodeImportKind: String, CaseIterable {
    case ready = "Ready"
    case reading = "Reading"
    case choosing = "Several found"
    case nothing = "No barcode"
    case unsupported = "Data Matrix only"
    case unreadable = "Could not open"

    var status: BarcodeImportStatus {
        switch self {
        case .ready:
            .ready
        case .reading:
            .reading
        case .choosing:
            .choosing(FoundBarcode.samples)
        case .nothing:
            .failed(.nothing)
        case .unsupported:
            .failed(.unsupported(["Data Matrix"]))
        case .unreadable:
            .failed(.unreadable)
        }
    }
}

/// What the stand-in reader finds in any photo or file, for the Reads knob.
private enum StoryReading: String, CaseIterable {
    case one = "One barcode"
    case several = "Several barcodes"
    case nothing = "No barcode"
    case unsupported = "A Data Matrix code"
    case unreadable = "Not a picture or PDF"

    var reading: BarcodeReading {
        switch self {
        case .one:
            .found([FoundBarcode.samples[1]])
        case .several:
            .found(FoundBarcode.samples)
        case .nothing:
            .nothing
        case .unsupported:
            .unsupported(["Data Matrix"])
        case .unreadable:
            .unreadable
        }
    }
}
