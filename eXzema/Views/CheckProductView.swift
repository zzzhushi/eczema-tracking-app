import SwiftUI
import SwiftData

/// "Can I try this product?" — paste or scan an ingredient list and check it
/// against your personal flare history and the bundled allergen catalog,
/// before it ever touches your skin.
struct CheckProductView: View {
    @Query private var exposures: [ExposureEntry]
    @Query private var flares: [FlareEvent]

    @State private var name = ""
    @State private var ingredientsText = ""
    @State private var showScanner = false
    @State private var verdict: ProductVerdict?
    @State private var isChecking = false

    private var parsed: [String] { IngredientParser.parse(ingredientsText) }

    private var scoresByIngredient: [String: TriggerScore] {
        let scores = CorrelationEngine().triggerScores(
            exposures: HistoryAssembler.exposureRecords(exposures),
            flares: HistoryAssembler.flareRecords(flares)
        )
        return Dictionary(uniqueKeysWithValues: scores.map { ($0.ingredient, $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product to check") {
                    TextField("Name (optional)", text: $name)
                    TextField("Paste or type the ingredient list", text: $ingredientsText, axis: .vertical)
                        .lineLimit(4...12)
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan ingredient label", systemImage: "camera.viewfinder")
                    }
                }

                if !parsed.isEmpty {
                    Section("Ingredients (\(parsed.count))") {
                        ForEach(parsed, id: \.self) { ingredient in
                            IngredientRow(
                                ingredient: ingredient,
                                personal: scoresByIngredient[ingredient],
                                known: KnownAllergenCatalog.match(ingredient)
                            )
                        }
                    }

                    Section {
                        Button {
                            check()
                        } label: {
                            if isChecking {
                                HStack {
                                    ProgressView()
                                    Text("Checking…")
                                }
                            } else {
                                Label("Check against my history", systemImage: "checkmark.shield")
                            }
                        }
                        .disabled(isChecking)
                    }
                }

                if let verdict {
                    Section {
                        HStack {
                            Text("Risk")
                            Spacer()
                            BadgeLabel(text: verdict.riskLevel.capitalized, color: riskColor(verdict.riskLevel))
                        }
                        Text(verdict.summary)
                        if !verdict.ingredientsOfConcern.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch out for")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(verdict.ingredientsOfConcern.joined(separator: ", "))
                            }
                        }
                        ForEach(verdict.suggestions, id: \.self) { suggestion in
                            Label(suggestion, systemImage: "lightbulb")
                                .font(.callout)
                        }
                    } header: {
                        Text(verdict.usedAI ? "Assessment (on-device AI)" : "Assessment (rule-based)")
                    } footer: {
                        Text("Based only on your own logs and a bundled catalog of documented allergens. Not medical advice.")
                    }
                }
            }
            .navigationTitle("Check a product")
            .sheet(isPresented: $showScanner) {
                ScannerSheet { scanned in
                    if ingredientsText.isEmpty {
                        ingredientsText = scanned
                    } else {
                        ingredientsText += ", " + scanned
                    }
                }
            }
        }
    }

    private func check() {
        let ingredients = parsed
        let scores = scoresByIngredient
        let personalHits = ingredients.compactMap { scores[$0] }.filter { $0.flaresPreceded > 0 }
        let knownHits = ingredients.compactMap { KnownAllergenCatalog.match($0) }
        isChecking = true
        verdict = nil
        Task {
            verdict = await AssistantService.assess(
                productName: name,
                ingredients: ingredients,
                personalHits: personalHits,
                knownHits: knownHits
            )
            isChecking = false
        }
    }

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "high": return .red
        case "caution": return .orange
        default: return .green
        }
    }
}
