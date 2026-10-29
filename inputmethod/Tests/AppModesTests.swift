import Foundation

private final class MemoryStore: ModeStore {
    var saved: Set<String>
    var saveCount = 0

    init(_ saved: Set<String> = []) { self.saved = saved }

    func learnedMarkedApps() -> Set<String> { saved }

    func learnMarkedApp(_ bundleID: String) {
        saved.insert(bundleID)
        saveCount += 1
    }

    func forgetMarkedApp(_ bundleID: String) {
        saved.remove(bundleID)
        saveCount += 1
    }
}

func runAppModesTests() {
    let store = MemoryStore()
    var modes = AppModes(store: store)
    check(modes.mode(for: "com.microsoft.VSCode") == .marked, "seeded Monaco editors")
    check(modes.mode(for: "com.exafunction.windsurf") == .marked, "seeded Windsurf")
    check(modes.mode(for: "com.todesktop.230313mzl4w4u92") == .marked, "seeded Cursor")
    check(modes.mode(for: "ru.keepcoder.Telegram") == .eager, "eager by default")

    modes.observe(bundleID: "com.example.chat", found: "pus", expected: "puş", staleView: "pus")
    check(modes.mode(for: "com.example.chat") == .marked, "pre-replacement text means stale")
    modes.observe(bundleID: "com.tinyspeck.slackmacgap", found: "pux", expected: "puş", staleView: "pus")
    check(modes.mode(for: "com.tinyspeck.slackmacgap") == .eager, "other mismatches do not learn")
    check(store.saved.contains("com.example.chat"), "learned apps are persisted")

    for _ in 0..<3 { modes.observe(bundleID: "com.example.nil", found: nil, expected: "puş", staleView: "pus") }
    check(modes.mode(for: "com.example.nil") == .marked, "a client repeatedly reporting no text falls back to marked")
    check(!store.saved.contains("com.example.nil"), "the nil fallback is not persisted")

    modes.observe(bundleID: "com.example.ok", found: "puş", expected: "puş", staleView: "pus")
    check(modes.mode(for: "com.example.ok") == .eager, "the expected text is not stale")
    modes.observe(bundleID: "com.example.same", found: "pus", expected: "pus", staleView: "pus")
    check(modes.mode(for: "com.example.same") == .eager, "no replacement difference proves nothing")

    let saves = store.saveCount
    modes.observe(bundleID: "com.example.chat", found: "pus", expected: "puş", staleView: "pus")
    modes.observe(bundleID: "com.microsoft.VSCode", found: "pus", expected: "puş", staleView: "pus")
    check(store.saveCount == saves, "an already marked app is not saved again")

    let reloaded = AppModes(store: store)
    check(reloaded.mode(for: "com.example.chat") == .marked, "learned apps survive a restart")
    check(reloaded.mode(for: "com.microsoft.VSCode") == .marked, "seeded apps stay with learned ones")
    check(AppModes(store: MemoryStore(["a.b"])).mode(for: "a.b") == .marked, "a store with apps seeds the modes")

    var streak = AppModes(store: MemoryStore())
    let nilSaves = { (m: inout AppModes) in m.observe(bundleID: "com.example.flaky", found: nil, expected: "puş", staleView: "pus") }
    nilSaves(&streak); nilSaves(&streak)
    streak.observe(bundleID: "com.example.flaky", found: "puş", expected: "puş", staleView: "pus")
    nilSaves(&streak)
    check(streak.mode(for: "com.example.flaky") == .eager, "nil, nil, text, nil does not mark")
    streak.observe(bundleID: "com.example.flaky", found: "pux", expected: "puş", staleView: "pus")
    nilSaves(&streak); nilSaves(&streak)
    check(streak.mode(for: "com.example.flaky") == .eager, "a non-learning mismatch also resets the nil streak")

    let nilStore = MemoryStore()
    var silent = AppModes(store: nilStore)
    nilSaves(&silent); nilSaves(&silent)
    check(silent.mode(for: "com.example.flaky") == .eager, "two nils do not mark")
    nilSaves(&silent)
    check(silent.mode(for: "com.example.flaky") == .marked, "three consecutive nils mark for the session")
    check(nilStore.saveCount == 0 && nilStore.saved.isEmpty, "nil-based marking never reaches the store")
    check(AppModes(store: nilStore).mode(for: "com.example.flaky") == .eager, "a fresh AppModes is eager again")

    var forgotten = AppModes(store: store)
    forgotten.observe(bundleID: "com.example.slack", found: "pus", expected: "puş", staleView: "pus")
    nilSaves(&forgotten); nilSaves(&forgotten); nilSaves(&forgotten)
    forgotten.forget("com.example.slack")
    forgotten.forget("com.example.flaky")
    check(forgotten.mode(for: "com.example.slack") == .eager, "forget drops a learned app")
    check(!store.saved.contains("com.example.slack"), "forget saves the store")
    check(forgotten.mode(for: "com.example.flaky") == .eager, "forget drops a session-marked app")
    forgotten.forget("com.microsoft.VSCode")
    check(forgotten.mode(for: "com.microsoft.VSCode") == .marked, "seeded apps stay marked after forget")

    var flip = Engine(mode: .marked)
    for c in "pus" { _ = flip.handle(.character(c, option: false)) }
    _ = flip.switchMode(.eager)
    _ = flip.switchMode(.marked)
    check(flip.handle(.character("h", option: false)) == [.pass], "switching away and back leaves no marked tail")

    var eager = Engine()
    _ = eager.handle(.character("s", option: false))
    _ = eager.switchMode(.marked)
    _ = eager.switchMode(.eager)
    check(eager.handle(.character("h", option: false)) == [.pass], "a mode switch starts a fresh eager word")

    var same = Engine(mode: .marked)
    _ = same.handle(.character("s", option: false))
    check(same.switchMode(.marked) == [.commit("s")], "switching to the same mode still ends the word")
    check(same.mode == .marked && same.handle(.character("h", option: false)) == [.pass], "and keeps the mode")

    var switcher = Engine(mode: .marked)
    for c in "pus" { _ = switcher.handle(.character(c, option: false)) }
    check(switcher.switchMode(.eager) == [.commit("s")], "switchMode flushes the pending tail")
    check(switcher.mode == .eager, "switchMode sets the mode")
    check(switcher.handle(.character("h", option: false)) == [.pass], "no stale state after switchMode")
    check(switcher.switchMode(.marked) == [], "an eager word with nothing to undo flushes nothing")
    check(switcher.handle(.character("h", option: false)) == [.pass], "no stale state when switching back")

    var late = Engine()
    for c in "sh" { _ = late.handle(.character(c, option: false)) }
    _ = late.switchMode(.marked)
    _ = late.switchMode(.eager)
    check(late.replacementFailed() == [], "a late failure right after a switch is harmless")
    _ = late.endWord()
    check(late.handle(.character("s", option: false)) == [.pass] && late.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")],
          "the next word still converts after a late failure")
    var lateMarked = Engine()
    _ = lateMarked.switchMode(.marked)
    check(lateMarked.replacementFailed() == [], "a late failure in marked mode is harmless")

    runHostAPITests()
}

/// What the input method host relies on: the last replacement's data and a silent reset.
private func runHostAPITests() {
    let list = WordListLexicon(english: ["push"], uzbekExceptions: [])
    func data(_ engine: Engine) -> [String]? { engine.lastReplacement.map { [$0.expected, $0.staleView] } }

    var digraph = Engine(lexicon: list)
    check(digraph.lastReplacement == nil, "no replacement data before the first replacement")
    for c in "shos" { _ = digraph.handle(.character(c, option: false)) }
    check(digraph.handle(.character("h", option: false)) == [.replace(expected: "şos", with: "şoş")], "a second digraph")
    check(data(digraph) == ["şos", "sos"], "a digraph replacement records its stale view")

    var boundary = Engine(lexicon: list)
    for c in "push" { _ = boundary.handle(.character(c, option: false)) }
    check(boundary.handle(.character(" ", option: false)) == [.replace(expected: "puş", with: "push"), .pass], "the guard at a space")
    check(boundary.pieceCount == 0, "the word is already reset when the host checks the guard")
    check(data(boundary) == ["puş", "pus"], "the guard replacement keeps the ended word's stale view")
    var modes = AppModes(store: MemoryStore())
    if let last = boundary.lastReplacement {
        modes.observe(bundleID: "com.example.stale", found: "pus", expected: last.expected, staleView: last.staleView)
    }
    check(modes.mode(for: "com.example.stale") == .marked, "a stale client is learned from a failed guard check")
    _ = boundary.handle(.character("a", option: false))
    check(data(boundary) == ["puş", "pus"], "keys without a replacement keep the last data")

    // A stale client kept the typed apostrophe: the guard check on don't finds the plain spelling.
    var contraction = Engine(lexicon: WordListLexicon(english: ["don't"], uzbekExceptions: []))
    for c in "don't" { _ = contraction.handle(.character(c, option: false)) }
    check(contraction.word.staleView() == "don't", "a tutuq piece shows as the typed apostrophe in the stale view")
    _ = contraction.endWord()
    check(data(contraction) == ["donʼt", "don't"], "the guard on don't records the stale apostrophe")
    var learner = AppModes(store: MemoryStore())
    learner.observe(bundleID: "com.example.dont", found: "don't", expected: "donʼt", staleView: "don't")
    check(learner.mode(for: "com.example.dont") == .marked, "don't-style stale text is learned")

    var marked = Engine(mode: .marked)
    for c in "pus" { _ = marked.handle(.character(c, option: false)) }
    marked.reset()
    check(marked.handle(.character("h", option: false)) == [.pass], "reset drops the marked tail without edits")
    check(marked.mode == .marked, "reset keeps the mode")

    var eager = Engine()
    _ = eager.handle(.character("s", option: false))
    eager.reset()
    check(eager.handle(.character("h", option: false)) == [.pass], "reset drops the eager word")
    _ = eager.handle(.character(" ", option: false))
    _ = eager.handle(.character("`", option: false))
    check(eager.inCodeSpan, "a backtick after a space opens a code span")
    eager.reset()
    _ = eager.handle(.character("s", option: false))
    check(eager.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")], "reset ends a code span")
}
