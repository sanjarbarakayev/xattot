import Foundation

private let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources")

func runQuoteTests() {
    let bundled = try? WordListLexicon.load(from: resources)
    check(bundled != nil, "bundled lexicon loads for quote tests")
    let lexicons: [(String, Lexicon)] = [("no list", EmptyLexicon()), ("bundled", bundled ?? EmptyLexicon())]

    for (name, lexicon) in lexicons {
        for mode in [Mode.eager, .marked] {
            func t(_ s: String) -> String { typed(s, mode: mode, lexicon: lexicon) }
            let label = "(\(name), \(mode))"
            // The word's own opening mark after o/g closes the quote.
            check(t("'kino'") == "'kino'", "closing quote after o \(label)")
            check(t("'keling'") == "'keling'", "closing quote after g \(label)")
            check(t("'kino' dedi") == "'kino' dedi", "closing quote before a space \(label)")
            check(t("'kino'.") == "'kino'.", "closing quote before punctuation \(label)")
            check(t("'bog''") == "'boğ'", "a doubled mark: g' is ğ, the second mark closes \(label)")
            check(t("'o'zbek'") == "'özbek'", "o' inside a quoted word is still ö \(label)")
            check(t("'bog` x") == "'boğ x", "a different mark does not close the quote \(label)")

            // A backtick that starts a word opens a code span: no conversions until it closes.
            check(t("`msg`") == "`msg`", "code span with g \(label)")
            check(t("`main.go`") == "`main.go`", "code span across punctuation \(label)")
            check(t("`git log`") == "`git log`", "code span across a space \(label)")
            check(t("`npm i -g`") == "`npm i -g`", "code span with a flag \(label)")
            check(t("`bash`") == "`bash`", "no digraph inside a code span \(label)")
            check(t("`git log` shahar") == "`git log` şahar", "words after the closing backtick convert \(label)")
            check(t("o`rik g`oz") == "örik ğoz", "a backtick after a letter still completes \(label)")
            check(t("`sh↵shahar") == "`sh\nşahar", "Return ends the code span \(label)")
            check(t("`sh⇥shahar") == "`sh\tşahar", "Tab ends the code span \(label)")
            check(t("`s⎋shahar") == "`sşahar", "Escape ends the code span \(label)")
            check(t("`s⌘shahar") == "`sşahar", "a shortcut ends the code span \(label)")
            check(t("`s→shahar") == "`sşahar", "an arrow ends the code span \(label)")
            check(t("`ab⌫sh") == "`ash", "Backspace inside the span keeps it \(label)")
            check(t("`ab⌫⌫⌫shahar") == "şahar", "Backspace over the opening backtick ends the span \(label)")
            check(t("`⌥s`") == "`s`", "an Option key passes inside the span \(label)")
        }
    }

    var e = Engine()
    for c in "'kino'" { _ = e.handle(.character(c, option: false)) }
    check(
        e.handle(.character(" ", option: false)) == [.replace(expected: "kinö", with: "kino'"), .pass],
        "the boundary splits the closing quote off ö")

    var span = Engine()
    _ = span.handle(.character("`", option: false))
    check(
        span.handle(.character("s", option: false)) == [.pass]
            && span.handle(.character("h", option: false)) == [.pass],
        "keys inside a code span pass")
    check(span.endWord() == [], "endWord ends the span without edits")
    _ = span.handle(.character("s", option: false))
    check(
        span.handle(.character("h", option: false)) == [.replace(expected: "s", with: "ş")],
        "conversions resume after endWord")

    check(typed("'o'zbek", smartQuotes: true) == "’özbek", "o' in a quoted word converts with smart quotes")
}
