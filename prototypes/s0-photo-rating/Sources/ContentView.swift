import SwiftUI
import PhotosUI

@main
struct ProbeApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var probe = Probe()
    @State private var picks: [PhotosPickerItem] = []
    @State private var contextResult = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Model") { Text(probe.availability) }
                Section("Photos") {
                    PhotosPicker("Choose photos", selection: $picks, maxSelectionCount: 12, matching: .images)
                    ForEach($probe.samples) { $s in
                        VStack(alignment: .leading) {
                            Text("\(s.name) (#\(s.index))").font(.headline)
                            Picker("Area", selection: $s.area) { Text("hands").tag("hands"); Text("face").tag("face") }
                            Picker("Label", selection: $s.label) { Text("unlabeled").tag("unlabeled"); Text("clear").tag("clear"); Text("flare").tag("flare") }
                            Stepper("Minutes-apart group: \(s.group)", value: $s.group, in: 0...6)
                            if !s.runs.isEmpty {
                                Text(s.runs.map { $0.failure ?? $0.scores.map { $0.map(String.init) ?? "-" }.joined() }.joined(separator: "  "))
                                    .font(.caption.monospaced())
                            }
                        }
                    }
                }
                Section("Run") {
                    Button("Rate each photo 5 times") { Task { await probe.runAll() } }.disabled(probe.running || probe.samples.isEmpty)
                    Text(probe.status)
                    Button("Context test (1 to 3 images)") { Task { contextResult = await probe.contextTest() } }.disabled(probe.samples.isEmpty)
                    Text(contextResult).font(.caption.monospaced())
                }
                Section("Summary") {
                    Text(probe.reportJSON()).font(.caption.monospaced())
                    ShareLink("Share report", item: probe.reportJSON())
                }
            }
            .navigationTitle("Rating probe")
            .onChange(of: picks) { Task { await probe.load(picks) } }
        }
    }
}
