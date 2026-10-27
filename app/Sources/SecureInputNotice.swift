/// Menu text that explains why Özbek will not stay on while some app holds secure input.
/// Kept free of AppKit so it can be tested.
enum SecureInputNotice {
    struct Holder: Equatable {
        let name: String
        /// A regular app that can be quit and reopened; system processes cannot.
        let canRestart: Bool
    }

    struct Lines: Equatable {
        let state: String
        let toggle: String
        /// Disabled line naming the likely holder; macOS does not say who holds secure input for sure.
        let reason: String?
        /// Item that restarts the likely holder, for apps that keep secure input after the field is gone.
        let restart: String?
    }

    /// waiting: Özbek was left, or asked for, while secure input was on and returns once it ends.
    static func lines(on: Bool, secure: Bool, waiting: Bool, holder: Holder?) -> Lines {
        guard secure else {
            return Lines(state: state(on ? "yoqilgan" : "öçirilgan"), toggle: on ? "Öçiriş" : "Yoqiş",
                         reason: nil, restart: nil)
        }
        let reason = holder.map { "Parol rejimi yoqilgan, ehtimol: \($0.name)" } ?? "Parol rejimi yoqilgan"
        if on {
            return Lines(state: state("yoqilgan"), toggle: "Öçiriş", reason: reason, restart: nil)
        }
        let restart = holder.flatMap { $0.canRestart ? "\($0.name)'ni qayta işga tuşiriş…" : nil }
        return waiting
            ? Lines(state: state("parol maydoni yopilganda yoqiladi"), toggle: "Öçiriş", reason: reason, restart: restart)
            : Lines(state: state("öçirilgan"), toggle: "Parol maydoni yopilganda yoqiş", reason: reason, restart: restart)
    }

    private static func state(_ text: String) -> String {
        "Özbekça: \(text)"
    }
}
