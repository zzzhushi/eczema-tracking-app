import SwiftUI
import SwiftData
import PhotosUI
import Charts

struct FlaresView: View {
    @Query(sort: \FlareEvent.date, order: .reverse) private var flares: [FlareEvent]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if flares.count >= 2 {
                    Section("Severity over time") {
                        Chart(flares) { flare in
                            LineMark(
                                x: .value("Date", flare.date),
                                y: .value("Severity", flare.severity)
                            )
                            PointMark(
                                x: .value("Date", flare.date),
                                y: .value("Severity", flare.severity)
                            )
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 160)
                        .padding(.vertical, 8)
                    }
                }
                Section {
                    ForEach(flares) { flare in
                        NavigationLink {
                            FlareDetailView(flare: flare)
                        } label: {
                            FlareRow(flare: flare)
                        }
                    }
                }
            }
            .overlay {
                if flares.isEmpty {
                    ContentUnavailableView(
                        "No flares logged",
                        systemImage: "flame",
                        description: Text("Hopefully it stays that way. When one happens, log it here so the app can look back at what preceded it.")
                    )
                }
            }
            .navigationTitle("Flares")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PhotoTimelineView()
                    } label: {
                        Label("Progress", systemImage: "photo.on.rectangle.angled")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Label("Log flare", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                LogFlareView()
            }
        }
    }
}

private struct FlareRow: View {
    let flare: FlareEvent

    private var severityColor: Color {
        switch flare.severity {
        case 7...: return .red
        case 4...6: return .orange
        default: return .yellow
        }
    }

    var body: some View {
        HStack {
            Text("\(flare.severity)")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(severityColor.opacity(0.2), in: Circle())
                .foregroundStyle(severityColor)
            VStack(alignment: .leading) {
                Text(flare.date.formatted(date: .abbreviated, time: .omitted))
                if !flare.bodyAreas.isEmpty {
                    Text(flare.bodyAreas.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !flare.photoFilenames.isEmpty {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct FlareDetailView: View {
    let flare: FlareEvent
    @Query private var exposures: [ExposureEntry]
    @Query private var flares: [FlareEvent]
    @Query private var environments: [EnvironmentEntry]

    private let windowDays = 3

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -windowDays, to: Calendar.current.startOfDay(for: flare.date)) ?? flare.date
    }

    private var windowExposures: [ExposureEntry] {
        exposures.filter { $0.date >= windowStart && $0.date <= flare.date }
    }

    private var suspects: [TriggerScore] {
        let windowIngredients = Set(windowExposures.flatMap { $0.product?.ingredients ?? [] })
        let scores = CorrelationEngine(windowDays: windowDays).triggerScores(
            exposures: HistoryAssembler.exposureRecords(exposures),
            flares: HistoryAssembler.flareRecords(flares)
        )
        return Array(scores.filter { windowIngredients.contains($0.ingredient) && $0.flaresPreceded > 0 }.prefix(8))
    }

    private var windowEnvironments: [EnvironmentEntry] {
        environments.filter { $0.date >= windowStart && $0.date <= flare.date }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: flare.date.formatted(date: .long, time: .omitted))
                LabeledContent("Severity", value: "\(flare.severity) / 10")
                if let poem = flare.poemScore {
                    LabeledContent("POEM score", value: "\(poem) / 28")
                }
                if !flare.bodyAreas.isEmpty {
                    LabeledContent("Areas", value: flare.bodyAreas.joined(separator: ", "))
                }
            }

            if !flare.photoFilenames.isEmpty {
                Section("Photos") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(flare.photoFilenames, id: \.self) { filename in
                                if let image = PhotoStore.image(named: filename) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 140, height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !flare.notes.isEmpty {
                Section("Notes") {
                    Text(flare.notes)
                }
            }

            Section {
                if suspects.isEmpty {
                    Text("No exposures logged in the \(windowDays) days before this flare. The more you log, the better this gets.")
                        .foregroundStyle(.secondary)
                }
                ForEach(suspects) { suspect in
                    IngredientRow(ingredient: suspect.ingredient, personal: suspect, known: suspect.knownAllergen)
                }
            } header: {
                Text("Suspected triggers (\(windowDays) days before)")
            } footer: {
                Text("Ranked by how consistently each ingredient appears before your flares across your whole history. Correlation, not diagnosis.")
            }

            if !windowEnvironments.isEmpty {
                Section("Environment in that window") {
                    ForEach(windowEnvironments) { env in
                        VStack(alignment: .leading) {
                            Text(env.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text([
                                env.conditions.isEmpty ? nil : env.conditions,
                                env.temperatureC.map { "\(Int($0)) °C" },
                                env.humidityPercent.map { "\(Int($0)) % humidity" },
                            ].compactMap(\.self).joined(separator: " · "))
                        }
                    }
                }
            }
        }
        .navigationTitle("Flare")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Chronological wall of all flare photos — the visual record of how the
/// skin is doing across flares. (Photo-based AI severity scoring is planned
/// once Foundation Models image input ships in the iOS 27 SDK.)
struct PhotoTimelineView: View {
    @Query(sort: \FlareEvent.date, order: .reverse) private var flares: [FlareEvent]

    private var flaresWithPhotos: [FlareEvent] {
        flares.filter { !$0.photoFilenames.isEmpty }
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 7...: return .red
        case 4...6: return .orange
        default: return .yellow
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(flaresWithPhotos) { flare in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(flare.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Spacer()
                            BadgeLabel(text: "Severity \(flare.severity)", color: severityColor(flare.severity))
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(flare.photoFilenames, id: \.self) { filename in
                                    if let image = PhotoStore.image(named: filename) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 170, height: 170)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                        if !flare.bodyAreas.isEmpty {
                            Text(flare.bodyAreas.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .overlay {
            if flaresWithPhotos.isEmpty {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "photo",
                    description: Text("Photos you attach to flares appear here as a timeline, so you can see your skin's progress over time.")
                )
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LogFlareView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var severity: Double = 5
    @State private var selectedAreas: Set<String> = []
    @State private var notes = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photoFilenames: [String] = []
    @State private var includePOEM = false
    @State private var poemAnswers = [Int](repeating: 0, count: 7)

    private let areas = ["Face", "Neck", "Hands", "Arms", "Legs", "Torso", "Scalp", "Other"]
    private let poemQuestions = [
        "Days with itchy skin",
        "Nights with disturbed sleep",
        "Days with bleeding skin",
        "Days with weeping or oozing",
        "Days with cracked skin",
        "Days with flaking skin",
        "Days with dry or rough skin",
    ]
    private let poemOptions = ["0 days", "1–2 days", "3–4 days", "5–6 days", "Every day"]

    private var poemTotal: Int { poemAnswers.reduce(0, +) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)

                Section("Severity: \(Int(severity)) / 10") {
                    Slider(value: $severity, in: 0...10, step: 1)
                }

                Section("Affected areas") {
                    ForEach(areas, id: \.self) { area in
                        Button {
                            if selectedAreas.contains(area) {
                                selectedAreas.remove(area)
                            } else {
                                selectedAreas.insert(area)
                            }
                        } label: {
                            HStack {
                                Text(area)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedAreas.contains(area) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                    }
                    if !photoFilenames.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(photoFilenames, id: \.self) { filename in
                                    if let image = PhotoStore.image(named: filename) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Photos are stored only inside this app's encrypted storage on this device.")
                }

                Section {
                    Toggle("Add POEM score", isOn: $includePOEM)
                    if includePOEM {
                        ForEach(0..<7, id: \.self) { index in
                            Picker(poemQuestions[index], selection: $poemAnswers[index]) {
                                ForEach(0..<5, id: \.self) { value in
                                    Text(poemOptions[value]).tag(value)
                                }
                            }
                        }
                        LabeledContent("POEM total", value: "\(poemTotal) / 28")
                    }
                } footer: {
                    Text("POEM (Patient-Oriented Eczema Measure) is a validated 7-question score about the past week. Optional, but great for tracking trends.")
                }

                Section("Notes") {
                    TextField("What changed recently? New product, food, stress…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Log flare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        for filename in photoFilenames { PhotoStore.delete(filename) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(FlareEvent(
                            date: date,
                            severity: Int(severity),
                            poemScore: includePOEM ? poemTotal : nil,
                            bodyAreas: Array(selectedAreas).sorted(),
                            notes: notes,
                            photoFilenames: photoFilenames
                        ))
                        dismiss()
                    }
                }
            }
            .onChange(of: photoItems) {
                Task {
                    for item in photoItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let filename = PhotoStore.save(data) {
                            photoFilenames.append(filename)
                        }
                    }
                    photoItems = []
                }
            }
        }
    }
}
