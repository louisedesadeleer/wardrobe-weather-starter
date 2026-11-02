import Foundation
import Observation

struct WardrobeBackup: Codable { var library: WardrobeLibrary; var photos: [String: Data] }
struct WeatherImport: Codable {
    struct Row: Codable { var outfitId: String; var temperatures: [Temperature]; var neutral: Bool; var rain: Rain; var wind: Wind; var notes: String; var photoHash: String }
    var ratings: [Row]
}
@MainActor @Observable final class WardrobeStore {
    private(set) var library = WardrobeLibrary.empty
    var errorMessage: String?
    let directory: URL
    private let file: URL
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WardrobeWeather", isDirectory: true)
        file = directory.appendingPathComponent("wardrobe.json")
        do {
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("photos"), withIntermediateDirectories: true)
            let data: Data
            if FileManager.default.fileExists(atPath: file.path) { data = try Data(contentsOf: file) }
            else { guard let seed = Bundle.main.url(forResource: "wardrobe-seed", withExtension: "json") else { throw WardrobeError.invalidBackup }; data = try Data(contentsOf: seed) }
            let decoded = try JSONDecoder().decode(WardrobeLibrary.self, from: data); try decoded.validate(); library = decoded
            if !FileManager.default.fileExists(atPath: file.path) { try persist(decoded) }
        } catch { errorMessage = "Couldn’t open your wardrobe: \(error.localizedDescription)" }
    }
    private func persist(_ library: WardrobeLibrary) throws {
        let data = try JSONEncoder().encode(library)
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func commit(_ change: (inout WardrobeLibrary) throws -> Void) throws {
        var next = library; try change(&next); try next.validate(); try persist(next); library = next
    }
    func rate(_ outfit: Outfit, rating: WeatherRating) throws {
        guard rating.isValid else { throw WardrobeError.invalidBackup }
        var rating = rating; rating.photoHash = outfit.photoHash; rating.updatedAt = ISO8601DateFormatter().string(from: Date())
        try commit { $0.ratings[outfit.id] = rating }
    }
    func log(outfit: Outfit, date: Date, status: WearStatus, notes: String) throws {
        let entry = WearLog(date: DateKey.string(date), outfitId: outfit.id, status: status, notes: String(notes.prefix(500)), updatedAt: ISO8601DateFormatter().string(from: Date()), itemIds: outfit.itemIds)
        try commit { try $0.setLog(entry) }
    }
    func removeLog(_ log: WearLog) throws { try commit { $0.logs.removeAll { $0.id == log.id } } }
    func saveBoard(name: String, layers: [BoardLayer], editing: Outfit?) throws -> Outfit {
        guard !layers.isEmpty else { throw WardrobeError.invalidBackup }
        var boardName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if boardName.isEmpty { boardName = editing?.name ?? "" }
        if boardName.isEmpty {
            let existingNames = Set(library.outfits.map(\.name))
            var number = library.outfits.count + 1
            repeat {
                boardName = String(format: "Outfit %03d", number)
                number += 1
            } while existingNames.contains(boardName)
        }
        let ids = Array(Set(layers.map(\.itemId))).sorted()
        let pieces = library.items.filter { ids.contains($0.id) }
        let now = ISO8601DateFormatter().string(from: Date())
        let id = editing?.source == "created" ? editing!.id : "outfit:custom:" + UUID().uuidString
        let result = Outfit(id: id, name: String(boardName.prefix(100)), brand: "\(ids.count) pieces", category: pieces.contains(where: { $0.category == "One Piece" }) ? "Dresses & one-pieces" : "Separates", colors: Array(Set(pieces.map(\.colors))).sorted().joined(separator: " · "), material: "", image: "", photoHash: UUID().uuidString, pieceNames: pieces.map(\.name).joined(separator: " · "), itemIds: ids, missingItems: ids.filter { id in !library.items.contains(where: { $0.id == id }) }.count, layers: layers, source: "created", updatedAt: now)
        try commit { library in library.outfits.removeAll { $0.id == id }; library.outfits.insert(result, at: 0) }
        return result
    }
    @discardableResult func addItem(name: String, brand: String, category: String, colors: String, png: Data, price: Double? = nil, currency: String = "EUR", productURL: String = "") throws -> ClosetItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmedName.isEmpty ? [trimmedBrand, category].filter { !$0.isEmpty }.joined(separator: " · ") : trimmedName
        let id = UUID().uuidString, reference = "photos/\(id).png"
        let destination = directory.appendingPathComponent(reference)
        try png.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let item = ClosetItem(id: "item:" + id, name: String((label.isEmpty ? "New piece" : label).prefix(100)), brand: String(trimmedBrand.prefix(80)), category: category, colors: String(colors.prefix(100)), material: "", image: reference, photoHash: id, importedWears: nil, source: productURL.isEmpty ? "uploaded" : "product-link", price: price, currency: currency, productURL: productURL)
        do { try commit { $0.items.insert(item, at: 0) } }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return item
    }
    func exportNewsletter() throws -> URL {
        struct Board: Encodable {
            let id: String; let name: String; let image: String; let photoHash: String
            let itemIds: [String]; let missingItems: Int
        }
        struct Payload: Encodable { let outfits: [Board]; let ratings: [String: WeatherRating]; let logs: [WearLog] }
        struct Export: Encodable { let wardrobe: Payload }
        let boards = library.outfits.map { Board(id: $0.id, name: $0.name, image: $0.image.hasPrefix("https://") ? $0.image : "", photoHash: $0.photoHash, itemIds: $0.itemIds, missingItems: $0.missingItems) }
        let data = try JSONEncoder().encode(Export(wardrobe: Payload(outfits: boards, ratings: library.ratings, logs: library.logs)))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Wardrobe-newsletter-\(DateKey.string(Date())).json")
        try data.write(to: url, options: .atomic)
        return url
    }
    func exportBackup() throws -> URL {
        var photos: [String: Data] = [:]
        let references = Set(library.items.map(\.image) + library.outfits.flatMap { $0.layers.map(\.image) })
        for reference in references where reference.hasPrefix("photos/") { photos[reference] = try Data(contentsOf: directory.appendingPathComponent(reference)) }
        let backup = WardrobeBackup(library: library, photos: photos)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Wardrobe-Weather-\(DateKey.string(Date())).json")
        try JSONEncoder().encode(backup).write(to: url, options: .atomic); return url
    }
    func importFile(_ url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count < 100_000_000 else { throw WardrobeError.invalidBackup }
        if let weather = try? JSONDecoder().decode(WeatherImport.self, from: data) {
            var count = 0
            try commit { library in
                for row in weather.ratings where library.outfits.contains(where: { $0.id == row.outfitId }) {
                    var rating = WeatherRating(); rating.temperatures = row.temperatures; rating.neutral = row.neutral; rating.rain = row.rain; rating.wind = row.wind; rating.notes = row.notes; rating.photoHash = row.photoHash
                    guard rating.isValid else { throw WardrobeError.invalidBackup }
                    library.ratings[row.outfitId] = rating; count += 1
                }
            }
            return "Imported weather choices for \(count) outfits."
        }
        let backup = try JSONDecoder().decode(WardrobeBackup.self, from: data); try backup.library.validate()
        for (key, _) in backup.photos { guard key.range(of: #"^photos/[A-Fa-f0-9-]{36}\.png$"#, options: .regularExpression) != nil else { throw WardrobeError.invalidBackup } }
        let references = Set(backup.library.items.map(\.image) + backup.library.outfits.flatMap { $0.layers.map(\.image) })
        for reference in references where reference.hasPrefix("photos/") {
            guard backup.photos[reference] != nil else { throw WardrobeError.missingPhoto }
        }
        // Fresh filenames preserve the current photos if restoration fails partway through.
        _ = try exportBackup()
        var restored = backup.library
        var filenames: [String: String] = [:]
        var written: [URL] = []
        do {
            for (key, bytes) in backup.photos {
                let fresh = "photos/" + UUID().uuidString + ".png"
                let destination = directory.appendingPathComponent(fresh)
                try bytes.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                filenames[key] = fresh; written.append(destination)
            }
            for index in restored.items.indices { if let fresh = filenames[restored.items[index].image] { restored.items[index].image = fresh } }
            for index in restored.outfits.indices {
                for layer in restored.outfits[index].layers.indices {
                    if let fresh = filenames[restored.outfits[index].layers[layer].image] { restored.outfits[index].layers[layer].image = fresh }
                }
            }
            try persist(restored); library = restored
        } catch {
            for file in written { try? FileManager.default.removeItem(at: file) }
            throw error
        }
        return "Wardrobe backup restored."
    }
}
