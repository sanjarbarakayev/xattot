/// When the input method stays out of the way. macOS bypasses input methods in secure text fields
/// itself, but not in an app that holds secure input on its own, such as Terminal's Secure Keyboard Entry.
enum SecureInputPolicy {
    /// True when secure input is on and the app being typed in holds it: every key then passes unconverted.
    /// A background holder (a browser that kept secure input) leaves other apps converting.
    static func passesThrough(secure: Bool, holder: String?, client: String?) -> Bool {
        guard secure, let holder, !holder.isEmpty else { return false }
        return holder == client
    }
}
