import SwiftUI
import PhotosUI
import UIKit

struct ColourSelector: View {
    @Binding var value: String
    private let hex: [UInt32] = [0x222222,0xffffff,0xf2ead6,0xcbb89e,0x805e46,0x999999,0x6c8ec2,0x253457,0x6b805b,0xbc5547,0xe7b3b6,0x9b83ae,0xdb985b,0xe7cf6f,0xc1c7ce,0xbfa260,0x9b83ae]
    private var selected: [String] { value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
            ForEach(PhotoAIService.colors.indices, id: \.self) { index in
                let name = PhotoAIService.colors[index], n = hex[index], picked = selected.contains { $0.lowercased() == name.lowercased() }
                Button {
                    value = (picked ? selected.filter { $0.lowercased() != name.lowercased() } : selected + [name]).joined(separator: ", ")
                } label: {
                    VStack(spacing: 5) {
                        Circle().fill(Color(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255)).frame(width: 26,height: 26).overlay { Circle().stroke(.gray.opacity(0.3)) }
                        Text(name).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
                    }.frame(maxWidth: .infinity, minHeight: 48).padding(2).overlay { Rectangle().stroke(picked ? Atelier.ink : .clear) }
                }.buttonStyle(.plain).accessibilityLabel(name).accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
    }
}
struct SelfieView: View {
    let choose: ([ClosetItem]) -> Void
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picked: PhotosPickerItem?
    @State private var photo: Data?
    @State private var busy = false
    @State private var result: SelfieSuggestion?
    @State private var selected = Set<String>()
    @State private var message = "Choose an outfit photo, then find your pieces."
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let photo, let image = UIImage(data: photo) { Image(uiImage: image).resizable().scaledToFit().frame(height: 260).frame(maxWidth: .infinity).background(Atelier.wall) }
                    PhotosPicker(selection: $picked, matching: .images) { Label("Choose a selfie", systemImage: "photo") }.disabled(busy)
                    Text("OpenAI reads your clothing and compares likely matches with wardrobe photos. Review every suggestion; nothing is saved automatically.").font(.caption).foregroundStyle(.secondary)
                    Button(busy ? "Finding pieces…" : "Find my pieces") { analyze() }.buttonStyle(AtelierButtonStyle(filled: true)).disabled(photo == nil || busy)
                    if busy { ProgressView() }
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    if let result {
                        ForEach(result.matches) { match in
                            if let item = store.library.items.first(where: { $0.id == match.itemId }) {
                                Button { if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) } } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selected.contains(item.id) ? "checkmark.square.fill" : "square")
                                        WardrobePhoto(source: item.image, label: item.name).frame(width: 64,height: 80).background(Atelier.wall)
                                        VStack(alignment: .leading, spacing: 6) { Text(item.name); Text(match.confidence + " match · " + match.description).font(.caption).foregroundStyle(.secondary) }
                                    }
                                }.buttonStyle(.plain)
                            }
                        }
                        if !result.unmatched.isEmpty { Text("Not matched: " + result.unmatched.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                        Button("Use selected pieces") { let items = store.library.items.filter { selected.contains($0.id) }; choose(items); dismiss() }.buttonStyle(AtelierButtonStyle(filled: true)).disabled(selected.isEmpty || busy)
                    }
                }.padding(20)
            }.background(Atelier.paper).navigationTitle("Outfit from a selfie").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
            .task(id: picked) {
                guard let picked else { return }; busy = true; defer { busy = false }
                do { guard let data = try await picked.loadTransferable(type: Data.self), data.count < 40_000_000, let image = UIImage(data: data), let png = PhotoProcessor.normalized(image).pngData() else { throw WardrobeError.invalidImage }; try Task.checkCancellation(); photo = png; result = nil; selected = []; message = "Ready to find your pieces." }
                catch is CancellationError {} catch { message = error.localizedDescription }
            }
        }
    }
    private func analyze() {
        guard let photo else { return }; busy = true; result = nil; selected = []; message = "Finding clothing, then comparing wardrobe photos…"
        Task { defer { busy = false }; do { let matches = try await PhotoAIService.selfie(photo, items: store.library.items, directory: store.directory); result = matches; message = matches.matches.isEmpty ? "No confident wardrobe matches. Choose pieces manually or try another photo." : "Select only pieces you recognise, then arrange the board." } catch { message = error.localizedDescription } }
    }
}
struct PhotoAISettings: View {
    @State private var key = ""
    @State private var connected = PhotoAIKey.read() != nil
    @State private var message = ""
    var body: some View {
        Section {
            Text(connected ? "Connected" : "Not connected")
            SecureField("Your OpenAI API key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Save key securely") { do { try PhotoAIKey.save(key); key = ""; connected = true; message = "Saved in this iPhone’s Keychain." } catch { message = error.localizedDescription } }.disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            if connected { Button("Disconnect OpenAI") { do { try PhotoAIKey.remove(); connected = false; message = "Disconnected." } catch { message = error.localizedDescription } } }
            if !message.isEmpty { Text(message).font(.caption) }
        } header: { Text("Photo suggestions · OpenAI") } footer: { Text("This personal app uses your own API key. Photos are sent to OpenAI only for suggestions; selfie matching also sends wardrobe metadata and candidate photos. Suggestions need your review. The key stays in this device’s Keychain and is excluded from wardrobe backups.") }
    }
}
