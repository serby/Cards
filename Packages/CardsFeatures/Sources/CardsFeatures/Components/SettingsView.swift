import CardsCore
import SwiftData
import SwiftUI

public struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CardItem]
    
    @AppStorage("brightnessBoost") private var brightnessBoost = true
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    public init() {}
    
    public var body: some View {
        List {
            Section {
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    HStack {
                        Text("Version")
                            .foregroundColor(.primaryText)
                        Spacer()
                        Text("\(version) (\(build))")
                            .foregroundColor(.secondaryText)
                    }
                }
                
                if let url = URL(string: "https://github.com/serby") {
                    Link(destination: url) {
                        HStack {
                            Text("Created by Paul Serby")
                                .foregroundColor(.primaryText)
                            Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .foregroundColor(.accent)
                            .accessibilityLabel("External link")
                        }
                    }
                }
            }
            
            Section {
                Toggle("Brightness Boost", isOn: $brightnessBoost)
                    .tint(.accent)
                Text("Boosts brightness when viewing card to improve scannability")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            } header: {
                Text("Display")
                    .foregroundColor(.secondaryText)
            }
            
            Section("Data") {
                Button("Export as JSON") {
                    showExportSheet = true
                }
                .foregroundColor(.accent)
                
                Button("Import JSON") {
                    showImportSheet = true
                }
                .foregroundColor(.accent)
                
                Button("Delete All Cards", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .disabled(cards.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.primaryBackground)
        .navigationTitle("Settings")
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(items: [exportJSON()])
        }
        .sheet(isPresented: $showImportSheet) {
            ImportView(importText: $importText, onImport: importJSON)
        }
        .confirmationDialog("Delete All Cards", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                deleteAllCards()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all \(cards.count) cards. This action cannot be undone.")
        }
        .alert("Import Result", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let dtos = cards.map { CardItemDTO(from: $0) }
        guard let data = try? encoder.encode(dtos),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    private func importJSON() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let data = importText.data(using: .utf8),
              let dtos = try? decoder.decode([CardItemDTO].self, from: data) else {
            alertMessage = "Invalid JSON format"
            showAlert = true
            return
        }
        
        for dto in dtos {
            modelContext.insert(dto.toCardItem())
        }
        
        try? modelContext.save()
        alertMessage = "Successfully imported \(dtos.count) cards"
        showAlert = true
        showImportSheet = false
        importText = ""
    }
    
    private func deleteAllCards() {
        for card in cards {
            modelContext.delete(card)
        }
        try? modelContext.save()
    }
}

struct ImportView: View {
    @Binding var importText: String
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $importText)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                
                Button("Paste from Clipboard") {
                    if let clipboard = UIPasteboard.general.string {
                        importText = clipboard
                    }
                }
                .buttonStyle(.bordered)
                .padding()
            }
            .navigationTitle("Import JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                    }
                    .disabled(importText.isEmpty)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .modelContainer(for: CardItem.self, inMemory: true)
    }
}
