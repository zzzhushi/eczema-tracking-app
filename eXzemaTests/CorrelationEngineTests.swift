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

final class EnvironmentCorrelationTests: XCTestCase {
    private let calendar = Calendar.current

    private func day(_ offset: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testColdDryDaysPrecedingFlaresAreScored() {
        // Cold, dry days on 0 and 10 each precede a flare; mild days don't.
        var environments: [EnvironmentRecord] = []
        for offset in 0...12 {
            let cold = offset == 0 || offset == 10
            environments.append(EnvironmentRecord(
                day: day(offset),
                factors: cold ? ["cold weather (≤5 °C)", "dry air (≤35% humidity)"] : ["humid air (≥70% humidity)"]
            ))
        }
        let flares = [1, 11].map { FlareRecord(day: day($0), severity: 6) }

        let scores = CorrelationEngine(windowDays: 3).environmentScores(environments: environments, flares: flares)

        let cold = scores.first { $0.ingredient == "cold weather (≤5 °C)" }
        XCTAssertNotNil(cold)
        XCTAssertEqual(cold?.kind, .environment)
        XCTAssertEqual(cold?.flaresPreceded, 2)
        XCTAssertEqual(cold?.precision ?? 0, 1.0, accuracy: 0.001)
        // Humid days were present before flares too (window overlaps), but
        // with far lower precision, so cold must outrank humid.
        if let humid = scores.first(where: { $0.ingredient == "humid air (≥70% humidity)" }) {
            XCTAssertGreaterThan(cold!.score, humid.score)
        }
    }

    func testEnvironmentFactorBucketing() {
        let entry = EnvironmentEntry(date: .now, locationName: "", temperatureC: 2, humidityPercent: 20, conditions: "Windy", notes: "")
        let factors = HistoryAssembler.environmentFactors(entry)
        XCTAssertTrue(factors.contains("cold weather (≤5 °C)"))
        XCTAssertTrue(factors.contains("dry air (≤35% humidity)"))
        XCTAssertTrue(factors.contains("windy"))

        let mild = EnvironmentEntry(date: .now, locationName: "", temperatureC: 20, humidityPercent: 50, conditions: "Clear", notes: "")
        XCTAssertTrue(HistoryAssembler.environmentFactors(mild).isEmpty)
    }
}

final class BarcodeLookupTests: XCTestCase {
    func testDatabaseIsBundledAndUnknownCodesMiss() {
        XCTAssertGreaterThan(BarcodeLookup.productCount, 100, "BarcodeDB.json should be bundled with a real slice")
        XCTAssertNil(BarcodeLookup.lookup("0000000000000"))
        XCTAssertNil(BarcodeLookup.lookup("not-a-barcode"))
    }

    func testKnownCodeResolvesWithLeadingZeroVariants() throws {
        // Nutella's EAN is a stable fixture of the popularity-ranked slice.
        let product = try XCTUnwrap(BarcodeLookup.lookup("3017620425035"))
        XCTAssertFalse(product.ingredientsText.isEmpty)
        XCTAssertNotNil(BarcodeLookup.lookup("03017620425035"), "leading zeros should be normalized away")
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
