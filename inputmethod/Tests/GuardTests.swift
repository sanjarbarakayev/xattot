import Foundation

private let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")

func runGuardTests() {
    let small = WordListLexicon(
        english: ["push", "shop", "chrome", "don't", "video", "log", "chin", "chap", "sham"],
        uzbekExceptions: ["çin", "çap", "şam"])

    check(typed("push shop", lexicon: small) == "push shop", "English words get their raw spelling back")
    check(typed("Push PUSH Chrome", lexicon: small) == "Push PUSH Chrome", "raw case is restored")
    check(typed("don't", lexicon: small) == "don't", "English contraction keeps its apostrophe")
    check(typed("'video'", lexicon: small) == "'video'", "closing quote after o stays a quote")
    check(typed("`log`", lexicon: small) == "`log`", "Markdown backticks after g")
    check(typed("chin chap sham", lexicon: small) == "çin çap şam", "Uzbek exception wins")
    check(typed("Chin CHAP", lexicon: small) == "Çin ÇAP", "Uzbek exception is case-insensitive")
    check(typed("shahar push", lexicon: small, stale: true) == "şahar puş", "a stale client keeps puş, never corrupts")
    check(typed("push shahar", lexicon: small, stale: true) == "puş şahar", "a failed guard does not stop the next word")
    check(typed("shahar push shop", lexicon: small) == "şahar push shop", "Uzbek words around English ones still convert")
    check(typed("push, shop.", lexicon: small) == "push, shop.", "punctuation ends the word and the guard runs first")
    check(typed("push\nshop", lexicon: small) == "push\nshop", "newline ends the word")
    check(typed("shahar", lexicon: small) == "şahar", "a word outside the list stays converted")
    check(typed("push", lexicon: EmptyLexicon()) == "puş", "without a lexicon nothing is restored")

    var engine = Engine(lexicon: small)
    for c in "push" { _ = engine.handle(.character(c, option: false)) }
    check(engine.endWord() == [.replace(expected: "puş", with: "push")], "the guard asks for one replacement")
    check(engine.endWord() == [], "the word is reset afterwards")
    for c in "push" { _ = engine.handle(.character(c, option: false)) }
    check(engine.handle(.character(" ", option: false)) == [.replace(expected: "puş", with: "push"), .pass],
          "the replacement comes before the boundary key")
    check(engine.replacementFailed() == [], "a failed guard adds nothing")
    _ = engine.handle(.character("s", option: false))
    check(engine.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")],
          "the next word still converts after a failed guard")

    var plain = Engine(lexicon: small)
    for c in "video" { _ = plain.handle(.character(c, option: false)) }
    check(plain.endWord() == [], "an unconverted English word needs no guard")

    var lost = Engine(lexicon: small)
    for c in "sha'" { _ = lost.handle(.character(c, option: false)) }
    _ = lost.replacementFailed()
    check(lost.endWord() == [], "an untracked word is left alone")

    // A quote only counts as closing when the same mark opened the word.
    check(typed("bog' tog'", lexicon: small) == "boğ toğ", "g' at the end of a word is ğ, not a quote")
    check(typed("bog' video'", lexicon: WordListLexicon(english: ["bog", "video"], uzbekExceptions: []))
          == "boğ videö", "a closing mark without an opener is part of the word")
    check(typed("'bog'", lexicon: WordListLexicon(english: ["bog"], uzbekExceptions: [])) == "'bog'",
          "an opened quote around an English word stays a quote")
    check(typed("'boshi'", lexicon: small) == "'boşi'", "a quoted Uzbek word stays Uzbek")
    check(typed("`dog` x", lexicon: WordListLexicon(english: ["dog"], uzbekExceptions: [])) == "`dog` x",
          "a backtick span stays raw")
    check(typed("'bog` x", lexicon: WordListLexicon(english: ["bog"], uzbekExceptions: [])) == "'boğ x",
          "a different closing mark is not a quote")
    check(typed("'⌫bog'", lexicon: WordListLexicon(english: ["bog"], uzbekExceptions: [])) == "boğ",
          "Backspace over a lone opener forgets it")

    let list = try? WordListLexicon.load(from: resources)
    if let list {
        check(typed("bosh tush shim chop chit shod hush marsh dacha", lexicon: list)
              == "boş tuş şim çop çit şod huş marş daça", "common Uzbek words that collide with English stay Uzbek")
        check(typed("mash shah", lexicon: list) == "mash shah", "rare Uzbek forms left to English")
        check(typed("bog' tog' dog' bug' tug'", lexicon: list) == "boğ toğ doğ buğ tuğ", "words ending in g' stay Uzbek")
        check(typed("Sen-chi", lexicon: list) == "Sen-çi", "chi after a hyphen stays Uzbek")
        check(typed("boshi tushda", lexicon: list) == "boşi tuşda", "words outside the list convert")
        check(typed("push shop chrome", lexicon: list) == "push shop chrome", "English words still revert with the bundled list")
        check(typed("'video' `log`", lexicon: list) == "'video' `log`", "quoted English with the bundled list")
        check(typed("'chap' chap", lexicon: list) == "'çap' çap", "a quoted Uzbek exception stays Uzbek")
    } else {
        check(false, "bundled lexicon loads")
    }
    checkExceptionsAreCollisions(resources)
    check(list?.isEnglish("change") == true, "bundled SCOWL list has change")
    check(list?.isEnglish("Change") == true, "lookup ignores case")
    check(list?.isEnglish("shahar") == false, "bundled list has no Uzbek words")
    check(list?.hasEnglishPrefix("chan") == true, "prefix search finds change")
    check(list?.hasEnglishPrefix("xqzv") == false, "prefix search rejects nonsense")
    check(list?.isUzbekException("çin") == true, "bundled exceptions have çin")
    check(list?.isUzbekException("ÇAP") == true, "bundled exceptions ignore case")
    check(list?.isUzbekException("push") == false, "push is not an exception")
}

/// Every exception must be a live collision: its raw form is an English word and typing it gives the exception.
private func checkExceptionsAreCollisions(_ directory: URL) {
    guard let list = try? WordListLexicon.load(from: directory),
          let text = try? String(contentsOf: directory.appendingPathComponent("uzbek-exceptions.txt"), encoding: .utf8)
    else {
        check(false, "exceptions file loads")
        return
    }
    let entries = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("#") && !$0.isEmpty }
    check(entries.count >= 14, "exceptions file has its entries")
    for entry in entries {
        let raw = entry.replacingOccurrences(of: "ç", with: "ch").replacingOccurrences(of: "ş", with: "sh")
            .replacingOccurrences(of: "ö", with: "o'").replacingOccurrences(of: "ğ", with: "g'")
        check(list.isEnglish(raw), "exception \(entry): \(raw) is in the English list")
        check(typed(raw, lexicon: list) == entry, "exception \(entry): typing \(raw) keeps it Uzbek")
    }
}
