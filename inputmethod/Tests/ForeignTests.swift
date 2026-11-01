func runForeignTests() {
    check(typed("wish watch switch") == "wish watch switch", "w makes the word foreign")
    check(typed("Wish WISH Watch WATCH") == "Wish WISH Watch WATCH", "capital W")
    check(typed("cash code cache accept macOS Facebook") == "cash code cache accept macOS Facebook", "c without h")
    check(typed("Cash CASH Cc cH cHoy") == "Cash CASH Cc cH cHoy", "capital C and a mismatched H")
    check(typed("wish shahar") == "wish şahar", "digraphs return after the word")
    check(typed("cash,choy.wow↵shu") == "cash,çoy.wow\nşu", "boundaries reset foreign")
    check(typed("choyxona shaxmat Choy CHOY") == "çoyxona şaxmat Çoy ÇOY", "ch keeps the word Uzbek")
    check(typed("code o'qish") == "code öqiş", "o' converts again in the next word")
    check(typed("won't wouldn't") == "won't wouldn't", "no tutuq in foreign words")
    check(typed("wo`rld wog'") == "wo`rld wog'", "o and g with an apostrophe do not join")
    check(typed("show-off") == "show-off", "w later in the word reverts ş")
    check(typed("ssh sho") == "sş şo", "no w, no c: still converted")

    // Earlier conversions revert, tutuq included.
    check(typed("shwo chocolate") == "shwo chocolate", "ç reverts when the word turns foreign")
    check(typed("ta'shw") == "ta'shw", "tutuq and ş revert")
    check(typed("o'zbekca accent") == "o'zbekca accent", "ö reverts at a later c")
    check(typed("ssh⌫w") == "sw", "Backspace over the digraph then w")
    check(typed("shw sh") == "shw ş", "the next word converts again")

    var e = Engine()
    _ = e.handle(.character("s", option: false))
    check(e.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")], "digraph converts")
    check(
        e.handle(.character("w", option: false)) == [.replace(expected: "ş", with: "sh"), .pass],
        "w reverts the shown text")
    check(e.handle(.character("s", option: false)) == [.pass], "letters only pass in a foreign word")
    check(e.handle(.character("h", option: false)) == [.pass], "no digraph in a foreign word")
    check(e.handle(.character("'", option: false)) == [.pass], "apostrophe passes and ends the word")
    check(e.handle(.character("s", option: false)) == [.pass], "next word starts plain")
    check(e.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")], "and converts")

    var plain = Engine()
    check(plain.handle(.character("w", option: false)) == [.pass], "w with nothing to revert is a plain pass")
    var cc = Engine()
    _ = cc.handle(.character("c", option: false))
    check(cc.handle(.character("a", option: false)) == [.pass], "c then a is foreign, nothing to revert")

    // A stale client cannot verify the revert; nothing is corrupted and replacements stop.
    check(typed("shw", stale: true) == "şw", "failed revert leaves the converted text and the letter")
    check(typed("shwsh", stale: true) == "şwsh", "no replacements after a failed revert")
    check(typed("shw sh", stale: true) == "şw ş", "replacements resume in the next word")

    var failing = Engine()
    for c in "sh" { _ = failing.handle(.character(c, option: false)) }
    check(
        failing.handle(.character("w", option: false)) == [.replace(expected: "ş", with: "sh"), .pass],
        "revert is asked")
    check(failing.replacementFailed() == [], "a failed revert adds nothing to the letter's own pass")
    check(failing.handle(.character("s", option: false)) == [.pass], "the word stays foreign")
    check(failing.handle(.character("h", option: false)) == [.pass], "and does not convert")
    check(failing.handle(.character("a", option: false)) == [.pass], "later letters pass")
    _ = failing.handle(.character(" ", option: false))
    _ = failing.handle(.character("s", option: false))
    check(failing.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")], "next word converts")

    // The pieces after a failed revert describe the converted text the client holds.
    var tail = Engine()
    for c in "sh" { _ = tail.handle(.character(c, option: false)) }
    _ = tail.handle(.character("w", option: false))
    _ = tail.replacementFailed()
    check(tail.handle(.named(.backspace)) == [.pass], "Backspace after a failed revert passes")
    check(tail.handle(.character("s", option: false)) == [.pass], "a letter after it passes")

    // After a revert there is one piece per client character, so Backspace stays aligned.
    var aligned = Engine()
    for c in "oo'sh" { _ = aligned.handle(.character(c, option: false)) }
    check(aligned.pieceCount == 3, "o, ö, ş are three pieces before the revert")
    _ = aligned.handle(.character("w", option: false))
    check(aligned.pieceCount == 6, "reverted o, o', sh plus w are six pieces for six characters")
    for _ in 0..<4 { _ = aligned.handle(.named(.backspace)) }
    check(aligned.pieceCount == 2, "four Backspaces leave two pieces")
    check(typed("shw⌫⌫a") == "sa", "Backspace over a reverted digraph")

    // Already not tracking: a foreign word does not try to revert.
    check(typed("sha'bw", smartQuotes: true) == "şa’bw", "no revert once tracking stopped")
    check(
        typedWithClick("pus", clickAt: 1, then: "hw") == "phwus",
        "after a failed digraph, w is typed at the moved caret")
    var stopped = Engine()
    for c in "sha'b" { _ = stopped.handle(.character(c, option: false)) }
    _ = stopped.replacementFailed()
    check(stopped.handle(.character("w", option: false)) == [.pass], "no .replace when tracking is false")
}
