import SwiftUI
import UniformTypeIdentifiers

/// The Import JSON sheet: paste an export, or choose one in the Files picker.
/// The chosen file is handed on to be read, not read here.
public struct ImportCardsView: View {
    @Binding private var importText: String
    private let readClipboard: () -> String?
    private let onImport: () -> Void
    private let onChooseFile: (Result<URL, any Error>) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var choosingFile = false

    public init(
        importText: Binding<String>,
        readClipboard: @escaping () -> String? = { nil },
        onImport: @escaping () -> Void,
        onChooseFile: @escaping (Result<URL, any Error>) -> Void = { _ in }
    ) {
        _importText = importText
        self.readClipboard = readClipboard
        self.onImport = onImport
        self.onChooseFile = onChooseFile
    }

    public var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .readsLeftToRight()
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    // Outside readsLeftToRight(), so the prompt follows the language.
                    .overlay(alignment: .topLeading) {
                        if importText.isEmpty {
                            Text(
                                "Paste exported JSON here",
                                comment: "Prompt in the empty text box of the import sheet. JSON is a file format; keep the name."
                            )
                                .foregroundStyle(Color.secondaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityLabel(
                        Text("JSON to import", comment: "VoiceOver label for the text box in the import sheet. JSON is a file format; keep the name.")
                    )
                    .accessibilityIdentifier("importTextEditor")
                    .padding()

                sourceButtonsLayout {
                    Button {
                        if let clipboard = readClipboard() {
                            importText = clipboard
                        }
                    } label: {
                        Text("Paste from Clipboard", comment: "Button in the import sheet that fills the text box with what was last copied.")
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("pasteFromClipboardButton")

                    Button {
                        choosingFile = true
                    } label: {
                        Text("Choose File", comment: "Button in the import sheet that opens the Files picker to choose a file of exported cards.")
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("chooseFileButton")
                    .accessibilityHint(
                        Text(
                            "Imports the cards in a JSON file",
                            comment: "VoiceOver hint for the Choose File button in the import sheet. JSON is a file format; keep the name."
                        )
                    )
                }
                // Plain accent text: on the bordered style's pink wash the accent
                // falls to 4:1.
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accent)
                .padding()
            }
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json], onCompletion: onChooseFile)
            .navigationTitle(Text("Import JSON", comment: "Title of the sheet for pasting cards exported as JSON."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the import sheet without importing.")
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onImport) {
                        Text("Import", comment: "Toolbar button in the import sheet that adds the pasted cards. A verb.")
                    }
                    .disabled(importText.isEmpty)
                    // Command-Return, as Return types a new line in the JSON.
                    .keyboardShortcut(.return, modifiers: .command)
                    .accessibilityIdentifier("importButton")
                }
            }
        }
    }

    /// Side by side, or stacked at the accessibility text sizes.
    private var sourceButtonsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
    }
}

#if DEBUG
#Preview("Empty") {
    @Previewable @State var text = ""
    ImportCardsView(importText: $text) {}
}

#Preview("Pasted export") {
    @Previewable @State var text = #"[{"code": "9988776655443", "name": "Honeycomb Rewards"}]"#
    ImportCardsView(importText: $text) {}
}
#endif
