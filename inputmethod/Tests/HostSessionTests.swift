import Foundation

private final class SessionStore: ModeStore {
    private(set) var saved: Set<String> = []
    private(set) var saveCount = 0

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

private func session(_ lexicon: any Lexicon = EmptyLexicon(), store: SessionStore = SessionStore(),
                     bundleID: String? = nil, client: HostTestClient) -> HostSession {
    var session = HostSession(lexicon: lexicon, store: store)
    if let bundleID { session.activate(bundleID: bundleID, client: client) }
    return session
}

private func typedInSession(_ notation: String, lexicon: any Lexicon = EmptyLexicon(),
                            bundleID: String? = nil) -> HostTestClient {
    let client = HostTestClient()
    var host = session(lexicon, bundleID: bundleID, client: client)
    client.type(notation, into: &host)
    host.endWord(client: client)
    return client
}

func runHostSessionTests() {
    let pushLexicon = WordListLexicon(english: ["push"], uzbekExceptions: [])

    check(typedInSession("shahar").text == "şahar", "host: shahar converts")
    check(typedInSession("push ", lexicon: pushLexicon).text == "push ", "host: the English guard restores push")
    check(typedInSession("o'g'il", bundleID: "com.example.chat").text == "öğil", "host: eager o'g'il")

    let unbound = HostTestClient()
    var noBundle = HostSession(lexicon: EmptyLexicon(), store: SessionStore())
    unbound.type("sh", into: &noBundle)
    check(unbound.text == "ş" && noBundle.mode == .eager, "host: no activated app types eagerly")

    // The controller ends the word on a click; the next letter starts a new one.
    let clicked = HostTestClient()
    var clickHost = session(client: clicked)
    clicked.type("s", into: &clickHost)
    clicked.click(at: 1)
    clickHost.endWord(client: clicked)
    clicked.type("h", into: &clickHost)
    check(clicked.text == "sh" && clicked.replaceCount == 0, "host: caretClickMidDigraph")

    let silent = HostTestClient()
    var silentHost = session(client: silent)
    silent.type("pus", into: &silentHost)
    silent.click(at: 1)
    silent.type("hsh", into: &silentHost)
    check(silent.text == "phshus" && silent.replaceCount == 0, "host: an unreported caret move fails every check")

    let staleStore = SessionStore()
    let stale = HostTestClient(stale: true)
    var staleHost = session(store: staleStore, bundleID: "x", client: stale)
    stale.type("shs", into: &staleHost)
    check(staleHost.mode == .eager, "host: a passing check learns nothing")
    let consumed = staleHost.handle(.character("h", option: false), client: stale)
    check(!consumed, "host: a failed digraph check passes the key")
    check(stale.replaceCount == 1, "host: a failed check replaces nothing")
    check(AppModes(store: staleStore).mode(for: "x") == .marked && staleStore.saved == ["x"],
          "host: failedCheckObserves")
    check(staleHost.mode == .eager, "host: a learned mode waits for the next key")
    stale.typeItself(.character("h", option: false))
    check(stale.text == "şsh", "host: the failed key is typed by the app")
    stale.type(" ", into: &staleHost)
    check(staleHost.mode == .marked, "host: the next key switches a learned app to marked")
    stale.type("sh", into: &staleHost)
    staleHost.endWord(client: stale)
    check(stale.text == "şsh ş" && stale.replaceCount == 1, "host: the next word composes in marked mode")

    let guardStore = SessionStore()
    let guarded = HostTestClient(stale: true)
    var guardHost = session(pushLexicon, store: guardStore, bundleID: "z", client: guarded)
    guarded.type("push ", into: &guardHost)
    check(guarded.text == "puş " && guarded.replaceCount == 1, "host: a failed guard check still passes the space")
    check(guardStore.saved == ["z"] && guardHost.mode == .eager, "host: a failed guard check learns the app")
    guardHost.endWord(client: guarded)
    check(guardHost.mode == .marked && guarded.text == "puş ", "host: endWord switches a learned app, editing nothing")

    let nilStore = SessionStore()
    let nilClient = HostTestClient(reportsNil: true)
    var nilHost = session(store: nilStore, bundleID: "y", client: nilClient)
    nilClient.type("sh sh", into: &nilHost)
    check(nilHost.mode == .eager, "host: two nil reports keep eager")
    nilClient.type(" sh", into: &nilHost)
    nilHost.endWord(client: nilClient)
    check(nilHost.mode == .marked && nilStore.saveCount == 0, "host: nilClientGoesMarkedAfterThree")
    check(nilClient.text == "sh sh sh" && nilClient.replaceCount == 0, "host: nil checks edit nothing")

    let code = HostTestClient()
    var codeHost = session(bundleID: "com.microsoft.VSCode", client: code)
    check(codeHost.mode == .marked, "host: activateSwitchesMode")
    code.type("o'g'il", into: &codeHost)
    codeHost.endWord(client: code)
    check(code.text == "öğil" && code.marked.isEmpty && code.replaceCount == 0, "host: marked o'g'il")

    let pending = HostTestClient()
    var pendingHost = session(bundleID: "com.microsoft.VSCode", client: pending)
    pending.type("s", into: &pendingHost)
    check(pending.marked == "s", "host: a pending opener is marked")
    pendingHost.endWord(client: pending)
    check(pending.commits.last == "s" && pending.marked.isEmpty && pending.text == "s", "host: endWordCommitsMarked")

    let chat = HostTestClient()
    var chatHost = session(bundleID: "com.example.chat", client: chat)
    chat.type("emas", into: &chatHost)
    let returned = chatHost.handle(.named(.returnKey), client: chat)
    check(!returned && chat.text == "emas" && chat.marked.isEmpty, "host: Return after emas passes")

    // A word belongs to the client it was typed in.
    let first = HostTestClient()
    let second = HostTestClient(text: "s")
    var moving = session(bundleID: "com.example.a", client: first)
    first.type("s", into: &moving)
    moving.activate(bundleID: "com.example.b", client: second)
    second.type("h", into: &moving)
    check(second.text == "sh" && second.replaceCount == 0, "host: activation drops the previous client's word")

    // The controller's order on refocus: end the word in the client, then activate it again.
    let refocused = HostTestClient()
    var refocusHost = session(bundleID: "com.microsoft.VSCode", client: refocused)
    refocused.type("s", into: &refocusHost)
    refocusHost.endWord(client: refocused)
    refocusHost.activate(bundleID: "com.microsoft.VSCode", client: refocused)
    refocused.type("h", into: &refocusHost)
    refocusHost.endWord(client: refocused)
    check(refocused.text == "sh" && refocused.marked.isEmpty && refocused.commits == ["s"],
          "host: re-activating the same client after endWord loses nothing")

    // IMK can activate again without a deactivation; the controller settles the word first.
    let twice = HostTestClient()
    var twiceHost = session(bundleID: "com.microsoft.VSCode", client: twice)
    twice.type("s", into: &twiceHost)
    twiceHost.settle(client: twice, showsMarked: twice.showsMarked)
    twiceHost.activate(bundleID: "com.microsoft.VSCode", client: twice)
    twice.type("h", into: &twiceHost)
    twiceHost.endWord(client: twice)
    check(twice.text == "sh" && twice.marked.isEmpty && twice.commits == ["s"],
          "host: activate twice with a pending opener loses nothing")

    let finalized = HostTestClient()
    var finalizedHost = session(bundleID: "com.microsoft.VSCode", client: finalized)
    finalized.type("s", into: &finalizedHost)
    finalized.finalizeMarked()
    finalizedHost.settle(client: finalized, showsMarked: finalized.showsMarked)
    finalizedHost.activate(bundleID: "com.microsoft.VSCode", client: finalized)
    finalized.type("h", into: &finalizedHost)
    finalizedHost.endWord(client: finalized)
    check(finalized.text == "sh" && finalized.commits.isEmpty,
          "host: text the client already finalized is not inserted again")

    // A click in a marked app: most apps finalize the marked text themselves.
    let movedMarked = HostTestClient()
    var movedHost = session(bundleID: "com.microsoft.VSCode", client: movedMarked)
    movedMarked.type("s", into: &movedHost)
    movedMarked.click(at: 1)
    movedHost.settle(client: movedMarked, showsMarked: movedMarked.showsMarked)
    check(movedMarked.text == "s" && movedMarked.commits.isEmpty, "host: a caret move after the app finalized commits nothing")

    let eagerMoved = HostTestClient()
    var eagerMovedHost = session(pushLexicon, client: eagerMoved)
    eagerMoved.type("push", into: &eagerMovedHost)
    eagerMoved.click(at: 2)
    eagerMovedHost.settle(client: eagerMoved, showsMarked: eagerMoved.showsMarked)
    check(eagerMoved.text == "puş" && eagerMoved.replaceCount == 1, "host: settling an eager word edits nothing")

    let editor = HostTestClient()
    let other = HostTestClient()
    var leaving = session(bundleID: "com.microsoft.VSCode", client: editor)
    editor.type("s", into: &leaving)
    leaving.activate(bundleID: "com.example.chat", client: other)
    check(leaving.mode == .eager && other.text.isEmpty && other.commits.isEmpty,
          "host: leaving a marked app commits nothing into the next one")

    let resetClient = HostTestClient()
    var resetHost = session(client: resetClient)
    resetClient.type("s", into: &resetHost)
    resetHost.reset()
    resetClient.type("h", into: &resetHost)
    check(resetClient.text == "sh" && resetClient.replaceCount == 0, "host: reset forgets the word")

    let shortClient = HostTestClient()
    var shortHost = session(client: shortClient)
    shortClient.type("s", into: &shortHost)
    shortClient.click(at: 0)
    shortClient.type("h", into: &shortHost)
    check(shortClient.text == "hs" && shortClient.replaceCount == 0, "host: too little text before the caret fails the check")
}
