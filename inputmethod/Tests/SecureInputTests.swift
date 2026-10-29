func runSecureInputTests() {
    let terminal = "com.apple.Terminal"
    check(SecureInputPolicy.passesThrough(secure: true, holder: terminal, client: terminal),
          "secure: the app holding secure input gets every key unconverted")
    check(!SecureInputPolicy.passesThrough(secure: false, holder: terminal, client: terminal),
          "secure: a stale holder without secure input converts")
    check(!SecureInputPolicy.passesThrough(secure: true, holder: "company.thebrowser.Browser", client: terminal),
          "secure: a background app holding secure input does not stop conversion elsewhere")
    check(!SecureInputPolicy.passesThrough(secure: true, holder: nil, client: terminal),
          "secure: an unknown holder converts")
    check(!SecureInputPolicy.passesThrough(secure: true, holder: "", client: ""),
          "secure: an empty bundle ID matches nothing")
    check(!SecureInputPolicy.passesThrough(secure: true, holder: terminal, client: nil),
          "secure: a client without a bundle ID converts")
}
