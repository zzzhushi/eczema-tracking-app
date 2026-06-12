import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ExposureEntry.date, order: .reverse) private var exposures: [ExposureEntry]
    @Query(sort: \EnvironmentEntry.date, order: .reverse) private var environments: [EnvironmentEntry]
    @Query(sort: \Product.name) private var products: [Product]

    @State private var showProductPicker = false
    @State private var showEnvironmentForm = false
    @State private var showFlareForm = false

    private var todayExposures: [ExposureEntry] {
        exposures.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var todayEnvironment: EnvironmentEntry? {
        environments.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Products & foods used today") {
                    if todayExposures.isEmpty {
                        Text("Nothing logged yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(todayExposures) { exposure in
                        HStack {
                            Image(systemName: exposure.product?.category.systemImage ?? "shippingbox")
                                .foregroundStyle(.tint)
                            Text(exposure.product?.name ?? "Deleted product")
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(todayExposures[index]) }
                    }
                    Button {
                        showProductPicker = true
                    } label: {
                        Label("Log products used", systemImage: "plus")
                    }
                }

                Section("Environment") {
                    if let env = todayEnvironment {
                        if !env.locationName.isEmpty {
                            LabeledContent("Location", value: env.locationName)
                        }
                        if let temperature = env.temperatureC {
                            LabeledContent("Temperature", value: "\(Int(temperature)) °C")
                        }
                        if let humidity = env.humidityPercent {
                            LabeledContent("Humidity", value: "\(Int(humidity)) %")
                        }
                        if !env.conditions.isEmpty {
                            LabeledContent("Conditions", value: env.conditions)
                        }
                    } else {
                        Button {
                            showEnvironmentForm = true
                        } label: {
                            Label("Log today's weather", systemImage: "cloud.sun")
                        }
                    }
                }

                Section {
                    Button {
                        showFlareForm = true
                    } label: {
                        Label("Log a flare-up", systemImage: "flame")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Daily logging is what makes the trigger insights trustworthy — even \"nothing new today\" is signal.")
                }
            }
            .navigationTitle(Date.now.formatted(date: .abbreviated, time: .omitted))
            .sheet(isPresented: $showProductPicker) {
                ProductPickerSheet(products: products.filter { !$0.isArchived })
            }
            .sheet(isPresented: $showEnvironmentForm) {
                EnvironmentForm()
            }
            .sheet(isPresented: $showFlareForm) {
                LogFlareView()
            }
        }
    }
}

private struct ProductPickerSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let products: [Product]
    @State private var selected: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            List(products) { product in
                Button {
                    if selected.contains(product.persistentModelID) {
                        selected.remove(product.persistentModelID)
                    } else {
                        selected.insert(product.persistentModelID)
                    }
                } label: {
                    HStack {
                        Image(systemName: product.category.systemImage)
                            .foregroundStyle(.tint)
                        Text(product.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selected.contains(product.persistentModelID) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .overlay {
                if products.isEmpty {
                    ContentUnavailableView(
                        "No products yet",
                        systemImage: "drop",
                        description: Text("Add the products and foods you use in the Products tab first.")
                    )
                }
            }
            .navigationTitle("Used today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        for product in products where selected.contains(product.persistentModelID) {
                            context.insert(ExposureEntry(date: .now, product: product))
                        }
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

private struct EnvironmentForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var location = ""
    @State private var temperature = ""
    @State private var humidity = ""
    @State private var conditions = "Clear"
    @State private var notes = ""

    private let conditionOptions = ["Clear", "Cloudy", "Rain", "Snow", "Windy", "Dry air", "Humid", "Hot", "Cold"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Location (e.g. Seattle)", text: $location)
                TextField("Temperature (°C)", text: $temperature)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Humidity (%)", text: $humidity)
                    .keyboardType(.numbersAndPunctuation)
                Picker("Conditions", selection: $conditions) {
                    ForEach(conditionOptions, id: \.self) { Text($0) }
                }
                Section("Notes") {
                    TextField("Anything else (AC all day, hot shower…)", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Today's environment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(EnvironmentEntry(
                            date: .now,
                            locationName: location,
                            temperatureC: Double(temperature),
                            humidityPercent: Double(humidity),
                            conditions: conditions,
                            notes: notes
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}
