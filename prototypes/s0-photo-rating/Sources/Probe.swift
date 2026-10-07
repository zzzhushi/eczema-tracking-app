import SwiftUI
import PhotosUI
import Observation

struct Sample: Identifiable {
    let id = UUID()
    let index: Int
    let name: String
    let url: URL
    var area = "hands"
    var label = "unlabeled"
    var group = 0
    var runs: [RunResult] = []
}

@MainActor @Observable
final class Probe {
    var samples: [Sample] = []
    var status = ""
    var running = false
    let runsPerPhoto = 5
    private let rubric = try! Rubric.load()
    var availability: String { Rater(rubric: rubric).availability }

    init() { loadBundled() }

    /// Loads the sanitized fixtures bundled from the git-ignored local folder. A name ending in
    /// `_time2` marks the same skin photographed minutes after the photo it is named after.
    func loadBundled() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let bases = urls.map { Self.base(of: $0) }
        var loaded: [Sample] = []
        for (i, url) in urls.enumerated() {
            let name = url.deletingPathExtension().lastPathComponent
            var s = Sample(index: i + 1, name: name, url: url)
            s.area = name.hasPrefix("face") ? "face" : "hands"
            if bases.filter({ $0 == bases[i] }).count > 1 {
                s.group = (Array(Set(bases.filter { b in bases.filter { $0 == b }.count > 1 })).sorted().firstIndex(of: bases[i]) ?? 0) + 1
            }
            loaded.append(s)
        }
        samples = loaded
    }

    private static func base(of url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.components(separatedBy: "_time").first ?? name
    }

    func load(_ items: [PhotosPickerItem]) async {
        samples = []
        for (i, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let small = image.preparingThumbnail(of: CGSize(width: 1600, height: 1600)),
                  let jpeg = small.jpegData(compressionQuality: 0.85) else { continue }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("probe-\(i).jpg")
            try? jpeg.write(to: url)
            samples.append(Sample(index: i + 1, name: "photo-\(i + 1)", url: url))
        }
    }

    func runAll() async {
        running = true
        let rater = Rater(rubric: rubric)
        for i in samples.indices {
            samples[i].runs = []
            for run in 1...runsPerPhoto {
                status = "Photo \(samples[i].index), run \(run) of \(runsPerPhoto)"
                let result = await rater.rate(imageURLs: [samples[i].url])
                samples[i].runs.append(result)
                print("RUN \(samples[i].name) run=\(run) scores=\(result.scores.map { $0.map(String.init) ?? "-" }.joined(separator: ",")) seconds=\(String(format: "%.1f", result.seconds)) tokens=\(result.promptTokens.map(String.init) ?? "?") failure=\(result.failure ?? "none")")
            }
        }
        status = "Done"
        running = false
    }

    /// Runs the whole evaluation without interaction, prints every result, and exits. Labels come
    /// from launch arguments of the form `label:<name>=clear|flare`.
    func autorun() async {
        UIApplication.shared.isIdleTimerDisabled = true
        for arg in CommandLine.arguments where arg.hasPrefix("label:") {
            let parts = arg.dropFirst(6).split(separator: "=").map(String.init)
            if parts.count == 2, let i = samples.firstIndex(where: { $0.name == parts[0] }) { samples[i].label = parts[1] }
        }
        print("AUTORUN start model=\(availability) photos=\(samples.map(\.name).joined(separator: ","))")
        await runAll()
        print("CONTEXT\n\(await contextTest())")
        print("SUMMARY\n\(reportJSON())")
        print("AUTORUN done")
        exit(0)
    }

    func contextTest() async -> String {
        let rater = Rater(rubric: rubric)
        var lines: [String] = []
        for count in 1...min(3, samples.count) {
            let result = await rater.rate(imageURLs: samples.prefix(count).map(\.url))
            lines.append("\(count) image(s): tokens \(result.promptTokens.map(String.init) ?? "?"), \(result.failure ?? "ok"), \(String(format: "%.1f", result.seconds)) s")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Summary (numbers and opaque photo numbers only)

    struct Summary: Codable {
        var rubricVersion: Int
        var photos: Int
        var runsPerPhoto: Int
        var refusalRate: Double
        var meanSeconds: Double
        var maxSignSpreadPerPhoto: [Int: Int]
        var meanSignDifferenceWithinGroups: [Int: Double]
        var clearBelowFlarePairs: [String: Bool]
    }

    func summary() -> Summary {
        let all = samples.flatMap(\.runs)
        let failed = all.filter { $0.failure != nil }
        var spreads: [Int: Int] = [:]
        for s in samples {
            let ok = s.runs.filter { $0.failure == nil }
            var worst = 0
            for sign in 0..<6 {
                let v = ok.compactMap { $0.scores.indices.contains(sign) ? $0.scores[sign] : nil }
                if let lo = v.min(), let hi = v.max() { worst = max(worst, hi - lo) }
            }
            spreads[s.index] = worst
        }
        var groupDiffs: [Int: Double] = [:]
        for g in Set(samples.map(\.group)).filter({ $0 > 0 }) {
            let members = samples.filter { $0.group == g }
            guard members.count >= 2 else { continue }
            let a = median(members[0]), b = median(members[1])
            let pairs = zip(a, b).compactMap { x, y -> Double? in (x != nil && y != nil) ? abs(Double(x!) - Double(y!)) : nil }
            if !pairs.isEmpty { groupDiffs[g] = pairs.reduce(0, +) / Double(pairs.count) }
        }
        var order: [String: Bool] = [:]
        for clear in samples where clear.label == "clear" {
            for flare in samples where flare.label == "flare" && flare.area == clear.area {
                let a = median(clear), b = median(flare)
                let shared = a.indices.filter { a[$0] != nil && b[$0] != nil }
                order["\(clear.index)<\(flare.index)"] = shared.reduce(0) { $0 + a[$1]! } < shared.reduce(0) { $0 + b[$1]! }
            }
        }
        return Summary(
            rubricVersion: rubric.version, photos: samples.count, runsPerPhoto: runsPerPhoto,
            refusalRate: all.isEmpty ? 0 : Double(failed.count) / Double(all.count),
            meanSeconds: all.isEmpty ? 0 : all.map(\.seconds).reduce(0, +) / Double(all.count),
            maxSignSpreadPerPhoto: spreads, meanSignDifferenceWithinGroups: groupDiffs, clearBelowFlarePairs: order)
    }

    private func median(_ s: Sample) -> [Int?] {
        let ok = s.runs.filter { $0.failure == nil }
        return (0..<6).map { sign in
            let v = ok.compactMap { $0.scores.indices.contains(sign) ? $0.scores[sign] : nil }.sorted()
            return v.isEmpty ? nil : v[v.count / 2]
        }
    }

    func reportJSON() -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(data: enc.encode(summary()), encoding: .utf8)) ?? "{}"
    }
}
