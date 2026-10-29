/// Keeps Özbek out of password fields, where macOS leaves it on and sh would type ş into a password.
/// Kept free of TIS calls so it can be tested.
enum PasswordGuard {
    struct Step: Equatable {
        /// Source to select now, if any.
        let select: String?
        /// The source Özbek was left for, while a password field holds focus.
        let leftFor: String?
    }

    static func step(
        secure: Bool, current: String?, uzbek: String, previous: String?, enabled: [SourceInfo], leftFor: String?
    ) -> Step {
        // macOS bypasses input methods in secure fields itself; moving it would also evict it
        // whenever a background app holds secure input.
        if current == LayoutMode.inputMethod.sourceID { return Step(select: nil, leftFor: nil) }
        if secure {
            guard current == uzbek else { return Step(select: nil, leftFor: leftFor) }
            let target = latinTarget(uzbek: uzbek, previous: previous, enabled: enabled)
            return Step(select: target, leftFor: target)
        }
        guard let leftFor else { return Step(select: nil, leftFor: nil) }
        return Step(select: current == leftFor ? uzbek : nil, leftFor: nil)
    }

    /// Whether secure input holds this mode back. The input method guards itself per key, and waiting
    /// for it would never end while a background app (Arc) keeps secure input.
    static func waits(for mode: LayoutMode) -> Bool {
        mode != .inputMethod
    }

    /// The source to stay on until secure input ends, or nil to select `target` now. From a non-Özbek
    /// source the guard would switch a layout straight back; from the other Özbek layout it moves on to Latin.
    static func waitBefore(selecting target: LayoutMode, secure: Bool, current: String?) -> String? {
        guard secure, waits(for: target), let current, !LayoutMode.isOzbek(current) else { return nil }
        return current
    }

    // Password fields accept only Latin sources, so a Russian previous source would not do;
    // the other Özbek layout is ASCII-capable too but would still type ş.
    private static func latinTarget(uzbek: String, previous: String?, enabled: [SourceInfo]) -> String? {
        let latin = enabled.filter { $0.id != uzbek && !LayoutMode.isOzbek($0.id) && $0.isASCIICapable }
        return latin.first(where: { $0.id == previous })?.id ?? latin.first?.id
    }
}
