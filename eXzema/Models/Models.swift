import Foundation
import SwiftData

enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case skincare
    case makeup
    case sunscreen
    case haircare
    case household
    case food
    case other

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .skincare: return "drop.fill"
        case .makeup: return "paintbrush.pointed"
        case .sunscreen: return "sun.max"
        case .haircare: return "comb"
        case .household: return "house"
        case .food: return "fork.knife"
        case .other: return "shippingbox"
        }
    }
}

@Model
final class Product {
    var name: String = ""
    var categoryRaw: String = ProductCategory.skincare.rawValue
    var ingredientsRaw: String = ""
    var ingredients: [String] = []
    var createdAt: Date = Date()
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ExposureEntry.product)
    var exposures: [ExposureEntry]? = []

    init(name: String, category: ProductCategory, ingredientsRaw: String) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.ingredientsRaw = ingredientsRaw
        self.ingredients = IngredientParser.parse(ingredientsRaw)
        self.createdAt = Date()
    }

    var category: ProductCategory {
        get { ProductCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

@Model
final class ExposureEntry {
    var date: Date = Date()
    var product: Product?

    init(date: Date, product: Product) {
        self.date = date
        self.product = product
    }
}

@Model
final class FlareEvent {
    var date: Date = Date()
    var severity: Int = 5
    var poemScore: Int?
    var bodyAreas: [String] = []
    var notes: String = ""
    var photoFilenames: [String] = []

    init(date: Date, severity: Int, poemScore: Int?, bodyAreas: [String], notes: String, photoFilenames: [String]) {
        self.date = date
        self.severity = severity
        self.poemScore = poemScore
        self.bodyAreas = bodyAreas
        self.notes = notes
        self.photoFilenames = photoFilenames
    }
}

@Model
final class EnvironmentEntry {
    var date: Date = Date()
    var locationName: String = ""
    var temperatureC: Double?
    var humidityPercent: Double?
    var conditions: String = ""
    var notes: String = ""

    init(date: Date, locationName: String, temperatureC: Double?, humidityPercent: Double?, conditions: String, notes: String) {
        self.date = date
        self.locationName = locationName
        self.temperatureC = temperatureC
        self.humidityPercent = humidityPercent
        self.conditions = conditions
        self.notes = notes
    }
}
