/// A text field behind `TextClient`, for driving a `HostSession` the way an app would.
final class HostTestClient: TextClient {
    private(set) var text = ""
    /// Character offset into `text`.
    private(set) var caret = 0
    /// Reports a shadow of the text that `replace` never updates (Monaco's behaviour).
    let stale: Bool
    /// `text(before:)` returns nil, like a client that exposes no text.
    let reportsNil: Bool

    private(set) var replaceCount = 0
    private(set) var commits: [String] = []
    private var shadow = ""
    private var markedLength = 0

    init(text: String = "", stale: Bool = false, reportsNil: Bool = false) {
        self.text = text
        self.shadow = text
        self.caret = text.count
        self.stale = stale
        self.reportsNil = reportsNil
    }

    /// The marked range, which always ends at the caret.
    var marked: String { String(Array(text)[(caret - markedLength)..<caret]) }

    /// Moves the caret as a click would. The session is not told; the caller decides.
    func click(at offset: Int) {
        caret = offset
        markedLength = 0
    }

    /// Types the notation; whatever the session passes, the app types itself.
    func type(_ notation: String, into session: inout HostSession) {
        for key in FakeClient.keys(notation) where !session.handle(key, client: self) {
            typeItself(key)
        }
    }

    func text(before length: Int) -> String? {
        if reportsNil { return nil }
        let seen = Array(stale ? shadow : text)
        let at = stale ? shadowCaret : caret
        return String(seen[max(0, at - length)..<at])
    }

    func replace(before length: Int, with replacement: String) {
        replaceCount += 1
        text = Self.splice(text, caret: caret, removing: length, inserting: replacement)
        caret += replacement.count - length
        if !stale { shadow = text }
    }

    func insert(_ inserted: String) { replaceMarked(with: inserted) }

    func setMarked(_ marked: String) {
        replaceMarked(with: marked)
        markedLength = marked.count
    }

    func commit(_ committed: String) {
        commits.append(committed)
        replaceMarked(with: committed)
    }

    private var shadowCaret: Int { caret + shadow.count - text.count }

    /// What the app does with a key the session passed.
    func typeItself(_ key: Key) {
        switch key {
        case .character(let c, _): edit(removing: 0, inserting: String(c))
        case .named(.returnKey), .named(.enter): edit(removing: 0, inserting: "\n")
        case .named(.tab): edit(removing: 0, inserting: "\t")
        case .named(.backspace): edit(removing: 1, inserting: "")
        case .named(.left): caret = max(0, caret - 1)
        case .named(.right): caret = min(text.count, caret + 1)
        case .named(.escape), .named(.up), .named(.down), .shortcut: break
        }
    }

    private func replaceMarked(with s: String) {
        edit(removing: markedLength, inserting: s)
        markedLength = 0
    }

    /// Removes characters before the caret and inserts text there, in the text and in the shadow.
    private func edit(removing: Int, inserting: String) {
        let n = min(removing, caret, stale ? shadowCaret : caret)
        let at = shadowCaret
        text = Self.splice(text, caret: caret, removing: n, inserting: inserting)
        shadow = stale ? Self.splice(shadow, caret: at, removing: n, inserting: inserting) : text
        caret += inserting.count - n
    }

    private static func splice(_ s: String, caret: Int, removing: Int, inserting: String) -> String {
        var chars = Array(s)
        chars.replaceSubrange((caret - removing)..<caret, with: Array(inserting))
        return String(chars)
    }
}
