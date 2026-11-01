import Foundation

/// A document read through UTF-16 ranges, as an IMK client serves it; records every range asked for.
private final class Document {
    let text: NSString
    private(set) var reads: [NSRange] = []
    /// Units cut from the end of every read, like a client that clamps the range it serves.
    var shortBy = 0
    var fails = false

    init(_ text: String) { self.text = text as NSString }

    func read(_ range: NSRange) -> String? {
        reads.append(range)
        if fails { return nil }
        return text.substring(with: NSRange(location: range.location, length: range.length - shortBy))
    }

    var end: Int { text.length }
}

private func suffix(_ count: Int, of document: Document, caret: Int? = nil) -> UTF16Text.Suffix? {
    UTF16Text.suffix(count, before: caret ?? document.end, read: document.read)
}

func runClientTextTests() {
    check(suffix(1, of: Document("şahar")) == .init(text: "r", units: 1), "utf16: one letter")
    check(suffix(2, of: Document("abş")) == .init(text: "bş", units: 2), "utf16: precomposed ş is one unit")

    let decomposed = "s\u{0327}"
    let combining = suffix(1, of: Document("a" + decomposed))
    check(combining?.text == decomposed && combining?.units == 2, "utf16: a combining mark stays with its letter")
    check(combining?.text == "ş", "utf16: a decomposed ş matches the precomposed one")

    check(
        suffix(2, of: Document("a👍🏽ş")) == .init(text: "👍🏽ş", units: 5),
        "utf16: an emoji with a skin tone is one Character")

    let family = Document("x👨‍👩‍👧‍👦s")
    check(suffix(2, of: family) == .init(text: "👨‍👩‍👧‍👦s", units: 12), "utf16: a long emoji grows the window")
    check(family.reads.count > 1, "utf16: the first window was too small for the family emoji")

    check(suffix(5, of: Document("ab")) == .init(text: "ab", units: 2), "utf16: fewer Characters near the start")
    check(
        suffix(2, of: Document("xyzşab"), caret: 4) == .init(text: "zş", units: 2),
        "utf16: reads before a mid-text caret")
    check(suffix(3, of: Document("ab"), caret: 0) == .init(text: "", units: 0), "utf16: nothing before the start")

    let untouched = Document("abc")
    check(
        suffix(0, of: untouched) == .init(text: "", units: 0) && untouched.reads.isEmpty,
        "utf16: zero Characters read nothing")

    let failing = Document("abc")
    failing.fails = true
    check(suffix(1, of: failing) == nil, "utf16: a failed read reports no text")

    let clamped = Document("abcdef")
    clamped.shortBy = 1
    check(suffix(1, of: clamped) == nil, "utf16: a read of the wrong length reports no text")

    let zalgo = Document("a" + String(repeating: "\u{0301}", count: UTF16Text.maxWindow + 10))
    check(suffix(1, of: zalgo) == nil, "utf16: a Character longer than the window reports no text")
    check(zalgo.reads.allSatisfy { $0.length <= UTF16Text.maxWindow }, "utf16: reads never exceed the window")

    let reads = Document("hello şahar")
    _ = suffix(2, of: reads)
    check(reads.reads.allSatisfy { NSMaxRange($0) == reads.end }, "utf16: every read ends at the caret")

    runCaretTrackerTests()
}

private func runCaretTrackerTests() {
    var fresh = CaretTracker()
    check(
        !fresh.sync(to: NSRange(location: 5, length: 0)) && fresh.location == 5, "caret: the first report is a baseline"
    )
    check(!fresh.sync(to: NSRange(location: 5, length: 0)), "caret: the same caret is no move")
    check(fresh.sync(to: NSRange(location: 2, length: 0)) && fresh.location == 2, "caret: another caret is a move")
    check(
        fresh.sync(to: NSRange(location: 2, length: 3)) && fresh.location == nil,
        "caret: a selection is a move and unknown")
    check(
        !fresh.sync(to: NSRange(location: 4, length: 0)) && fresh.location == 4,
        "caret: nothing to compare after unknown")
    check(
        !fresh.sync(to: NSRange(location: NSNotFound, length: 0)) && fresh.location == nil,
        "caret: NSNotFound is unknown")

    var typing = CaretTracker()
    _ = typing.sync(to: NSRange(location: 10, length: 0))
    typing.passed(typing: "s")
    check(typing.location == 11, "caret: a passed letter moves the caret")
    typing.replace(units: 1, with: "ş")
    check(typing.location == 11, "caret: s to ş keeps the caret")
    typing.passed(typing: "👍🏽")
    check(typing.location == 15, "caret: a passed emoji moves by its UTF-16 units")
    typing.replace(units: 2, with: "push")
    check(typing.location == 17, "caret: a guard restore moves by the difference")
    typing.insert("ö")
    check(typing.location == 18, "caret: an insert moves the caret")
    typing.passed(typing: nil)
    check(typing.location == nil, "caret: a passed key with unknown effect forgets the caret")
    typing.insert("a")
    check(typing.location == nil, "caret: an unknown caret stays unknown")

    var lagging = CaretTracker()
    _ = lagging.sync(to: NSRange(location: 10, length: 0))
    lagging.replace(units: 2, with: "ş")
    check(
        !lagging.sync(to: NSRange(location: 10, length: 0)), "caret: a report lagging behind a replacement is no move")
    check(lagging.location == 9, "caret: a lagging report keeps the predicted caret")
    check(!lagging.sync(to: NSRange(location: 9, length: 0)), "caret: the caught-up report is no move")
    check(
        lagging.sync(to: NSRange(location: 4, length: 0)) && lagging.location == 4,
        "caret: another report after a replacement is still a move")

    var marked = CaretTracker()
    _ = marked.sync(to: NSRange(location: 0, length: 0))
    marked.setMarked("s")
    check(marked.location == 1 && marked.markedUnits == 1, "caret: marked text ends at the caret")
    check(!marked.sync(to: NSRange(location: 1, length: 0)), "caret: the caret after marked text is no move")
    marked.setMarked("şo")
    check(marked.location == 2 && marked.markedUnits == 2, "caret: new marked text replaces the old")
    marked.insert("şö")
    check(marked.location == 2 && marked.markedUnits == 0, "caret: a commit replaces the marked text")
    marked.setMarked("g")
    marked.setMarked("")
    check(marked.location == 2 && marked.markedUnits == 0, "caret: clearing marked text")
    marked.setMarked("o")
    marked.passed(typing: "x")
    check(marked.location == nil, "caret: a key passed over marked text forgets the caret")
    check(
        marked.sync(to: NSRange(location: 3, length: 0)) == false && marked.markedUnits == 1,
        "caret: a baseline keeps the marked text")
}
