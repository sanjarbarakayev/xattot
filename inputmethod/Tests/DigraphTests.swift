func runDigraphTests() {
    check(typed("choy shahar o'zbek g'isht") == "çoy şahar özbek ğişt", "lowercase digraphs")
    check(typed("o`rik g`oz") == "örik ğoz", "backtick like apostrophe")
    check(typed("Choy Shahar CHOY SHAHAR") == "Çoy Şahar ÇOY ŞAHAR", "capitals")
    check(typed("ssh oo' gg'") == "sş oö gğ", "only the last opener joins")
    check(typed("ras") == "ras", "a final opener stays")
    check(typed("emas↵") == "emas\n", "Return after an opener is typed, nothing pending")
    check(typed("Toshkent shahrida o'qish boshlandi, choy ichdik.") == "Toşkent şahrida öqiş boşlandi, çoy içdik.", "sentence")

    var e = Engine()
    check(e.handle(.character("a", option: false)) == [.pass], "plain letter passes")
    check(e.handle(.character("s", option: false)) == [.pass], "an opener also passes")
    check(e.handle(.character("h", option: false)) == [.replace(expected: "as", with: "aş")], "h asks to replace the whole word")

    // Caret moved inside a word: the check fails and the key is typed where the caret is.
    check(typedWithClick("pus", clickAt: 1, then: "h") == "phus", "no replacement when the caret moved")
    check(typedWithClick("pus", clickAt: 1, then: "hsh") == "phshus", "no replacements for the rest of the word")
    // The text before the moved caret ends with the opener, but not with the whole word.
    check(typedWithClick("yes pus", clickAt: 3, then: "h") == "yesh pus", "a moved caret after another s is caught")
    check(typedWithClick("bo go", clickAt: 2, then: "'") == "bo' go", "a moved caret after another o is caught")
    check(typedWithClick("yes pus", clickAt: 7, then: "h") == "yes puş", "the caret in place still converts")

    // After a failed replacement the word stops replacing until it ends.
    var failing = Engine()
    _ = failing.handle(.character("s", option: false))
    _ = failing.handle(.character("h", option: false))
    check(failing.replacementFailed() == [.pass], "a failed digraph replacement falls back to typing the key")
    _ = failing.handle(.character("s", option: false))
    check(failing.handle(.character("h", option: false)) == [.pass], "no more replacements in this word")
    _ = failing.handle(.character(" ", option: false))
    _ = failing.handle(.character("s", option: false))
    check(failing.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")], "replacements resume in the next word")
    check(failing.replacementFailed() == [.pass], "failure after resume is handled")

    var idle = Engine()
    check(idle.replacementFailed() == [], "a failure with nothing pending yields no edits")

    // Boundaries and named keys.
    check(typed("sh sh") == "ş ş", "space ends the word")
    check(typed("s⇥h") == "s\th", "Tab ends the word")
    check(typed("s←h") == "hs", "an arrow ends the word")
    check(typed("s⌘h") == "sh", "a shortcut ends the word")
    check(typed("s⎋h") == "sh", "Escape ends the word")
    check(typed("s1h") == "s1h", "a digit ends the word")
    check(typed("sh⌫s") == "s", "Backspace removes the digraph and the app deletes one character")
    check(typed("s⌫sh") == "ş", "Backspace forgets the piece, so the next digraph still joins")

    var w = Word()
    w.pieces = [Piece(raw: "p", shown: "p"), Piece(raw: "u", shown: "u"), Piece(raw: "sh", shown: "ş")]
    check(w.raw == "push" && w.shown == "puş", "Word raw and shown")
    check(w.staleView() == "pus", "staleView shows each digraph as its first key")
    check(w.tracking && !w.foreign, "a fresh word tracks and is not foreign")

    // Monaco-like clients keep reporting the pre-replacement text.
    check(typed("shu", stale: true) == "şu", "stale client still ends up with the replaced text")
    check(typed("it's", smartQuotes: true) == "it’s", "smart quotes insert a curly apostrophe")
}
