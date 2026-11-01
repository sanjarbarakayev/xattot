func runKeysTests() {
    check(typed("pus⌥h Chrome") == "push Çrome", "Option+H types an h that never joins")
    check(typed("pus⌥h⌥H") == "pushH", "Option+H keeps its case")
    check(typed("PUS⌥H") == "PUSH", "Shift+Option+H after capitals")
    check(typed("mo⌥'") == "moʼ", "Option+' types tutuq after o")
    check(typed("mo⌥\"") == "moʼ", "Shift+Option+' also types tutuq")
    check(typed("go⌥'") == "goʼ", "Option+' does not join with o")
    check(typed("⌥c⌥s⌥g⌥o⌥C⌥S⌥G⌥O") == "çşğöÇŞĞÖ", "Option letters")
    check(typed("⌥s⌥h") == "şh", "an Option letter is no opener")
    check(typed("⌥o' ⌥g`") == "ö' ğ`", "an Option o does not join with an apostrophe")
    check(typed("⌥ca ⌥Ca") == "ça Ça", "an Option c is not a bare c, so no foreign guard")
    check(typed("⌥Chay") == "Çhay", "an Option C does not join with h")
    check(typed("s⌥h⌥c⌥h") == "shçh", "Option+H after an Option letter stays plain")

    var e = Engine()
    _ = e.handle(.character("s", option: false))
    check(e.handle(.character("e", option: true)) == [.pass], "other Option keys reach ABC dead keys")
    check(e.handle(.character("h", option: false)) == [.pass], "that Option key ended the word")
    check(typed("s⌥eh") == "seh", "Option+e ends the word, so h no longer joins")

    var opt = Engine()
    check(opt.handle(.character("c", option: true)) == [.insert("ç")], "Option+c inserts ç")
    check(opt.handle(.character("C", option: true)) == [.insert("Ç")], "Option+C inserts Ç")
    check(opt.handle(.character("h", option: true)) == [.insert("h")], "Option+H inserts h")
    check(opt.handle(.character("H", option: true)) == [.insert("H")], "Shift+Option+H inserts H")
    check(opt.handle(.character("'", option: true)) == [.insert("ʼ")], "Option+' inserts tutuq")
    check(opt.handle(.character("\"", option: true)) == [.insert("ʼ")], "Shift+Option+' inserts tutuq")
    check(opt.pieceCount == 6, "one piece per inserted character")

    check(typed("pus⌫sh") == "puş", "Backspace forgets the piece, s joins again")
    check(typed("sx⌫h") == "ş", "a typo, Backspace, then h joins the preceding s")
    check(typed("shoshilmoq o'g'il") == "şoşilmoq öğil", "several conversions in one word")
    check(typed("sh⌫a") == "a", "Backspace removes s+h as one piece")
    check(typed("s⌘h") == "sh", "a shortcut ends the word")
    check(typed("s⌫h") == "h", "Backspace over an opener")
    check(typed("⌫⌫sh") == "ş", "Backspace on an empty word")
    check(typed("a'⌫b") == "ab", "Backspace over a pending apostrophe")
    check(typed("a'⌥sb") == "aʼşb", "an Option letter after an apostrophe makes it tutuq")
    check(typed("a'⌥hb") == "aʼhb", "so does Option+H")
    check(typed("a'⌥'b") == "a'ʼb", "Option+' leaves the apostrophe alone")
    check(typed("mo⌥'⌫'") == "mö", "Backspace over a tutuq piece, o' joins again")
    check(typed("⌥s⌫sh") == "ş", "Backspace over an Option letter")
    check(typed("pus⌥h⌫h") == "puş", "Backspace over Option+H, a plain h joins again")

    // Option inserts keep the word consistent: a later foreign letter reverts only converted pieces.
    check(typed("sh⌥hw") == "shhw", "foreign revert after Option+H")
    check(typed("⌥ssh w") == "şş w", "an Option letter then a digraph")
    check(typed("ssh⌥ew") == "sşew", "a passed Option key ends the word")

    check(typed("wow⌥s⌫a") == "wowa", "Option letters in a foreign word keep Backspace aligned")
    check(typed("wow⌥sh") == "wowşh", "no digraph after an Option letter in a foreign word")

    // Deleting the foreign trigger makes the word Uzbek again.
    check(typed("w⌫sh") == "ş", "Backspace over w clears the foreign word")
    check(typed("ca⌫h") == "ç", "Backspace over the letter after c")
    check(typed("wow⌫⌫⌫sh") == "ş", "an emptied foreign word converts again")

    // A word emptied by Backspace starts over, whatever stopped it.
    check(typed("a'b⌫⌫⌫sh", smartQuotes: true) == "ş", "an emptied untracked word converts again")
    check(typed("shw⌫⌫⌫sh", mode: .marked) == "ş", "an emptied untracked word converts again in marked mode")
    check(typed("'bo⌫⌫kino'") == "'kino'", "the opening quote survives when only the word is deleted")
    check(typed("'b⌫⌫kino'") == "kinö", "deleting the opening quote forgets it")
    check(typed("wow⌫sh") == "wosh", "the trigger is still there")
    check(typed("shw⌫⌫a") == "sa", "Backspace over a reverted digraph and its trigger")
    check(typed("c⌥s⌫h") == "ç", "Option path never marked the word foreign")
    check(typed("mo⌥''a") == "moʼ'a", "a tutuq piece is not a letter for the apostrophe rule")

    // Stale clients: Option inserts add exact characters, later digraphs still verify.
    check(typed("pus⌥h", stale: true) == "push", "Option+H with a stale client")
    check(typed("⌥ssh", stale: true) == "şş", "a digraph after an Option letter with a stale client")

    // A failed tutuq replacement before an Option letter keeps the apostrophe.
    var failing = Engine()
    for c in "a'" { _ = failing.handle(.character(c, option: false)) }
    check(
        failing.handle(.character("s", option: true)) == [.replace(expected: "a'", with: "aʼ"), .insert("ş")],
        "pending apostrophe becomes tutuq")
    check(failing.replacementFailed() == [], "a failed tutuq adds nothing to the insert")
    check(failing.pieceCount == 3, "a, apostrophe, ş")
    check(failing.handle(.character("s", option: false)) == [.pass], "no replacements after a failed replacement")
    check(failing.handle(.character("h", option: false)) == [.pass], "the word stays plain")
}
