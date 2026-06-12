import XCTest
@testable import eXzema

final class CorrelationEngineTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testConsistentTriggerOutranksDailyStaple() {
        // "mi cream" (methylisothiazolinone) used on 3 days, each followed by
        // a flare the next day. "water" used every single day.
        var exposures: [ExposureRecord] = []
        for offset in 0...24 {
            exposures.append(ExposureRecord(day: day(offset), productName: "Daily Lotion", ingredients: ["water", "glycerin"]))
        }
        for offset in [0, 10, 20] {
            exposures.append(ExposureRecord(day: day(offset), productName: "MI Cream", ingredients: ["methylisothiazolinone"]))
        }
        let flares = [1, 11, 21].map { FlareRecord(day: day($0), severity: 6) }

        let scores = CorrelationEngine(windowDays: 3).triggerScores(exposures: exposures, flares: flares)

        let mi = scores.first { $0.ingredient == "methylisothiazolinone" }
        let water = scores.first { $0.ingredient == "water" }
        XCTAssertNotNil(mi)
        XCTAssertNotNil(water)
        XCTAssertEqual(mi?.flaresPreceded, 3)
        XCTAssertEqual(mi?.totalFlares, 3)
        XCTAssertEqual(mi?.precision ?? 0, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(mi!.score, water!.score)
        XCTAssertEqual(scores.first?.ingredient, "methylisothiazolinone")
    }

    func testIngredientNeverNearFlareIsExcluded() {
        let exposures = [
            ExposureRecord(day: day(0), productName: "Trigger Cream", ingredients: ["methylisothiazolinone"]),
            ExposureRecord(day: day(20), productName: "Safe Serum", ingredients: ["squalane"]),
        ]
        let flares = [FlareRecord(day: day(1), severity: 5)]

        let scores = CorrelationEngine(windowDays: 3).triggerScores(exposures: exposures, flares: flares)

        XCTAssertFalse(scores.contains { $0.ingredient == "squalane" })
        XCTAssertTrue(scores.contains { $0.ingredient == "methylisothiazolinone" })
    }

    func testKnownAllergenSurfacesEvenWithoutFlareAssociation() {
        let exposures = [
            ExposureRecord(day: day(0), productName: "Fragranced Lotion", ingredients: ["fragrance"]),
        ]
        let scores = CorrelationEngine(windowDays: 3).triggerScores(exposures: exposures, flares: [
            FlareRecord(day: day(15), severity: 4),
        ])

        let fragrance = scores.first { $0.ingredient == "fragrance" }
        XCTAssertNotNil(fragrance)
        XCTAssertEqual(fragrance?.flaresPreceded, 0)
        XCTAssertNotNil(fragrance?.knownAllergen)
    }
}

final class IngredientParserTests: XCTestCase {
    func testParsingNormalizesAliasesAndSeparators() {
        let parsed = IngredientParser.parse("Ingredients: Aqua, Parfum; Glycerin\nOctocrylene, Water (Aqua)")
        XCTAssertEqual(parsed, ["water", "fragrance", "glycerin", "octocrylene"])
    }

    func testKnownAllergenMatching() {
        XCTAssertEqual(KnownAllergenCatalog.match("Oxybenzone")?.name, "benzophenone-3")
        XCTAssertEqual(KnownAllergenCatalog.match("PARFUM")?.name, "fragrance")
        XCTAssertEqual(KnownAllergenCatalog.match("methylchloroisothiazolinone")?.name, "methylchloroisothiazolinone")
        XCTAssertNil(KnownAllergenCatalog.match("glycerin"))
    }
}
