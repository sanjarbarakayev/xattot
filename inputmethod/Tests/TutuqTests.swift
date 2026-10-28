func runTutuqTests() {
    check(typed("san'at ma'no Qur'on SAN'AT") == "sanʼat maʼno Qurʼon SANʼAT", "tutuq between letters")
    check(typed("mas'ul ta'sir") == "masʼul taʼsir", "after an opener")
    check(typed("ta'shkil sa'o'lat") == "taʼşkil saʼölat", "digraph right after tutuq")
    check(typed("o'zbek tog' bog'cha") == "özbek toğ boğça", "o' and g' stay letters")
    check(typed("'salom' dedi") == "'salom' dedi", "quotes around words")
    check(typed("kitob'.") == "kitob'.", "apostrophe before punctuation")
    check(typed("kitob'↵") == "kitob'\n", "Return after an apostrophe leaves it")
    check(typed("a''b") == "a''b", "a second apostrophe stays plain")
    check(typed("san'at", stale: true) == "sanʼat", "tutuq with a stale client")

    // Backtick only completes o/g; elsewhere it is a plain character and a word boundary.
    check(typed("san`at") == "san`at", "backtick is not a tutuq")
    check(typed("`salom") == "`salom", "backtick at word start")
    check(typed("a`'b") == "a`'b", "backtick then apostrophe stay plain")

    // Backspace forgets the apostrophe piece with its character.
    check(typed("san'⌫at") == "sanat", "Backspace on a pending apostrophe")
    check(typed("san'a⌫⌫t") == "sant", "Backspace over a tutuq")

    // The app rewrote the apostrophe (smart quotes).
    check(typed("san'at", smartQuotes: true) == "san’at", "no tutuq replacement over a smart quote")
    check(typed("ta'shkil", smartQuotes: true) == "ta’shkil", "no replacements in the word after a failed tutuq")
    check(typed("ta'shkil sh", smartQuotes: true) == "ta’shkil ş", "replacements resume in the next word")

    var e = Engine()
    _ = e.handle(.character("a", option: false))
    check(e.handle(.character("'", option: false)) == [.pass], "apostrophe after a letter passes")
    check(e.handle(.character("b", option: false)) == [.replace(expected: "a'", with: "aʼ"), .pass], "a letter turns it into tutuq")
    check(e.handle(.character("'", option: false)) == [.pass], "apostrophe after b passes")
    check(e.handle(.character("b", option: false)) == [.replace(expected: "aʼb'", with: "aʼbʼ"), .pass], "a second tutuq in the word")
    check(e.handle(.character("1", option: false)) == [.pass], "a digit passes")
    check(e.handle(.character("'", option: false)) == [.pass], "apostrophe after a digit is a boundary")
    check(e.handle(.character("b", option: false)) == [.pass], "no tutuq after a boundary apostrophe")
    check(e.handle(.character("`", option: false)) == [.pass], "backtick after a letter passes")

    var failing = Engine()
    _ = failing.handle(.character("a", option: false))
    _ = failing.handle(.character("'", option: false))
    _ = failing.handle(.character("s", option: false))
    check(failing.replacementFailed() == [], "a failed tutuq replacement adds nothing to the letter's own pass")
    check(failing.handle(.character("h", option: false)) == [.pass], "no more replacements in this word")

    // A failed digraph after a tutuq falls back like any other digraph.
    var digraph = Engine()
    for c in "a's" { _ = digraph.handle(.character(c, option: false)) }
    check(digraph.handle(.character("h", option: false)) == [.replace(expected: "aʼs", with: "aʼş")], "digraph after tutuq asks to replace")
    check(digraph.replacementFailed() == [.pass], "its failure falls back to typing h")
}
