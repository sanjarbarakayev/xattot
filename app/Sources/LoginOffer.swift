/// Without the app running after a restart, the hotkey and the password guard stop while the
/// layout stays on, so the app asks once whether to launch at login.
enum LoginOffer {
    static let askedKey = "askedLaunchAtLogin"

    static func shouldAsk(asked: Bool, launchesAtLogin: Bool, layoutEnabled: Bool) -> Bool {
        !asked && !launchesAtLogin && layoutEnabled
    }
}
