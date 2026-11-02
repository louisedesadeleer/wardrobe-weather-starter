import Foundation
public struct WearAnalytics: Sendable {
    public var wornDays: Int
    public var outfitCounts: [String: Int]
    public var itemDays: [String: Int]
    public var lastWorn: [String: String]
    public init(library: WardrobeLibrary, since: String? = nil) {
        let logs = library.logs.filter { $0.status == .worn && (since == nil || $0.date >= since!) }
        wornDays = Set(logs.map(\.date)).count
        outfitCounts = [:]; lastWorn = [:]
        var dates: [String: Set<String>] = [:]
        let outfits = Dictionary(uniqueKeysWithValues: library.outfits.map { ($0.id,$0) })
        for log in logs {
            outfitCounts[log.outfitId, default: 0] += 1
            lastWorn[log.outfitId] = max(lastWorn[log.outfitId] ?? "", log.date)
            for item in Set(log.itemIds ?? outfits[log.outfitId]?.itemIds ?? []) { dates[item, default: []].insert(log.date) }
        }
        itemDays = dates.mapValues(\.count)
    }
}
