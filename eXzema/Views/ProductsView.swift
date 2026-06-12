import SwiftUI
import SwiftData

struct ProductsView: View {
    @Query(sort: \Product.name) private var products: [Product]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProductCategory.allCases) { category in
                    let items = products.filter { $0.category == category && !$0.isArchived }
                    if !items.isEmpty {
                        Section(category.label) {
                            ForEach(items) { product in
                                NavigationLink {
                                    ProductDetailView(product: product)
                                } label: {
                                    HStack {
                                        Image(systemName: category.systemImage)
                                            .foregroundStyle(.tint)
                                        VStack(alignment: .leading) {
                                            Text(product.name)
                                            Text("\(product.ingredients.count) ingredients")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if products.filter({ !$0.isArchived }).isEmpty {
                    ContentUnavailableView(
                        "No products yet",
                        systemImage: "drop",
                        description: Text("Add the skincare, makeup, sunscreen, and foods you use. Their ingredients power your trigger insights.")
                    )
                }
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add product", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddProductView()
            }
        }
    }
}

struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: ProductCategory = .skincare
    @State private var ingredientsText = ""
    @State private var showScanner = false

    private var parsedCount: Int { IngredientParser.parse(ingredientsText).count }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(ProductCategory.allCases) { category in
                        Label(category.label, systemImage: category.systemImage).tag(category)
                    }
                }
                Section {
                    TextField("Paste or type the ingredient list, separated by commas", text: $ingredientsText, axis: .vertical)
                        .lineLimit(4...12)
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan label or barcode", systemImage: "camera.viewfinder")
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text(parsedCount > 0 ? "\(parsedCount) ingredients detected." : "Tip: tap a barcode to look the product up offline, or point at the INCI list and tap each line of text.")
                }
            }
            .navigationTitle("New product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Product(name: name, category: category, ingredientsRaw: ingredientsText))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerSheet { scanned in
                    if ingredientsText.isEmpty {
                        ingredientsText = scanned
                    } else {
                        ingredientsText += ", " + scanned
                    }
                } onProduct: { product in
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        name = product.displayName
                    }
                    ingredientsText = product.ingredientsText
                }
            }
        }
    }
}

struct ProductDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let product: Product

    @Query private var exposures: [ExposureEntry]
    @Query private var flares: [FlareEvent]

    private var scoresByIngredient: [String: TriggerScore] {
        let scores = CorrelationEngine().triggerScores(
            exposures: HistoryAssembler.exposureRecords(exposures),
            flares: HistoryAssembler.flareRecords(flares)
        )
        return Dictionary(uniqueKeysWithValues: scores.map { ($0.ingredient, $0) })
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Category", value: product.category.label)
                LabeledContent("Times logged", value: "\(product.exposures?.count ?? 0)")
            }
            Section("Ingredients") {
                if product.ingredients.isEmpty {
                    Text("No ingredients recorded.")
                        .foregroundStyle(.secondary)
                }
                ForEach(product.ingredients, id: \.self) { ingredient in
                    IngredientRow(
                        ingredient: ingredient,
                        personal: scoresByIngredient[ingredient],
                        known: KnownAllergenCatalog.match(ingredient)
                    )
                }
            }
            Section {
                Button("Delete product", role: .destructive) {
                    context.delete(product)
                    dismiss()
                }
            } footer: {
                Text("Deleting also removes its usage history, which weakens your insights. Consider keeping discontinued products.")
            }
        }
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shared row showing an ingredient with personal-history and known-allergen badges.
struct IngredientRow: View {
    let ingredient: String
    let personal: TriggerScore?
    let known: KnownAllergen?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ingredient.capitalized)
                Spacer()
                if let personal, personal.flaresPreceded > 0 {
                    BadgeLabel(text: "Your trigger?", color: .red)
                }
                if known != nil {
                    BadgeLabel(text: "Known allergen", color: .orange)
                }
            }
            if let personal, personal.flaresPreceded > 0 {
                Text("Preceded \(personal.flaresPreceded) of \(personal.totalFlares) flares · used on \(personal.exposureDayCount) day(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let known {
                Text(known.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
