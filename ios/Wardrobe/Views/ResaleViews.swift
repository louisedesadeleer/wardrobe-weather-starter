import SwiftUI

func wardrobeMoney(_ amount: Double?, currency: String?) -> String {
    guard let amount else { return "Price not set" }
    return amount.formatted(.currency(code: currency ?? "EUR"))
}
func wardrobePrice(_ text: String) throws -> Double? {
    if text.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
    guard let value = Double(text.replacingOccurrences(of: ",", with: ".")), value.isFinite, value >= 0, value <= 1_000_000 else { throw PhotoAIError(message: "Enter a valid price from 0 to 1,000,000.") }
    return (value * 100).rounded() / 100
}
struct WardrobeReviewView: View {
    var addedId: String? = nil
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var category = "All"
    @State private var search = ""
    @State private var selected: ClosetItem?
    private var wears: [String: Int] { WearAnalytics(library: store.library).itemDays }
    private var items: [ClosetItem] { store.library.items.filter { $0.id != addedId && (category == "All" || $0.category == category) && (search.isEmpty || ($0.name + $0.brand).localizedCaseInsensitiveContains(search)) }.sorted { wears[$0.id,default: 0] < wears[$1.id,default: 0] } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Keep, replace or sell?").font(Atelier.title(26))
                    Text("Counts show wear logged here, not your full history. Marking a piece to sell or replace keeps it in your wardrobe and past outfits.").font(.caption).foregroundStyle(.secondary)
                    Picker("Category", selection: $category) { Text("All pieces").tag("All"); ForEach(closetCategories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    ForEach(items) { item in
                        Button { selected = item } label: {
                            HStack(spacing: 12) {
                                WardrobePhoto(source: item.image, label: item.name).frame(width: 65,height: 85).background(Atelier.wall)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name)
                                    Text("\(wears[item.id,default: 0]) days logged worn").font(.caption)
                                    if let count = item.importedWears { Text("\(count) imported wears (separate)").font(.caption2) }
                                    Text((item.resale?.status ?? "undecided").capitalized + " · " + wardrobeMoney(item.price, currency: item.currency)).font(.caption2).foregroundStyle(.secondary)
                                }; Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }
                        }.buttonStyle(.plain)
                    }
                    if items.isEmpty { Text("No matching pieces.").font(.caption).foregroundStyle(.secondary) }
                }.padding(20)
            }.background(Atelier.paper).searchable(text: $search).navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { ResaleEditorView(item: $0) }
            .onAppear { if let item = store.library.items.first(where: { $0.id == addedId }) { category = item.category } }
        }
    }
}
struct ResaleEditorView: View {
    let item: ClosetItem
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var details = ResaleDetails()
    @State private var price = ""
    @State private var currency = "EUR"
    @State private var asking = ""
    @State private var error = ""
    @State private var confirmDraft = false
    private let conditions = ["New with tags","New without tags","Very good","Good","Satisfactory"]
    private var listing: String { [details.title,details.description,asking.isEmpty ? "" : "Asking price: " + asking + " " + currency].filter { !$0.isEmpty }.joined(separator: "\n\n") }
    var body: some View {
        NavigationStack {
            Form {
                Section { HStack { WardrobePhoto(source: item.image, label: item.name).frame(width: 75,height: 100).background(Atelier.wall); Text(item.name).font(Atelier.title(22)) } }
                Section("Price & source") {
                    TextField("Price paid / saved price", text: $price).keyboardType(.decimalPad)
                    TextField("Currency", text: $currency).textInputAutocapitalization(.characters)
                }
                Section {
                    Picker("What would you like to do?", selection: $details.status) { ForEach(["undecided","keep","replace","sell"], id: \.self) { Text($0.capitalized).tag($0) } }
                } footer: { Text("Sell and Replace are intentions. The item stays in your wardrobe and past outfits.") }
                Section {
                    TextField("Size", text: $details.size)
                    Picker("Condition", selection: $details.condition) { Text("Choose after checking").tag(""); ForEach(conditions, id: \.self) { Text($0).tag($0) } }
                    TextField("Flaws, measurements & other details", text: $details.notes, axis: .vertical).lineLimit(3...6)
                    TextField("Your asking price (" + currency + ")", text: $asking).keyboardType(.decimalPad)
                    Button("Draft listing") { if details.title.isEmpty && details.description.isEmpty { draft() } else { confirmDraft = true } }
                    TextField("Listing title", text: $details.title)
                    TextField("Listing description", text: $details.description, axis: .vertical).lineLimit(5...12)
                    ShareLink("Copy or share listing", item: listing).disabled(details.title.isEmpty || details.description.isEmpty)
                } header: { Text("Vinted draft") } footer: { Text("Check the wording and use current photos of your own item. Asking price is your choice; this does not estimate market value or post to Vinted.") }
                if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
            }.scrollContentBackground(.hidden).background(Atelier.paper).navigationTitle("Price & resale").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } } }
            .confirmationDialog("Replace your current listing draft?", isPresented: $confirmDraft) { Button("Replace draft") { draft() }; Button("Cancel", role: .cancel) {} }
            .onAppear { details = item.resale ?? ResaleDetails(); price = item.price.map { String($0) } ?? ""; currency = item.currency ?? "EUR"; asking = item.resale?.askingPrice.map { String($0) } ?? "" }
        }
    }
    private func draft() {
        guard !details.condition.isEmpty else { error = "Choose the actual condition first."; return }
        details.title = String([item.name.localizedCaseInsensitiveContains(item.brand) ? "" : item.brand,item.name,details.size].filter { !$0.isEmpty }.joined(separator: " · ").prefix(100))
        details.description = [item.name,item.brand.isEmpty ? "" : "Brand: " + item.brand,details.size.isEmpty ? "" : "Size: " + details.size,item.colors.isEmpty ? "" : "Colour: " + item.colors,"Condition: " + details.condition,details.notes.isEmpty ? "" : "Details: " + details.notes].filter { !$0.isEmpty }.joined(separator: "\n")
        error = ""
    }
    private func save() {
        do {
            let savedPrice = try wardrobePrice(price); details.askingPrice = try wardrobePrice(asking)
            try store.commit { library in
                guard let index = library.items.firstIndex(where: { $0.id == item.id }) else { throw WardrobeError.invalidBackup }
                library.items[index].price = savedPrice; library.items[index].currency = currency.uppercased(); library.items[index].resale = details
            }; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct WardrobeReviewSettings: View {
    @Environment(WardrobeStore.self) private var store
    @State private var reviewing = false
    var body: some View {
        Section {
            Toggle("Review my wardrobe when I add something", isOn: Binding(get: { store.library.preferences?.reviewOnAdd ?? false }, set: { value in do { try store.commit { $0.preferences = WardrobePreferences(reviewOnAdd: value) } } catch { store.errorMessage = error.localizedDescription } }))
            Button("Review pieces to keep or sell") { reviewing = true }
        } header: { Text("Wardrobe review") } footer: { Text("After saving a new item, review similar pieces. You can also start a review here anytime.") }
        .sheet(isPresented: $reviewing) { WardrobeReviewView() }
    }
}
