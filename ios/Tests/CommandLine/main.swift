import Foundation
let tests = WardrobeCoreTests()
var passed = 0
func run(_ name: String, _ action: () throws -> Void) {
    let before = failures
    do { try action(); if failures == before { passed += 1; print("PASS \(name)") } }
    catch { failures += 1; print("FAIL \(name): \(error)") }
}
run("testSeedPreservesWardrobeAndEditableBoards", tests.testSeedPreservesWardrobeAndEditableBoards)
run("testSwipeDirections", tests.testSwipeDirections)
run("testSmallDiagonalOrInvalidSwipesDoNotTag", tests.testSmallDiagonalOrInvalidSwipesDoNotTag)
run("testWeatherRequiresExplicitRainAndWindSuitability", tests.testWeatherRequiresExplicitRainAndWindSuitability)
run("testNeutralAndMultipleTemperatureValidation", tests.testNeutralAndMultipleTemperatureValidation)
run("testVoiceTagsMultipleTemperaturesAndAvoidsNegation", tests.testVoiceTagsMultipleTemperaturesAndAvoidsNegation)
run("testWearUpsertAndStatusChanges", tests.testWearUpsertAndStatusChanges)
run("testAnalyticsDeduplicatesItemDaysAndRetainsWearSnapshot", tests.testAnalyticsDeduplicatesItemDaysAndRetainsWearSnapshot)
run("testImportedTotalsNeverBecomeDatedWears", tests.testImportedTotalsNeverBecomeDatedWears)
run("testDateValidationAndTimeZoneBoundary", tests.testDateValidationAndTimeZoneBoundary)
run("testInvalidOrFutureWearCannotBeLogged", tests.testInvalidOrFutureWearCannotBeLogged)
run("testInvalidBackupReferencesAndLayoutsRejected", tests.testInvalidBackupReferencesAndLayoutsRejected)
run("testPricesAndResaleAreOptionalAndSurviveBackup", tests.testPricesAndResaleAreOptionalAndSurviveBackup)
print("\(passed)/13 test groups passed; \(failures) failures")
exit(failures == 0 ? 0 : 1)
