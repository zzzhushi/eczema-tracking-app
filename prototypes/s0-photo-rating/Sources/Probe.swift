import FoundationModels
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

/// Prints a result line and appends it to the results file in the app's Documents folder, so a run
/// survives the Mac's console connection dropping.
func emit(_ line: String) {
    print(line)
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.log")
    let data = Data((line + "\n").utf8)
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: url)
    }
}

@MainActor @Observable
final class Probe {
    var samples: [Sample] = []
    var status = ""
    var running = false
    let runsPerPhoto = CommandLine.arguments.contains("-once") ? 1 : 5
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
                let result = CommandLine.arguments.contains("-prompt2") ? await rater.rateV2(imageURLs: [samples[i].url]) : await rater.rate(imageURLs: [samples[i].url])
                samples[i].runs.append(result)
                emit("RUN \(samples[i].name) run=\(run) scores=\(result.scores.map { $0.map(String.init) ?? "-" }.joined(separator: ",")) seconds=\(String(format: "%.1f", result.seconds)) tokens=\(result.promptTokens.map(String.init) ?? "?") failure=\(result.failure ?? "none") obs=\(result.observations ?? "")")
            }
        }
        status = "Done"
        running = false
    }

    /// Runs the whole evaluation without interaction, prints every result, and exits. Labels come
    /// from launch arguments of the form `label:<name>=clear|flare`.
    func autorun() async {
        UIApplication.shared.isIdleTimerDisabled = true
        try? FileManager.default.removeItem(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("results.log"))
        for arg in CommandLine.arguments where arg.hasPrefix("label:") {
            let parts = arg.dropFirst(6).split(separator: "=").map(String.init)
            if parts.count == 2, let i = samples.firstIndex(where: { $0.name == parts[0] }) { samples[i].label = parts[1] }
        }
        emit("AUTORUN start greedy=\(CommandLine.arguments.contains("-greedy")) model=\(availability) photos=\(samples.map(\.name).joined(separator: ","))")
        if CommandLine.arguments.contains("-compare") { await compareAll() }
        if CommandLine.arguments.contains("-anchored") { await anchoredAll() }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("-variants=") }) {
            await variantRound(arg.dropFirst(10).split(separator: ",").compactMap { Variant(rawValue: String($0)) })
        }
        if CommandLine.arguments.contains(where: { $0.hasPrefix("-pairs") }) { await pairRound() }
        if !CommandLine.arguments.contains("-noscore") { await runAll() }
        if !CommandLine.arguments.contains("-nocontext") { emit("CONTEXT\n\(await contextTest())") }
        emit("SUMMARY\n\(reportJSON())")
        emit("AUTORUN done")
        exit(0)
    }

    /// Asks which of two photos is worse, in both orders so position bias shows up.
    func compareAll() async {
        let rater = Rater(rubric: rubric)
        let pairs = [("face_clear", "face"), ("face", "face_flare"), ("face_clear", "face_flare"),
                     ("hand_normal_patch", "right"), ("right", "right_time2"), ("right", "left"), ("left", "right_time2")]
        let area = CommandLine.arguments.first { $0.hasPrefix("-pairs=") }?.dropFirst(7)
        for (a, b) in pairs where area == nil || (area == "face") == a.hasPrefix("face") {
            guard let sa = samples.first(where: { $0.name == a }), let sb = samples.first(where: { $0.name == b }) else { continue }
            for (x, y) in [(sa, sb), (sb, sa)] {
                let r = await rater.compare(first: x.url, second: y.url)
                emit("PAIR first=\(x.name) second=\(y.name) worse=\(r.judgment?.worse ?? "-") difference=\(r.judgment.map { String($0.difference) } ?? "-") seconds=\(String(format: "%.1f", r.seconds)) failure=\(r.failure ?? "none") obs=\(r.judgment?.observations ?? "")")
            }
        }
    }

    /// Rates each photo against the clear-skin reference for its area, with the reference shown
    /// both before and after the photo so position bias shows up.
    func anchoredAll() async {
        let rater = Rater(rubric: rubric)
        let references = ["face": "face_clear", "hands": "hand_normal_patch"]
        for s in samples {
            guard let refName = references[s.area], let ref = samples.first(where: { $0.name == refName }) else { continue }
            for referenceFirst in [true, false] {
                let r = await rater.rateAgainst(reference: ref.url, photo: s.url, referenceFirst: referenceFirst)
                emit("ANCHORED photo=\(s.name) referenceFirst=\(referenceFirst) overall=\(r.rating.map { String($0.overall) } ?? "-") coverage=\(r.rating?.coverage ?? "-") regions=\(r.rating?.regions.joined(separator: "|") ?? "-") seconds=\(String(format: "%.1f", r.seconds)) failure=\(r.failure ?? "none") obs=\(r.rating?.differences ?? "")")
            }
        }
    }

    /// Runs each variant on every photo against its area's clear-skin reference, in both orders,
    /// and prints one line per call. Results are judged offline against the local manifest.
    func variantRound(_ variants: [Variant]) async {
        let rater = Rater(rubric: rubric)
        let references = ["face": "face_clear", "hands": "hand_normal_patch"]
        func clean(_ text: String) -> String { text.replacingOccurrences(of: "\n", with: " ") }
        let only = Set(CommandLine.arguments.first { $0.hasPrefix("-photos=") }?.dropFirst(8).split(separator: ",").map(String.init) ?? [])
        for variant in variants {
            for s in samples where only.isEmpty || only.contains(s.name) {
                guard let refName = references[s.area], let ref = samples.first(where: { $0.name == refName }) else { continue }
                let head = "V variant=\(variant.rawValue) photo=\(s.name)"
                switch variant {
                case .perception:
                    let (r, t, f) = await rater.ask(Perception.self, instructions: AnchoredPrompts.perception, prompt: rater.describePrompt(photo: s.url))
                    emit("\(head) bodyPart=\(r?.bodyPart ?? "-") anyRedness=\(r.map { String($0.anyRedness) } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.description ?? ""))")
                case .relative2Sampled:
                    var sampler = rater
                    sampler.greedy = false
                    var sums: [Int] = []
                    for _ in 1...5 {
                        let (r, _, _) = await sampler.ask(RelativeSigns.self, instructions: AnchoredPrompts.relative2, prompt: rater.anchoredPrompt(reference: ref.url, photo: s.url, referenceFirst: true))
                        if let r { sums.append(r.levels.reduce(0, +)) }
                    }
                    let mean = sums.isEmpty ? -1 : Double(sums.reduce(0, +)) / Double(sums.count)
                    emit("\(head) refFirst=true sums=\(sums.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) obs=")
                case .relative2BoostSampled:
                    var sampler = rater
                    sampler.greedy = false
                    var maxes: [Int] = []
                    var runs: [String] = []
                    for _ in 1...5 {
                        let (r, _, _) = await sampler.ask(RelativeSigns.self, instructions: AnchoredPrompts.relative2, prompt: rater.anchoredPrompt(reference: boosted(ref.url), photo: boosted(s.url), referenceFirst: true))
                        if let r { maxes.append(r.levels.max() ?? 0); runs.append(r.levels.map(String.init).joined()) }
                    }
                    let mean = maxes.isEmpty ? -1 : Double(maxes.reduce(0, +)) / Double(maxes.count)
                    emit("\(head) refFirst=true maxes=\(maxes.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) signs=\(runs.joined(separator: ";")) obs=")
                case .relative7BoostSampled:
                    var sampler = rater
                    sampler.greedy = false
                    var maxes: [Int] = []
                    var runs: [String] = []
                    for _ in 1...5 {
                        let (r, _, _) = await sampler.ask(RelativeSigns7.self, instructions: AnchoredPrompts.relative2, prompt: rater.anchoredPrompt(reference: boosted(ref.url), photo: boosted(s.url), referenceFirst: true))
                        if let r { maxes.append(r.levels.max() ?? 0); runs.append(r.levels.map(String.init).joined()) }
                    }
                    let mean = maxes.isEmpty ? -1 : Double(maxes.reduce(0, +)) / Double(maxes.count)
                    emit("\(head) refFirst=true maxes=\(maxes.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) signs=\(runs.joined(separator: ";")) obs=")
                case .pairBoost:
                    break
                case .swellingRef, .swellingEyes, .swellingNoRef:
                    var sampler = rater
                    sampler.greedy = false
                    let runs = Int(CommandLine.arguments.first { $0.hasPrefix("-runs=") }?.dropFirst(6) ?? "") ?? 5
                    var levels: [Int] = []
                    var notes: [String] = []
                    for _ in 1...runs {
                        switch variant {
                        case .swellingNoRef:
                            let (r, _, f) = await sampler.ask(SwellingAlone.self, instructions: AnchoredPrompts.swellingNoRef, prompt: rater.ratePrompt(photo: s.url))
                            levels.append(r?.level ?? -1); notes.append(r?.eyes ?? (f ?? ""))
                        case .swellingEyes:
                            guard let refEyes = eyeRegion(of: ref.url), let eyes = eyeRegion(of: s.url) else { levels.append(-1); notes.append("no face found"); continue }
                            let (r, _, f) = await sampler.ask(SwellingCompared.self, instructions: AnchoredPrompts.swellingEyes, prompt: rater.anchoredPrompt(reference: refEyes, photo: eyes, referenceFirst: true, noun: "crop"))
                            levels.append(r?.level ?? -1); notes.append(r?.new ?? (f ?? ""))
                        default:
                            let (r, _, f) = await sampler.ask(SwellingCompared.self, instructions: AnchoredPrompts.swellingRef, prompt: rater.anchoredPrompt(reference: ref.url, photo: s.url, referenceFirst: true))
                            levels.append(r?.level ?? -1); notes.append(r?.new ?? (f ?? ""))
                        }
                    }
                    let ok = levels.filter { $0 >= 0 }
                    let mean = ok.isEmpty ? -1 : Double(ok.reduce(0, +)) / Double(ok.count)
                    emit("\(head) levels=\(levels.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) obs=\(clean(notes.joined(separator: " / ")))")
                case .swellGeneralRef, .swellRaisedRef, .swellGeneralNoRef, .swellRaisedNoRef:
                    var sampler = rater
                    sampler.greedy = false
                    let runs = Int(CommandLine.arguments.first { $0.hasPrefix("-runs=") }?.dropFirst(6) ?? "") ?? 3
                    let definition = [.swellGeneralRef, .swellGeneralNoRef].contains(variant) ? AnchoredPrompts.swellingGeneral : AnchoredPrompts.swellingRaised
                    let withReference = [.swellGeneralRef, .swellRaisedRef].contains(variant)
                    var levels: [Int] = []
                    var regions: [String] = []
                    for _ in 1...runs {
                        let (r, _, _) = withReference
                            ? await sampler.ask(SwellingAnywhere.self, instructions: AnchoredPrompts.swellingWithReference(definition), prompt: rater.anchoredPrompt(reference: ref.url, photo: s.url, referenceFirst: true))
                            : await sampler.ask(SwellingAnywhere.self, instructions: AnchoredPrompts.swellingAlone(definition), prompt: rater.ratePrompt(photo: s.url))
                        levels.append(r?.level ?? -1)
                        regions.append(r?.regions.joined(separator: "+") ?? "-")
                    }
                    let ok = levels.filter { $0 >= 0 }
                    let mean = ok.isEmpty ? -1 : Double(ok.reduce(0, +)) / Double(ok.count)
                    emit("\(head) levels=\(levels.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) regions=\(regions.joined(separator: "|"))")
                case .absoluteBoostSampled:
                    var sampler = rater
                    sampler.greedy = false
                    var maxes: [Int] = []
                    var runs: [String] = []
                    for _ in 1...5 {
                        let (r, _, _) = await sampler.ask(SignScoresV2.self, instructions: rubric.absoluteInstructions, prompt: rater.ratePrompt(photo: boosted(s.url)))
                        if let r { maxes.append(r.values.max() ?? 0); runs.append(r.values.map(String.init).joined()) }
                    }
                    let mean = maxes.isEmpty ? -1 : Double(maxes.reduce(0, +)) / Double(maxes.count)
                    emit("\(head) refFirst=none maxes=\(maxes.map(String.init).joined(separator: ",")) mean=\(String(format: "%.1f", mean)) signs=\(runs.joined(separator: ";")) obs=")
                case .identical:
                    for other in [ref, s] {
                        let (r, t, f) = await rater.ask(Identity.self, instructions: AnchoredPrompts.identical, prompt: rater.anchoredPrompt(reference: ref.url, photo: other.url, referenceFirst: true))
                        emit("\(head) against=\(other.name) samePhoto=\(r.map { String($0.samePhoto) } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))")
                    }
                case .tiles:
                    var ratings: [String] = []
                    var notes: [String] = []
                    var total = 0.0
                    for tile in quadrantTiles(of: s.url) {
                        let (r, t, f) = await rater.ask(Overall3.self, instructions: AnchoredPrompts.tile, prompt: rater.anchoredPrompt(reference: ref.url, photo: tile, referenceFirst: true, noun: "part"))
                        ratings.append(r.map { String($0.overall) } ?? (f ?? "-"))
                        notes.append(clean(r?.differences ?? ""))
                        total += t
                    }
                    emit("\(head) refFirst=true tiles=\(ratings.joined(separator: ",")) seconds=\(String(format: "%.1f", total)) obs=\(notes.joined(separator: " / "))")
                default:
                    for referenceFirst in [true, false] {
                        let prompt = rater.anchoredPrompt(reference: ref.url, photo: s.url, referenceFirst: referenceFirst)
                        let line: String
                        switch variant {
                        case .overall3:
                            let (r, t, f) = await rater.ask(Overall3.self, instructions: AnchoredPrompts.overall3, prompt: prompt)
                            line = "overall=\(r.map { String($0.overall) } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        case .relative2Boost:
                            let (r, t, f) = await rater.ask(RelativeSigns.self, instructions: AnchoredPrompts.relative2, prompt: rater.anchoredPrompt(reference: boosted(ref.url), photo: boosted(s.url), referenceFirst: referenceFirst))
                            line = "levels=\(r.map { $0.levels.map(String.init).joined(separator: ",") } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        case .rednessBoost:
                            let (r, t, f) = await rater.ask(RednessOnly.self, instructions: AnchoredPrompts.rednessOnly, prompt: rater.anchoredPrompt(reference: boosted(ref.url), photo: boosted(s.url), referenceFirst: referenceFirst))
                            line = "score=\(r.map { String($0.level) } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        case .direct3:
                            let (r, t, f) = await rater.ask(Direct3.self, instructions: AnchoredPrompts.direct3, prompt: prompt)
                            line = "overall=\(r.map { String($0.overall) } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs="
                        case .relative2:
                            let (r, t, f) = await rater.ask(RelativeSigns.self, instructions: AnchoredPrompts.relative2, prompt: prompt)
                            line = "levels=\(r.map { $0.levels.map(String.init).joined(separator: ",") } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        case .checklist:
                            let (r, t, f) = await rater.ask(Checklist.self, instructions: AnchoredPrompts.checklist, prompt: prompt)
                            line = "signs=\(r.map { $0.signs.map { $0 ? "1" : "0" }.joined() } ?? "-") coverage=\(r?.coverage ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        default:
                            let (r, t, f) = await rater.ask(RelativeSigns.self, instructions: AnchoredPrompts.relative, prompt: prompt)
                            line = "levels=\(r.map { $0.levels.map(String.init).joined(separator: ",") } ?? "-") seconds=\(String(format: "%.1f", t)) failure=\(f ?? "none") obs=\(clean(r?.differences ?? ""))"
                        }
                        emit("\(head) refFirst=\(referenceFirst) \(line)")
                    }
                }
            }
        }
    }

    /// Asks which of two boosted photos of the same area is worse, in both orders, 5 sampled runs each.
    func pairRound() async {
        var sampler = Rater(rubric: rubric)
        sampler.greedy = false
        let pairs = [("face_clear", "face"), ("face", "face_flare"), ("face_clear", "face_flare"),
                     ("hand_normal_patch", "right"), ("right", "right_time1b"), ("right", "left"), ("right", "right_time2")]
        let area = CommandLine.arguments.first { $0.hasPrefix("-pairs=") }?.dropFirst(7)
        for (a, b) in pairs where area == nil || (area == "face") == a.hasPrefix("face") {
            guard let sa = samples.first(where: { $0.name == a }), let sb = samples.first(where: { $0.name == b }) else { continue }
            for (x, y) in [(sa, sb), (sb, sa)] {
                var answers: [String] = []
                let pairRuns = Int(CommandLine.arguments.first { $0.hasPrefix("-pairRuns=") }?.dropFirst(10) ?? "") ?? 5
                for _ in 1...pairRuns {
                    let prompt = Prompt {
                        "First photo:"
                        Attachment(imageURL: boosted(x.url))
                        "Second photo:"
                        Attachment(imageURL: boosted(y.url))
                        "Which photo shows more eczema?"
                    }
                    let (r, _, f) = await sampler.ask(PairBoost.self, instructions: AnchoredPrompts.pair, prompt: prompt)
                    answers.append(r?.worse ?? (f ?? "-"))
                }
                emit("P first=\(x.name) second=\(y.name) answers=\(answers.joined(separator: ","))")
            }
        }
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
            for sign in 0..<7 {
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
        return (0..<7).map { sign in
            let v = ok.compactMap { $0.scores.indices.contains(sign) ? $0.scores[sign] : nil }.sorted()
            return v.isEmpty ? nil : v[v.count / 2]
        }
    }

    func reportJSON() -> String {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(data: enc.encode(summary()), encoding: .utf8)) ?? "{}"
    }
}
