import Foundation

public enum Temperature: String, Codable, CaseIterable, Identifiable, Sendable {
    case cold, cool, mild, hot
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var range: String { switch self { case .cold: "Below 10°C"; case .cool: "10–17°C"; case .mild: "18–23°C"; case .hot: "24°C+" } }
    public var symbol: String { switch self { case .cold: "snowflake"; case .cool: "cloud"; case .mild: "cloud.sun"; case .hot: "sun.max" } }
}
public enum Rain: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown, dryOnly = "dry-only", lightRain = "light-rain", rainReady = "rain-ready"
    public var id: String { rawValue }
    public var title: String { switch self { case .unknown: "Not set"; case .dryOnly: "Dry days only"; case .lightRain: "Light rain is fine"; case .rainReady: "Rain-ready" } }
}
public enum Wind: String, Codable, CaseIterable, Identifiable, Sendable {
    case unknown, avoidWind = "avoid-wind", windOK = "wind-ok"
    public var id: String { rawValue }
    public var title: String { switch self { case .unknown: "Not set"; case .avoidWind: "Avoid windy days"; case .windOK: "Wind is fine" } }
}
public struct WeatherRating: Codable, Equatable, Sendable {
    public var temperatures: [Temperature] = []
    public var neutral = false
    public var rain: Rain = .unknown
    public var wind: Wind = .unknown
    public var notes = ""
    public var photoHash = ""
    public var updatedAt: String? = nil
    public init() {}
    public var isValid: Bool { (neutral ? temperatures.isEmpty : !temperatures.isEmpty) && Set(temperatures).count == temperatures.count && notes.count <= 500 }
    public func matches(_ temperature: Temperature?, rainy: Bool = false, windy: Bool = false) -> Bool {
        guard isValid else { return false }
        if let temperature, !neutral && !temperatures.contains(temperature) { return false }
        if rainy && ![Rain.lightRain, .rainReady].contains(rain) { return false }
        if windy && wind != .windOK { return false }
        return true
    }
}
public struct ResaleDetails: Codable, Equatable, Sendable {
    public var status = "undecided"
    public var size = ""
    public var condition = ""
    public var notes = ""
    public var askingPrice: Double? = nil
    public var title = ""
    public var description = ""
}
public struct WardrobePreferences: Codable, Sendable { public var reviewOnAdd = false }
public struct ClosetItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var brand: String
    public var category: String
    public var colors: String
    public var material: String
    public var image: String
    public var photoHash: String
    public var importedWears: Int?
    public var source: String
    public var price: Double? = nil
    public var currency: String? = nil
    public var productURL: String? = nil
    public var resale: ResaleDetails? = nil
}
public struct BoardLayer: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var itemId: String
    public var image: String
    public var centerX: Double
    public var centerY: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var flipped: Bool
}
public struct Outfit: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var brand: String
    public var category: String
    public var colors: String
    public var material: String
    public var image: String
    public var photoHash: String
    public var pieceNames: String
    public var itemIds: [String]
    public var missingItems: Int
    public var layers: [BoardLayer]
    public var source: String
    public var updatedAt: String
}
public enum WearStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case planned, worn, notWorn = "not-worn"
    public var id: String { rawValue }
    public var title: String { switch self { case .planned: "Planned"; case .worn: "Worn"; case .notWorn: "Not worn" } }
    public var symbol: String { switch self { case .planned: "clock"; case .worn: "checkmark.circle.fill"; case .notWorn: "minus.circle" } }
}
public struct WearLog: Codable, Identifiable, Equatable, Sendable {
    public var date: String
    public var outfitId: String
    public var status: WearStatus
    public var notes: String
    public var updatedAt: String
    public var itemIds: [String]? = nil
    public var id: String { date + ":" + outfitId }
}
public struct WardrobeLibrary: Codable, Sendable {
    public var version: Int
    public var items: [ClosetItem]
    public var outfits: [Outfit]
    public var ratings: [String: WeatherRating]
    public var logs: [WearLog]
    public var importedAt: String
    public var preferences: WardrobePreferences? = nil
    public static var empty: Self { .init(version: 1, items: [], outfits: [], ratings: [:], logs: [], importedAt: "2026-10-28") }
    public mutating func setLog(_ log: WearLog) throws {
        guard DateKey.parse(log.date) != nil, outfits.contains(where: { $0.id == log.outfitId }) else { throw WardrobeError.invalidLog }
        if log.status == .worn && log.date > DateKey.string(Date()) { throw WardrobeError.futureWear }
        logs.removeAll { $0.id == log.id }; logs.append(log)
    }
    public func validate() throws {
        guard version == 1, Set(items.map(\.id)).count == items.count, Set(outfits.map(\.id)).count == outfits.count, Set(logs.map(\.id)).count == logs.count else { throw WardrobeError.invalidBackup }
        let ids = Set(outfits.map(\.id))
        guard logs.allSatisfy({ ids.contains($0.outfitId) && DateKey.parse($0.date) != nil }), ratings.allSatisfy({ ids.contains($0.key) && $0.value.isValid }) else { throw WardrobeError.invalidBackup }
        for item in items {
            for value in [item.price,item.resale?.askingPrice] { if let value { guard value.isFinite && value >= 0 && value <= 1_000_000 else { throw WardrobeError.invalidBackup } } }
            if let currency = item.currency { guard currency.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else { throw WardrobeError.invalidBackup } }
            if let link = item.productURL, !link.isEmpty { guard let url = URL(string: link), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw WardrobeError.invalidBackup } }
            if let resale = item.resale { guard ["undecided","keep","replace","sell"].contains(resale.status) else { throw WardrobeError.invalidBackup } }
        }
        for outfit in outfits {
            guard outfit.layers.allSatisfy({ [$0.centerX,$0.centerY,$0.width,$0.height,$0.rotation].allSatisfy(\.isFinite) && $0.width > 0 && $0.height > 0 }) else { throw WardrobeError.invalidBackup }
        }
    }
}
public enum WardrobeError: LocalizedError {
    case invalidLog, futureWear, invalidBackup, invalidImage, missingPhoto
    public var errorDescription: String? { switch self {
        case .invalidLog: "Choose a valid date and an outfit from your wardrobe."
        case .futureWear: "Future outfits can be planned. Mark them worn on the day."
        case .invalidBackup: "This file isn’t a valid wardrobe backup. Your current data is unchanged."
        case .invalidImage: "This photo couldn’t be opened. Please choose another image."
        case .missingPhoto: "A photo is missing from the backup. Your current data is unchanged."
    } }
}
public enum DateKey {
    public static func string(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = timeZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    public static func parse(_ value: String) -> Date? {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let date = f.date(from: value), f.string(from: date) == value else { return nil }; return date
    }
}
