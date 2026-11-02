import SwiftUI
import Charts
import UniformTypeIdentifiers
struct InsightsView: View {
    @Environment(WardrobeStore.self) private var store
    @State private var period = "All time"
    private var since: String? { period == "Last 30 days" ? DateKey.string(Calendar.current.date(byAdding: .day, value: -29, to: Date())!) : nil }
    private var stats: WearAnalytics { WearAnalytics(library: store.library, since: since) }
    private var neverLogged: Int { let worn = Set(store.library.logs.filter { $0.status == .worn }.map(\.outfitId)); return store.library.outfits.filter { !worn.contains($0.id) }.count }
    private var topOutfits: [Outfit] { store.library.outfits.filter { stats.outfitCounts[$0.id,default:0] > 0 }.sorted { stats.outfitCounts[$0.id,default:0] > stats.outfitCounts[$1.id,default:0] } }
    private var topItems: [ClosetItem] { store.library.items.filter { stats.itemDays[$0.id,default:0] > 0 }.sorted { stats.itemDays[$0.id,default:0] > stats.itemDays[$1.id,default:0] } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    Picker("Period", selection: $period) { Text("All time").tag("All time"); Text("Last 30 days").tag("Last 30 days") }.pickerStyle(.segmented)
                    HStack {
                        metric("\(stats.wornDays)", "Days logged worn")
                        Spacer(); metric("\(stats.outfitCounts.count)", "Outfits worn")
                        Spacer(); metric("\(stats.itemDays.count)", "Pieces worn")
                    }
                    if topOutfits.isEmpty { ContentUnavailableView("Your story starts with a wear", systemImage: "chart.bar", description: Text("Mark an outfit Worn in the calendar to see your patterns here.")) }
                    else {
                        Text("Your most-worn outfits").font(Atelier.body(15))
                        Chart(Array(topOutfits.prefix(5))) { outfit in
                            BarMark(x: .value("Wears", stats.outfitCounts[outfit.id,default:0]), y: .value("Outfit", outfit.name)).foregroundStyle(Atelier.ink)
                        }.frame(height: CGFloat(min(5, topOutfits.count)) * 42 + 25)
                        Text("Pieces getting the most love").font(Atelier.body(15))
                        ForEach(Array(topItems.prefix(10))) { item in HStack { WardrobePhoto(source: item.image).frame(width: 45,height: 55); VStack(alignment: .leading) { Text(item.name).font(.subheadline); Text("\(stats.itemDays[item.id,default:0]) distinct days").font(.caption).foregroundStyle(.secondary) }; Spacer() } }
                    }
                    Divider()
                    Text("Not worn here yet").font(Atelier.body(15))
                    Text("\(neverLogged) outfits have no Worn entries in this app. That doesn’t mean you’ve never worn them.").font(.subheadline).foregroundStyle(.secondary)
                    Divider()
                    Text("Imported wear history").font(Atelier.body(15))
                    Text("Imported totals have no dates, so they stay separate from the calendar to avoid double-counting.").font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(store.library.items.filter { ($0.importedWears ?? 0) > 0 }.sorted { ($0.importedWears ?? 0) > ($1.importedWears ?? 0) }.prefix(10))) { item in HStack { Text(item.name).font(.subheadline); Spacer(); Text("\(item.importedWears ?? 0) wears").font(.caption).foregroundStyle(.secondary) } }
                }.padding(20)
            }.background(Atelier.paper).navigationTitle("").navigationBarTitleDisplayMode(.inline)
        }
    }
    private func metric(_ value: String, _ label: String) -> some View { VStack(alignment: .leading, spacing: 5) { Text(value).font(Atelier.title(35)); Text(label).font(.caption2).foregroundStyle(.secondary) } }
}
struct SettingsView: View {
    @Environment(WardrobeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var backup: URL?
    @State private var newsletterExport: URL?
    @State private var importing = false
    @State private var confirmImport = false
    @State private var message = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Your collection") {
                    LabeledContent("Pieces", value: "\(store.library.items.count)")
                    LabeledContent("Outfits", value: "\(store.library.outfits.count)")
                    LabeledContent("Weather tagged", value: "\(store.library.ratings.count)")
                }
                Section("Outfit emails") {
                    Text("Use Prepare full backup below, then share it to your computer and run the newsletter tool. Export again after changing outfits or weather tags.").font(.caption)
                }
                PhotoAISettings()
                WardrobeReviewSettings()
                Section {
                    Button("Prepare full backup") { do { backup = try store.exportBackup() } catch { store.errorMessage = error.localizedDescription } }
                    if let backup { ShareLink("Save or share backup", item: backup) }
                    Button("Import backup or website weather tags") { confirmImport = true }
                    if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
                } header: { Text("Backups & transfer") } footer: { Text("Backups include your wardrobe data and uploaded photos. A full backup replaces the local library; website weather exports only update matching outfit tags.") }
                Section("About this version") {
                    Text("Your wardrobe is saved on this iPhone. There is no automatic cloud sync yet.")
                    Text("Indyx photos load online and are cached after viewing. Uploaded photos stay on this device and in your exported backups.")
                    Text("To bring over your existing weather tags: export ratings from the website’s settings, then import that JSON file here.")
                }.font(.caption)
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .confirmationDialog("Import a wardrobe file?", isPresented: $confirmImport, titleVisibility: .visible) { Button("Choose file") { importing = true }; Button("Cancel", role: .cancel) {} } message: { Text("A full backup replaces this device’s wardrobe. Export your current backup first if you want to keep a copy.") }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { message = try store.importFile(result.get()); backup = nil } catch { store.errorMessage = error.localizedDescription }
            }
        }
    }
}
