import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var exposures: [ExposureEntry]
    @Query private var flares: [FlareEvent]
    @Query private var environments: [EnvironmentEntry]

    private var environmentScores: [TriggerScore] {
        CorrelationEngine().environmentScores(
            environments: HistoryAssembler.environmentRecords(environments),
            flares: HistoryAssembler.flareRecords(flares)
        )
    }

    private var scores: [TriggerScore] {
        CorrelationEngine().triggerScores(
            exposures: HistoryAssembler.exposureRecords(exposures),
            flares: HistoryAssembler.flareRecords(flares)
        )
    }

    private var likelyTriggers: [TriggerScore] {
        Array(scores.filter { $0.flaresPreceded > 0 }.prefix(15))
    }

    private var knownInUse: [TriggerScore] {
        scores.filter { $0.knownAllergen != nil && $0.flaresPreceded == 0 }
    }

    private var aiStatus: AIStatus { AssistantService.status() }

    var body: some View {
        NavigationStack {
            List {
                if flares.isEmpty || exposures.isEmpty {
                    ContentUnavailableView(
                        "Not enough data yet",
                        systemImage: "chart.bar",
                        description: Text("Log the products you use each day, and any flare-ups. Insights appear once there's at least one flare with prior exposures.")
                    )
                } else {
                    Section {
                        ForEach(likelyTriggers) { score in
                            TriggerScoreRow(score: score)
                        }
                        if likelyTriggers.isEmpty {
                            Text("No ingredient has appeared before a flare yet.")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Likely triggers")
                    } footer: {
                        Text("Score combines how many of your flares an ingredient preceded and how often using it was followed by a flare. Everyday ingredients (like water) can rank high simply because they're always present — judge with that in mind.")
                    }

                    if !environmentScores.isEmpty {
                        Section {
                            ForEach(environmentScores) { score in
                                TriggerScoreRow(score: score)
                            }
                        } header: {
                            Text("Environment patterns")
                        } footer: {
                            Text("Weather conditions from your logs that preceded flares, scored the same way as ingredients.")
                        }
                    }

                    if !knownInUse.isEmpty {
                        Section {
                            ForEach(knownInUse) { score in
                                TriggerScoreRow(score: score)
                            }
                        } header: {
                            Text("Known allergens you're using")
                        } footer: {
                            Text("Documented contact allergens or irritants in your products that haven't been linked to your flares so far.")
                        }
                    }
                }

                Section {
                    HStack(alignment: .top) {
                        Image(systemName: aiStatus.available ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(aiStatus.available ? .green : .orange)
                        Text(aiStatus.detail)
                            .font(.callout)
                    }
                } header: {
                    Text("On-device AI")
                } footer: {
                    Text("eXzema surfaces correlations in your own logs to support data-driven decisions. It does not diagnose or treat any condition — see a dermatologist for medical advice. All data stays on this device.")
                }
            }
            .navigationTitle("Insights")
        }
    }
}

private struct TriggerScoreRow: View {
    let score: TriggerScore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(score.ingredient.capitalized)
                    .font(.headline)
                Spacer()
                if score.knownAllergen != nil {
                    BadgeLabel(text: "Known allergen", color: .orange)
                }
            }
            if score.flaresPreceded > 0 {
                ProgressView(value: score.score)
                    .tint(score.score >= 0.5 ? .red : .orange)
                Text("Preceded \(score.flaresPreceded) of \(score.totalFlares) flares · used on \(score.exposureDayCount) day(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let known = score.knownAllergen {
                Text(known.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !score.products.isEmpty {
                Text("In: \(score.products.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
