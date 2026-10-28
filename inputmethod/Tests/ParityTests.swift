import Foundation

private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

private func jsonObjects(_ path: String) -> [[String: String]]? {
    guard let data = try? Data(contentsOf: root.appendingPathComponent(path)) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [[String: String]]
}

/// Replays the free layout's simulator outputs (Tests/parity.json) through the engine.
func runParityTests() {
    guard let cases = jsonObjects("Tests/parity.json"), let divergences = jsonObjects("Tests/divergences.json"),
          let bundled = try? WordListLexicon.load(from: root.appendingPathComponent("Resources")) else {
        check(false, "parity data and bundled lexicon load")
        return
    }
    var byInput: [String: [String: String]] = [:]
    for d in divergences { byInput[d["input"] ?? ""] = d }
    check(byInput.count == divergences.count, "divergence inputs are unique")
    check(divergences.allSatisfy { ($0["reason"] ?? "").isEmpty == false && ["none", "bundled"].contains($0["lexicon"] ?? "") },
          "every divergence has a reason and a lexicon")
    check(cases.count >= 500, "parity data has the literals and the generated strings")

    func lexicon(_ d: [String: String]) -> Lexicon { d["lexicon"] == "bundled" ? bundled : EmptyLexicon() }

    var mismatches = 0
    for c in cases {
        guard let input = c["input"], let free = c["output"] else { continue }
        let d = byInput[input]
        let expected = d?["engine"] ?? free
        let actual = typed(input, lexicon: d.map(lexicon) ?? EmptyLexicon())
        if actual != expected {
            mismatches += 1
            check(false, "parity \(input.debugDescription): free \(free.debugDescription), expected \(expected.debugDescription), got \(actual.debugDescription)")
        }
    }
    check(mismatches == 0, "\(cases.count) parity cases match the free simulator or a documented divergence")

    var stale = 0
    for d in divergences {
        guard let input = d["input"], let engine = d["engine"] else { continue }
        if typed(input, lexicon: lexicon(d)) != engine {
            stale += 1
            check(false, "divergence \(input.debugDescription) no longer yields \(engine.debugDescription)")
        }
        if let free = cases.first(where: { $0["input"] == input })?["output"], free == engine {
            stale += 1
            check(false, "divergence \(input.debugDescription) equals the free output")
        }
    }
    check(stale == 0, "\(divergences.count) divergences are current")
}
