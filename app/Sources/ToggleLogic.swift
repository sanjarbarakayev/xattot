struct SourceInfo: Equatable {
    let id: String
    let isASCIICapable: Bool
}

/// Decides where the toggle goes; kept free of TIS calls so it can be tested.
enum ToggleLogic {
    static func isOn(current: String?, uzbek: String) -> Bool {
        current == uzbek
    }

    static func previousToRemember(current: String?) -> String? {
        LayoutMode.isOzbek(current) ? nil : current
    }

    /// Source to return to when Özbek is switched off: the one used before it if still
    /// enabled, otherwise the first Latin source (ABC), otherwise anything else.
    static func offTarget(uzbek: String, previous: String?, enabled: [SourceInfo]) -> String? {
        let others = enabled.filter { $0.id != uzbek && !LayoutMode.isOzbek($0.id) }
        if let previous, others.contains(where: { $0.id == previous }) {
            return previous
        }
        return others.first(where: \.isASCIICapable)?.id ?? others.first?.id
    }
}
