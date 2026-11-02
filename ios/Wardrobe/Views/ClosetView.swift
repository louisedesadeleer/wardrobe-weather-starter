import SwiftUI
import PhotosUI
import UIKit

let closetCategories = ["Top","Bottom","One Piece","Outerwear","Shoes","Bag","Accessory","Jewelry","Swim","Other"]
struct ClosetView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var search = ""
    @State private var category = "All"
    @State private var upload = false
    @State private var selected: ClosetItem?
    @State private var addedItem: ClosetItem?
    @State private var reviewItem: ClosetItem?
    private var items: [ClosetItem] { store.library.items.filter { (category == "All" || $0.category == category) && (search.isEmpty || ($0.name + $0.brand + $0.colors).localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Picker("Category", selection: $category) { Text("All pieces").tag("All"); ForEach(closetCategories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    Text("\(items.count) pieces").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible()),GridItem(.flexible())], spacing: 20) {
                        ForEach(items) { item in
                            Button { selected = item } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    WardrobePhoto(source: item.image, label: item.name).frame(height: 130).frame(maxWidth: .infinity).background(Atelier.wall)
                                    Text(item.name).font(.caption).lineLimit(2).foregroundStyle(Atelier.ink)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(18)
            }.background(Atelier.paper).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Name, brand or colour")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { upload = true } label: { Image(systemName: "plus") }.accessibilityLabel("Upload an item") } }
            .sheet(isPresented: $upload, onDismiss: { if store.library.preferences?.reviewOnAdd == true { reviewItem = addedItem }; addedItem = nil }) { ItemUploadView(onSave: { addedItem = $0 }) }
            .sheet(item: $reviewItem) { WardrobeReviewView(addedId: $0.id) }
            .sheet(item: $selected) { ItemDetailView(item: $0) }
        }
    }
}
struct ItemDetailView: View {
    let item: ClosetItem
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Outfit?
    @State private var resale = false
    private var current: ClosetItem { store.library.items.first { $0.id == item.id } ?? item }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WardrobePhoto(source: item.image, label: item.name).frame(height: 280).frame(maxWidth: .infinity).background(Atelier.wall)
                    Text(item.name).font(Atelier.title(32))
                    Text(item.category + " · " + item.colors).font(.subheadline).foregroundStyle(.secondary)
                    Text(wardrobeMoney(current.price, currency: current.currency)).font(.subheadline)
                    Button("Price, replace or sell") { resale = true }.buttonStyle(AtelierButtonStyle())
                    Text("\(WearAnalytics(library: store.library).itemDays[item.id, default: 0]) days worn in this app").font(.headline)
                    if let wears = item.importedWears { Text("Indyx reported \(wears) wears at import. These are shown separately from your dated calendar entries.").font(.caption).foregroundStyle(.secondary) }
                    Text("In your outfits").font(Atelier.title(24))
                    LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 20) {
                        ForEach(store.library.outfits.filter { $0.itemIds.contains(item.id) }) { outfit in Button { selected = outfit } label: { OutfitCard(outfit: outfit) }.buttonStyle(.plain) }
                    }
                }.padding(20)
            }.background(Atelier.paper).navigationTitle("Your piece").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { OutfitDetailView(outfitId: $0.id) }
            .sheet(isPresented: $resale) { ResaleEditorView(item: current) }
        }
    }
}
struct ItemUploadView: View {
    var onSave: ((ClosetItem) -> Void)? = nil
    @State private var price = ""
    @State private var currency = "EUR"
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picked: PhotosPickerItem?
    @State private var original: Data?
    @State private var preview: Data?
    @State private var brand = ""
    @State private var category = "Top"
    @State private var colors = ""
    @State private var busy = false
    @State private var message: String?
    @State private var aiMessage = "Details are suggested automatically when you choose a photo. The photo is sent to OpenAI; review before saving."
    @State private var categoryEdited = false
    @State private var suggesting = false
    @State private var showAISettings = false
    @State private var aiConnected = PhotoAIKey.read() != nil
    @State private var suggestedBrand: String?
    @State private var suggestedColors: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let preview, let image = UIImage(data: preview) { Image(uiImage: image).resizable().scaledToFit().frame(height: 240).frame(maxWidth: .infinity).background(Atelier.wall) }
                    PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) { Label(preview == nil ? "Choose a photo" : "Change photo", systemImage: "photo.on.rectangle") }.disabled(busy)
                    if original != nil {
                        Button { removeBackground() } label: { Label("Remove background", systemImage: "person.crop.rectangle") }.disabled(busy)
                        Button("Use original photo") { preview = original; message = nil }.disabled(busy)
                    }
                    if busy { ProgressView(suggesting ? "Suggesting details…" : "Processing photo…") }
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
                Section("About this piece") {
                    TextField("Brand (optional)", text: $brand)
                    TextField("Price paid / saved price", text: $price).keyboardType(.decimalPad)
                    TextField("Currency", text: $currency).textInputAutocapitalization(.characters)
                    Picker("Category", selection: Binding(get: { category }, set: { category = $0; categoryEdited = true })) { ForEach(closetCategories, id: \.self) { Text($0).tag($0) } }
                    TextField("Colours (optional)", text: $colors)
                    ColourSelector(value: $colors)
                    if aiConnected {
                        Button("Retry AI suggestions") { Task { await suggest() } }.disabled(original == nil || busy)
                    } else {
                        Button("Connect OpenAI for automatic details") { showAISettings = true }.disabled(busy)
                    }
                    Text(aiMessage).font(.caption).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).background(Atelier.paper)
            .navigationTitle("Add a piece").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let preview else { return }
                    do { let item = try store.addItem(name: "", brand: brand, category: category, colors: colors, png: preview, price: try wardrobePrice(price), currency: currency.uppercased()); onSave?(item); dismiss() } catch { store.errorMessage = error.localizedDescription }
                }.disabled(preview == nil || busy) }
            }
            .sheet(isPresented: $showAISettings, onDismiss: {
                aiConnected = PhotoAIKey.read() != nil
                if aiConnected && original != nil { Task { await suggest() } }
            }) {
                NavigationStack {
                    Form { PhotoAISettings() }
                        .navigationTitle("Photo suggestions")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAISettings = false } } }
                }
            }
            .task(id: picked) {
                guard let picked else { return }; busy = true; defer { busy = false }
                do {
                    guard let data = try await picked.loadTransferable(type: Data.self), data.count < 40_000_000, let image = UIImage(data: data), let png = PhotoProcessor.normalized(image).pngData() else { throw WardrobeError.invalidImage }
                    try Task.checkCancellation(); original = png; preview = png; message = nil
                    await readSuggestions(png)
                } catch is CancellationError {} catch { message = error.localizedDescription }
            }
        }
    }
    private func suggest() async {
        guard let original, !busy else { return }; busy = true; defer { busy = false }; await readSuggestions(original)
    }
    private func readSuggestions(_ photo: Data) async {
        aiConnected = PhotoAIKey.read() != nil
        guard aiConnected else {
            aiMessage = "Connect OpenAI to suggest details automatically. You can also fill them in and save without it."
            return
        }
        suggesting = true
        defer { suggesting = false }
        aiMessage = "Reading this piece…"
        do {
            let suggestion = try await PhotoAIService.item(photo)
            try Task.checkCancellation()
            if brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || brand == suggestedBrand { brand = suggestion.brand }
            if !categoryEdited && closetCategories.contains(suggestion.category) { category = suggestion.category }
            let newColors = suggestion.colors.joined(separator: ", ")
            if colors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || colors == suggestedColors { colors = newColors }
            suggestedBrand = suggestion.brand; suggestedColors = newColors
            aiMessage = "Review the suggested details before saving. " + suggestion.note
        } catch is CancellationError {} catch { aiMessage = error.localizedDescription }
    }
    private func removeBackground() {
        guard let original else { return }; busy = true; message = nil
        Task { do { preview = try await PhotoProcessor.cutout(original) } catch { message = "Couldn’t remove the background. Try another photo." }; busy = false }
    }
}
