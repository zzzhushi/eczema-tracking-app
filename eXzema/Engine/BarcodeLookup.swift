import Foundation

struct BarcodeProduct {
    let code: String
    let name: String
    let brand: String
    let ingredientsText: String

    var displayName: String {
        brand.isEmpty || name.localizedCaseInsensitiveContains(brand) ? name : "\(brand) \(name)"
    }
}

/// Offline barcode → ingredients lookup against a bundled slice of the
/// Open Food Facts / Open Beauty Facts databases (Resources/BarcodeDB.json,
/// regenerated with scripts/build_barcode_db.py). No network is ever used:
/// what you scan stays on the device.
enum BarcodeLookup {
    private struct Entry: Codable {
        let n: String // name
        let b: String // brand
        let i: String // ingredients text
    }

    private static let database: [String: Entry] = {
        guard let url = Bundle.main.url(forResource: "BarcodeDB", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let db = try? JSONDecoder().decode([String: Entry].self, from: data)
        else { return [:] }
        return db
    }()

    static var productCount: Int { database.count }

    static func lookup(_ code: String) -> BarcodeProduct? {
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        // Scanners and the database disagree about leading zeros (UPC-A is
        // often stored as 12 digits but scanned as 13-digit EAN), so try a
        // few canonical forms.
        var candidates = [digits]
        let stripped = String(digits.drop(while: { $0 == "0" }))
        if stripped != digits { candidates.append(stripped) }
        if digits.count < 13 {
            candidates.append(String(repeating: "0", count: 13 - digits.count) + digits)
        }
        for candidate in candidates {
            if let entry = database[candidate] {
                return BarcodeProduct(code: candidate, name: entry.n, brand: entry.b, ingredientsText: entry.i)
            }
        }
        return nil
    }
}
