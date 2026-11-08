import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Choose Photo and Choose File, under the camera on the add form. Reads the
/// barcode in a screenshot, a photo or a PDF such as an e-ticket, and fills in
/// the card's code and type as a scan does (CARD-13).
///
/// One barcode fills the form at once; several open a list to choose from; none,
/// or only kinds the app cannot show, says so under the buttons.
public struct BarcodeImportSection: View {
    private let actions: BarcodeImportActions
    private let onFound: (FoundBarcode) -> Void
    @Environment(\.accessibilityAnnouncer) private var announcer
    @State private var status: BarcodeImportStatus
    /// The barcodes the list shows, kept while it slides away after a choice.
    @State private var choices: [FoundBarcode]
    @State private var photo: PhotosPickerItem?
    @State private var choosingFile = false
    /// Counts fills, so the success haptic plays each time (A11Y-5).
    @State private var fills = 0

    /// `status` is where it starts, for stories and previews; the app starts `.ready`.
    public init(
        actions: BarcodeImportActions = BarcodeImportActions(),
        status: BarcodeImportStatus = .ready,
        onFound: @escaping (FoundBarcode) -> Void = { _ in }
    ) {
        self.actions = actions
        self.onFound = onFound
        _status = State(initialValue: status)
        if case .choosing(let barcodes) = status {
            _choices = State(initialValue: barcodes)
        } else {
            _choices = State(initialValue: [])
        }
    }

    public var body: some View {
        Section {
            PhotosPicker(selection: $photo, matching: .images) {
                ImportRowLabel(
                    title: Text(
                        "Choose Photo",
                        comment: "Button under the camera in the new card form that opens the photo library to read a barcode from a picture."
                    ),
                    systemImage: "photo.on.rectangle"
                )
            }
            .accessibilityIdentifier("choosePhotoButton")
            .accessibilityHint(
                Text("Reads the barcode in a screenshot or a photo", comment: "VoiceOver hint for the Choose Photo button in the new card form.")
            )

            // The pickers and the list hang off this one row: on the section,
            // SwiftUI would attach them to every row in it.
            Button {
                choosingFile = true
            } label: {
                ImportRowLabel(
                    title: Text(
                        "Choose File",
                        comment: "Button under the camera in the new card form that opens Files to read a barcode from an image or a PDF."
                    ),
                    systemImage: "doc"
                )
            }
            .accessibilityIdentifier("chooseBarcodeFileButton")
            .accessibilityHint(
                Text(
                    "Reads the barcode in an image or a PDF, such as an e-ticket",
                    comment: "VoiceOver hint for the Choose File button in the new card form. PDF is a file format; keep the name."
                )
            )
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.image, .pdf]) { choice in
                read { await actions.readFile(choice) }
            }
            .sheet(isPresented: isChoosing) {
                chooser
            }
        } footer: {
            footer
        }
        .disabled(status == .reading)
        .onChange(of: photo) { _, item in
            guard let item else { return }
            // Cleared, so choosing the same photo again reads it again.
            photo = nil
            read { await actions.readPhoto(item) }
        }
        .sensoryFeedback(.success, trigger: fills)
    }
}

extension BarcodeImportSection {
    @ViewBuilder
    private var footer: some View {
        switch status {
        case .reading:
            HStack(spacing: 8) {
                ProgressView()
                Text(
                    "Reading the barcode…",
                    comment: "Beside a spinner under Choose Photo and Choose File in the new card form, while the chosen photo or file is read."
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("barcodeImportReading")
        case .failed(let reading):
            if let problem = reading.problem {
                Label(problem, systemImage: "exclamationmark.circle")
                    .foregroundStyle(Color.secondaryText)
                    .accessibilityIdentifier("barcodeImportProblem")
            }
        case .ready, .choosing:
            Text(
                "Read the barcode in a screenshot, a photo or a PDF, such as an e-ticket.",
                comment: "Under Choose Photo and Choose File in the new card form, saying what they do. PDF is a file format; keep the name."
            )
            // The app's supporting text, as every footer in the form takes: the
            // system's footer grey is 3.2:1 on the form's background.
            .foregroundStyle(Color.secondaryText)
            .accessibilityIdentifier("barcodeImportHint")
        }
    }

    /// The list of barcodes found, in a sheet. Choosing one fills the form and
    /// closes it; Cancel closes it and fills nothing.
    private var chooser: some View {
        NavigationStack {
            BarcodeChoiceList(barcodes: choices, onChoose: fill)
                .navigationTitle(
                    Text(
                        "Choose a Barcode",
                        comment: "Title of the sheet that lists the barcodes found in a photo or a file, to choose the one for the new card."
                    )
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            status = .ready
                        } label: {
                            Text("Cancel", comment: "Closes the list of barcodes found in a photo or a file without filling in the card form.")
                        }
                        .accessibilityIdentifier("cancelBarcodeChoiceButton")
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    private var isChoosing: Binding<Bool> {
        Binding(
            get: {
                if case .choosing = status { true } else { false }
            },
            set: { shown in
                if !shown, case .choosing = status {
                    status = .ready
                }
            }
        )
    }

    private func read(_ reading: @escaping @MainActor () async -> BarcodeReading) {
        status = .reading
        Task {
            show(await reading())
        }
    }

    private func show(_ reading: BarcodeReading) {
        switch reading {
        case .found(let barcodes) where barcodes.count > 1:
            choices = barcodes
            status = .choosing(barcodes)
        case .found(let barcodes) where barcodes.count == 1:
            fill(barcodes[0])
        case .found:
            fail(.nothing)
        case .nothing, .unsupported, .unreadable:
            fail(reading)
        }
    }

    private func fill(_ barcode: FoundBarcode) {
        status = .ready
        onFound(barcode)
        fills += 1
        announcer.announce(barcode.announcement)
    }

    /// Says under the buttons why nothing was filled in, and tells VoiceOver too.
    private func fail(_ reading: BarcodeReading) {
        status = .failed(reading)
        if let problem = reading.problem {
            announcer.announce(String(localized: problem))
        }
    }
}

/// A row's icon and title. Not a `Label`: in a list row, a Label gives its
/// title the icon's frame for accessibility, and these icons are shorter
/// than a line of text, so the accessibility audit found the title clipped
/// (the add form's other rows have taller icons). The icons share a column
/// that grows with the text, so both titles line up, as a Label's would,
/// and the row's separator starts at the title.
private struct ImportRowLabel: View {
    let title: Text
    let systemImage: String
    /// The rows' icon column, as wide as the widest icon at the text size.
    @ScaledMetric(relativeTo: .body) private var iconWidth = 28.0

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                // The size a list row's Label draws its icon at.
                .imageScale(.large)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            title
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
    }
}

#if DEBUG
#Preview("Ready") {
    Form {
        BarcodeImportSection()
    }
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("No barcode found") {
    Form {
        BarcodeImportSection(status: .failed(.nothing))
    }
    .environment(\.accessibilityAnnouncer, .silent)
}

#Preview("Several found") {
    Form {
        BarcodeImportSection(status: .choosing(FoundBarcode.samples))
    }
    .environment(\.accessibilityAnnouncer, .silent)
}
#endif
