/// The Özbek modes (the input method and the two layouts the bundle ships) and how the app moves between them.
/// Kept free of TIS calls so it can be tested.
enum LayoutMode: String, CaseIterable {
    case inputMethod, digraph, tugmali

    static let defaultsKey = "layoutMode"

    var sourceID: String {
        switch self {
        case .inputMethod: "com.sanjarbarakayev.inputmethod.xattot"
        case .digraph: "com.sanjarbarakayev.keyboardlayout.xattot.keylayout.UzbekLatin"
        case .tugmali: "com.sanjarbarakayev.keyboardlayout.xattot.keylayout.UzbekLatinTugmali"
        }
    }

    /// The mode whose source the app works with: the one enabled source, else the stored choice.
    static func active(stored: LayoutMode?, enabledIDs: Set<String>) -> LayoutMode {
        let enabled = allCases.filter { enabledIDs.contains($0.sourceID) }
        if enabled.count == 1, let only = enabled.first { return only }
        return stored ?? .inputMethod
    }

    static func isOzbek(_ id: String?) -> Bool {
        allCases.contains { $0.sourceID == id }
    }

    struct Switch: Equatable {
        let enable: String?
        let disable: [String]
        let select: String
    }

    /// enable is nil when the target is already enabled; disable (every other mode) runs only after enable succeeds.
    static func switchSteps(to target: LayoutMode, enabledIDs: Set<String>) -> Switch {
        let others = allCases.filter { $0 != target && enabledIDs.contains($0.sourceID) }
        return Switch(
            enable: enabledIDs.contains(target.sourceID) ? nil : target.sourceID,
            disable: others.map(\.sourceID),
            select: target.sourceID
        )
    }

    /// Steps that finish a pending switch, or nil while macOS has not enabled the target yet.
    static func completion(of target: LayoutMode, enabledIDs: Set<String>) -> Switch? {
        enabledIDs.contains(target.sourceID) ? switchSteps(to: target, enabledIDs: enabledIDs) : nil
    }
}
