import Foundation

struct Entrant: Decodable {
    let number: Int
    let name, platform, date: String
    let rank: Int
    let mean, std, min, max: Double
    let failed: Int
    let scores: [Double]
}
struct Standing: Decodable { let number, rank: Int; let name: String; let mean: Double }
struct Paired: Decodable { let delta: [Double]; let mean: Double; let astraWins, fableWins: Int }
struct Spread: Decodable { let below100, above700: Int }
struct Results: Decodable {
    let batch, asOf: String
    let totalRounds, totalFailures: Int
    let entries: [Entrant]
    let standings: [Standing]
    let paired: Paired
    let spread: Spread
    func entrant(_ number: Int) -> Entrant { entries.first { $0.number == number }! }
}
struct Spectrum: Decodable {
    let selection, units: String
    let frequency: [Double]
    let series: [String: [[Double]]]
    let band08to12: [String: [Double]]
}
struct Cue: Decodable { let at: Double; let until: Double?; let kind, text: String }
struct SceneSpec: Decodable { let id: String; let bar: Int; let title: String; let cues: [Cue] }
struct Edit: Decodable {
    let voiceCredit: String?
    let title: String
    let bpm, fps, endBar: Int
    let scenes: [SceneSpec]
    var barDuration: Double { 240.0 / Double(bpm) }
    func startFrame(_ bar: Int) -> Int { Int((Double(bar * fps) * barDuration).rounded()) }
    var frames: Int { startFrame(endBar) }
}
struct Film {
    let edit: Edit
    let data: Results
    let spectrum: Spectrum
    init() throws {
        func read<T: Decodable>(_ path: String) throws -> T {
            try JSONDecoder().decode(T.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        }
        edit = try read(ProcessInfo.processInfo.environment["AVIS_FILM_EDIT"] ?? "src/edit.json")
        data = try read("data/results.json")
        spectrum = try read("data/spectrum.json")
    }
    func timing(frame: Int) -> (i: Int, t: Double, length: Double) {
        let i = edit.scenes.lastIndex { edit.startFrame($0.bar) <= frame } ?? 0
        let first = edit.startFrame(edit.scenes[i].bar)
        let next = i+1 == edit.scenes.count ? edit.frames : edit.startFrame(edit.scenes[i+1].bar)
        return (i, Double(frame-first)/Double(edit.fps), Double(next-first)/Double(edit.fps))
    }
}
func fixed(_ x: Double, _ digits: Int = 2) -> String { String(format:"%.*f",digits,x) }
func two(_ x: Int) -> String { String(format:"%02d",x) }
func clamp(_ x: Double) -> Double { max(0, min(1, x)) }
func ease(_ t: Double, _ start: Double, _ duration: Double) -> Double {
    let x = clamp((t - start) / duration)
    return 1 - pow(1 - x, 3)
}
func smooth(_ t: Double, _ a: Double, _ b: Double) -> Double {
    let x=clamp((t-a)/(b-a))
    return x*x*(3-2*x)
}
