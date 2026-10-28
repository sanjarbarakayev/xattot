import Foundation

private let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")

func runMarkedTests() {
    let small = WordListLexicon(english: ["push", "change", "shop", "don't", "video", "chap"],
                                uzbekExceptions: ["çap"])

    check(typed("shahar o'g'il shoshilmoq", mode: .marked) == "şahar öğil şoşilmoq", "marked mode converts")
    check(typed("push change", mode: .marked, lexicon: small) == "push change", "ambiguous span decided at the boundary")
    check(typed("emas↵", mode: .marked) == "emas\n", "Return commits the pending s first")
    check(typed("pus⌫sh", mode: .marked) == "puş", "Backspace shrinks the marked span")

    var e = Engine(mode: .marked)
    check(e.handle(.character("a", option: false)) == [.pass], "a plain letter passes")
    check(e.handle(.character("s", option: false)) == [.setMarked("s")], "an opener is marked")
    check(e.handle(.character("a", option: false)) == [.commit("sa")], "resolved span is committed")
    check(e.handle(.character("s", option: false)) == [.setMarked("s")], "the next opener is marked again")
    check(e.handle(.character("h", option: false)) == [.commit("ş")], "a finished digraph outside English is committed")
    check(e.replacementFailed() == [], "marked mode has no replacement to fail")

    var span = Engine(lexicon: small, mode: .marked)
    for c in "pu" { _ = span.handle(.character(c, option: false)) }
    check(span.handle(.character("s", option: false)) == [.setMarked("s")], "s after an English start is marked")
    check(span.handle(.character("h", option: false)) == [.setMarked("ş")], "a conversion inside an English prefix stays marked")
    check(span.handle(.character(" ", option: false)) == [.commit("sh"), .pass], "the boundary commits the raw tail")

    var back = Engine(mode: .marked)
    _ = back.handle(.character("s", option: false))
    check(back.handle(.named(.backspace)) == [.setMarked("")], "Backspace in the tail is consumed")
    check(back.handle(.named(.backspace)) == [.pass], "Backspace with no tail reaches the app")

    check(typed("push shahar", mode: .marked, lexicon: small, stale: true) == "push şahar", "a stale client still converts")
    check(typed("ma'no a'⌥'b", mode: .marked) == "maʼno a'ʼb", "tutuq in marked mode")
    check(typed("⌥c⌥s s⌥h", mode: .marked) == "çş sh", "Option letters are committed")
    check(typed("show cat", mode: .marked, lexicon: small) == "show cat", "foreign words revert inside the tail")
    check(typed("show", mode: .marked) == "şow", "committed text is never reverted, as in the free layout")
    check(typed("don't", mode: .marked, lexicon: small) == "don't", "an English contraction keeps its apostrophe")
    check(typed("'video' 'chap'", mode: .marked, lexicon: small) == "'video' 'çap'", "quoted words in marked mode")
    check(typed("s⌘h sh⇥", mode: .marked) == "sh ş\t", "a shortcut and Tab end the word")
    check(typed("s⌥eh", mode: .marked) == "seh", "an unmapped Option key ends the word")

    let samples = ["push change", "shahar o'g'il", "show cat", "don't", "'video'", "pus⌫sh", "ma'no", "s⌥h chrome"]
    check(samples.allSatisfy { !markedEdits($0, lexicon: small).contains(where: isReplace) },
          "marked mode never emits .replace")

    if let list = try? WordListLexicon.load(from: resources) {
        check(typed("shahar o'g'il shoshilmoq", mode: .marked, lexicon: list) == "şahar öğil şoşilmoq",
              "marked mode converts with the bundled lexicon")
        check(typed("push change", mode: .marked, lexicon: list) == "push change", "English words with the bundled lexicon")
        check(typed("bosh", mode: .marked, lexicon: list) == "boş", "an Uzbek exception stays converted")
        check(typed("show shower chrome", mode: .marked, lexicon: list) == "show shower chrome",
              "an English prefix keeps the span open until the foreign letter")
        check(typed("'video' bog'", mode: .marked, lexicon: list) == "'video' boğ", "quotes and g' with the bundled lexicon")
    } else {
        check(false, "bundled lexicon loads")
    }
}

private func markedEdits(_ notation: String, lexicon: Lexicon) -> [Edit] {
    var engine = Engine(lexicon: lexicon, mode: .marked)
    let edits = FakeClient.keys(notation).flatMap { engine.handle($0) }
    return edits + engine.endWord()
}
