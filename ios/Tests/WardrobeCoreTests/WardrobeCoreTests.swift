import Foundation
#if !CORE_CHECKS
import XCTest
@testable import WardrobeCore
#endif

final class WardrobeCoreTests: XCTestCase {
    private func seed() throws -> WardrobeLibrary {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(WardrobeLibrary.self, from: Data(contentsOf: root.appendingPathComponent("Wardrobe/Resources/wardrobe-seed.json")))
    }
    func testSeedPreservesWardrobeAndEditableBoards() throws {
        let library = try seed()
        try library.validate()
        XCTAssertEqual(library.items.count, 48)
        XCTAssertEqual(library.outfits.count, 32)
        XCTAssertEqual(library.outfits.flatMap(\.layers).count, 64)
        XCTAssertTrue(library.logs.isEmpty)
        XCTAssertEqual(library.ratings.count, 28)
        XCTAssertTrue(library.items.allSatisfy { $0.source == "demo" })
        let decoded = try JSONDecoder().decode(WardrobeLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(decoded.outfits, library.outfits)
    }
    func testPricesAndResaleAreOptionalAndSurviveBackup() throws {
        var library = try seed()
        XCTAssertNil(library.items[0].price); XCTAssertNil(library.items[0].resale); XCTAssertNil(library.preferences)
        library.items[0].price = 89.95; library.items[0].currency = "EUR"; library.items[0].productURL = "https://example.com/product"
        var resale = ResaleDetails(); resale.status = "sell"; resale.condition = "Good"; resale.notes = "Small mark on sleeve"; resale.askingPrice = 25; resale.title = "Blue shirt"; resale.description = "Small mark on sleeve"
        library.items[0].resale = resale; library.preferences = WardrobePreferences(reviewOnAdd: true)
        try library.validate()
        let restored = try JSONDecoder().decode(WardrobeLibrary.self, from: JSONEncoder().encode(library))
        XCTAssertEqual(restored.items[0],library.items[0]); XCTAssertEqual(restored.preferences?.reviewOnAdd,true)
        XCTAssertEqual(restored.items.count,48); XCTAssertEqual(restored.outfits,library.outfits)
        library.items[0].price = -1; XCTAssertThrowsError(try library.validate()); library.items[0].price = 10
        library.items[0].productURL = "javascript:alert(1)"; XCTAssertThrowsError(try library.validate())
    }
    func testSwipeDirections() {
        XCTAssertEqual(SwipeWeather.temperature(dx: 0, dy: 100), .cold)
        XCTAssertEqual(SwipeWeather.temperature(dx: 0, dy: -100), .hot)
        XCTAssertEqual(SwipeWeather.temperature(dx: -100, dy: 10), .cool)
        XCTAssertEqual(SwipeWeather.temperature(dx: 100, dy: 10), .mild)
    }
    func testSmallDiagonalOrInvalidSwipesDoNotTag() {
        XCTAssertNil(SwipeWeather.temperature(dx: 55, dy: 0))
        XCTAssertNil(SwipeWeather.temperature(dx: 100, dy: 100))
        XCTAssertNil(SwipeWeather.temperature(dx: -100, dy: 90))
        XCTAssertNil(SwipeWeather.temperature(dx: .nan, dy: 100))
        XCTAssertNil(SwipeWeather.temperature(dx: .infinity, dy: 100))
        XCTAssertEqual(SwipeWeather.temperature(dx: 56, dy: 0), .mild)
    }
    func testWeatherRequiresExplicitRainAndWindSuitability() {
        var rating = WeatherRating(); rating.temperatures = [.cold,.cool]
        XCTAssertTrue(rating.matches(.cool))
        XCTAssertFalse(rating.matches(.hot))
        XCTAssertFalse(rating.matches(.cold, rainy: true))
        XCTAssertFalse(rating.matches(.cold, windy: true))
        rating.rain = .lightRain; rating.wind = .windOK
        XCTAssertTrue(rating.matches(.cold, rainy: true, windy: true))
        rating.rain = .dryOnly
        XCTAssertFalse(rating.matches(.cold, rainy: true))
    }
    func testNeutralAndMultipleTemperatureValidation() {
        var rating = WeatherRating(); XCTAssertFalse(rating.isValid)
        rating.neutral = true; XCTAssertTrue(rating.matches(.hot))
        rating.temperatures = [.cold]; XCTAssertFalse(rating.isValid)
        rating.neutral = false; rating.temperatures = [.cold,.cold]; XCTAssertFalse(rating.isValid)
        rating.temperatures = [.cold,.cool]; XCTAssertTrue(rating.isValid)
        rating.notes = String(repeating: "x", count: 501); XCTAssertFalse(rating.isValid)
    }
    func testVoiceTagsMultipleTemperaturesAndAvoidsNegation() {
        let result = VoiceWeather.apply("cool or mild, dry days only. no wind. note: bring a jacket", to: WeatherRating())
        XCTAssertEqual(result.temperatures, [.cool,.mild]); XCTAssertEqual(result.rain,.dryOnly)
        XCTAssertEqual(result.wind,.avoidWind); XCTAssertEqual(result.notes,"bring a jacket")
        XCTAssertEqual(VoiceWeather.apply("not cold but cool", to: WeatherRating()).temperatures,[.cool])
        XCTAssertEqual(VoiceWeather.apply("not waterproof", to: WeatherRating()).rain,.dryOnly)
        XCTAssertTrue(VoiceWeather.apply("any temperature", to: result).neutral)
        XCTAssertEqual(VoiceWeather.apply("something unclear", to: result), result)
    }
    func testWearUpsertAndStatusChanges() throws {
        var library = try seed(); let outfit = library.outfits[0]
        var log = WearLog(date:"2026-10-01",outfitId:outfit.id,status:.planned,notes:"",updatedAt:"",itemIds:outfit.itemIds)
        try library.setLog(log); XCTAssertEqual(WearAnalytics(library:library).wornDays,0)
        log.status = .worn; try library.setLog(log); try library.setLog(log)
        XCTAssertEqual(library.logs.count,1); XCTAssertEqual(WearAnalytics(library:library).outfitCounts[outfit.id],1)
        log.status = .notWorn; try library.setLog(log)
        XCTAssertEqual(WearAnalytics(library:library).wornDays,0)
    }
    func testAnalyticsDeduplicatesItemDaysAndRetainsWearSnapshot() throws {
        var library = try seed(); let one = library.outfits[0], two = library.outfits[1]
        let piece = library.items[0].id
        for outfit in [one,two] {
            try library.setLog(.init(date:"2026-10-01",outfitId:outfit.id,status:.worn,notes:"",updatedAt:"",itemIds:[piece,piece]))
        }
        try library.setLog(.init(date:"2026-10-02",outfitId:one.id,status:.worn,notes:"",updatedAt:"",itemIds:[piece]))
        library.outfits[0].itemIds = []
        let stats = WearAnalytics(library:library)
        XCTAssertEqual(stats.wornDays,2); XCTAssertEqual(stats.itemDays[piece],2)
        XCTAssertEqual(stats.outfitCounts[one.id],2); XCTAssertEqual(stats.lastWorn[one.id],"2026-10-02")
        XCTAssertEqual(WearAnalytics(library:library,since:"2026-10-02").itemDays[piece],1)
    }
    func testImportedTotalsNeverBecomeDatedWears() throws {
        let library = try seed(); let stats = WearAnalytics(library:library)
        XCTAssertEqual(stats.wornDays,0); XCTAssertTrue(stats.itemDays.isEmpty)
        XCTAssertTrue(stats.outfitCounts.isEmpty)
    }
    func testDateValidationAndTimeZoneBoundary() {
        XCTAssertNil(DateKey.parse("2026-02-30")); XCTAssertNil(DateKey.parse("2026-2-01"))
        XCTAssertNotNil(DateKey.parse("2024-02-29"))
        let date = ISO8601DateFormatter().date(from:"2026-10-28T00:30:00Z")!
        XCTAssertEqual(DateKey.string(date,timeZone:TimeZone(secondsFromGMT:-7*3600)!),"2026-10-27")
        XCTAssertEqual(DateKey.string(date,timeZone:TimeZone(secondsFromGMT:0)!),"2026-10-28")
    }
    func testInvalidOrFutureWearCannotBeLogged() throws {
        var library = try seed(); let outfit = library.outfits[0]
        XCTAssertThrowsError(try library.setLog(.init(date:"2026-02-30",outfitId:outfit.id,status:.worn,notes:"",updatedAt:"")))
        XCTAssertThrowsError(try library.setLog(.init(date:"2026-10-01",outfitId:"missing",status:.worn,notes:"",updatedAt:"")))
        XCTAssertThrowsError(try library.setLog(.init(date:"2999-01-01",outfitId:outfit.id,status:.worn,notes:"",updatedAt:"")))
        XCTAssertNoThrow(try library.setLog(.init(date:"2999-01-01",outfitId:outfit.id,status:.planned,notes:"",updatedAt:"")))
    }
    func testInvalidBackupReferencesAndLayoutsRejected() throws {
        var library = try seed(); library.outfits.append(library.outfits[0])
        XCTAssertThrowsError(try library.validate())
        library = try seed(); library.outfits[0].layers[0].width = -1
        XCTAssertThrowsError(try library.validate())
        library = try seed(); var rating = WeatherRating(); rating.neutral = true; library.ratings["unknown"] = rating
        XCTAssertThrowsError(try library.validate())
    }
}
