import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let budgetMicroseconds = 2000.0

/// The least a host does with the edits: text with the caret at the end, plus the marked run.
struct BenchClient {
    private var text: [Character] = []
    private var markedLength = 0

    mutating func apply(_ edits: [Edit], key: Key?, engine: inout Engine, timings: inout [UInt64]) {
        for edit in edits {
            switch edit {
            case .pass:
                switch key {
                case .character(let c, _)?: text.append(c)
                case .named(.returnKey)?, .named(.enter)?: text.append("\n")
                case .named(.tab)?: text.append("\t")
                case .named(.backspace)?: _ = text.popLast()
                default: break
                }
            case .insert(let s), .commit(let s):
                setMarked(s)
                markedLength = 0
            case .setMarked(let s):
                setMarked(s)
                markedLength = s.count
            case .replace(let expected, let with):
                if text.suffix(expected.count).elementsEqual(expected) {
                    text.removeLast(expected.count)
                    text.append(contentsOf: with)
                } else {
                    let start = DispatchTime.now().uptimeNanoseconds
                    let fallback = engine.replacementFailed()
                    timings.append(DispatchTime.now().uptimeNanoseconds - start)
                    apply(fallback, key: key, engine: &engine, timings: &timings)
                }
            }
        }
    }

    private mutating func setMarked(_ s: String) {
        text.removeLast(min(markedLength, text.count))
        text.append(contentsOf: s)
    }
}

/// Types the corpus and returns the engine time of every `handle`/`endWord` call, in nanoseconds.
func run(_ corpus: String, mode: Mode, lexicon: Lexicon) -> [UInt64] {
    var engine = Engine(lexicon: lexicon, mode: mode)
    var client = BenchClient()
    var timings: [UInt64] = []
    timings.reserveCapacity(corpus.count + 1024)
    for c in corpus {
        let key: Key = c == "\n" ? .named(.returnKey) : .character(c, option: false)
        let start = DispatchTime.now().uptimeNanoseconds
        let edits = engine.handle(key)
        timings.append(DispatchTime.now().uptimeNanoseconds - start)
        client.apply(edits, key: key, engine: &engine, timings: &timings)
    }
    let start = DispatchTime.now().uptimeNanoseconds
    let edits = engine.endWord()
    timings.append(DispatchTime.now().uptimeNanoseconds - start)
    client.apply(edits, key: nil, engine: &engine, timings: &timings)
    return timings
}

/// Prints the line and returns whether p99 is inside the budget.
func report(_ label: String, _ timings: [UInt64]) -> Bool {
    let sorted = timings.sorted()
    func micros(_ q: Double) -> Double {
        Double(sorted[min(sorted.count - 1, Int(Double(sorted.count) * q))]) / 1000
    }
    let p99 = micros(0.99)
    let max = Double(sorted[sorted.count - 1]) / 1000
    print(String(format: "%@ p50 %.1f p99 %.1f max %.1f us (%d calls)", label, micros(0.5), p99, max, sorted.count))
    return p99 < budgetMicroseconds
}

// Synthetic corpus from scripts/export_parity.py (random parity syllables and test literals), not real Uzbek text.
guard let corpus = try? String(contentsOf: root.appendingPathComponent("Bench/corpus.txt"), encoding: .utf8) else {
    print("cannot read Bench/corpus.txt")
    exit(2)
}
let loadStart = DispatchTime.now().uptimeNanoseconds
guard let lexicon = try? WordListLexicon.load(from: root.appendingPathComponent("Resources")) else {
    print("cannot load Resources")
    exit(2)
}
print(String(format: "lexicon load %.1f ms", Double(DispatchTime.now().uptimeNanoseconds - loadStart) / 1_000_000))

let eagerOK = report("eager ", run(corpus, mode: .eager, lexicon: lexicon))
let markedOK = report("marked", run(corpus, mode: .marked, lexicon: lexicon))
if !(eagerOK && markedOK) {
    print("FAIL: p99 must be under \(Int(budgetMicroseconds)) us")
    exit(1)
}
