// Plain assertions runner: Command Line Tools ship without XCTest.
import AppKit
import Carbon

var failures = 0
func check(_ condition: Bool, _ label: String) {
    print("\(condition ? "ok  " : "FAIL") \(label)")
    if !condition { failures += 1 }
}

let uz = "uz"
let abc = SourceInfo(id: "abc", isASCIICapable: true)
let russian = SourceInfo(id: "ru", isASCIICapable: false)
let cyrillic = SourceInfo(id: "uz-cyr", isASCIICapable: false)
let uzbek = SourceInfo(id: uz, isASCIICapable: true)

check(ToggleLogic.offTarget(uzbek: uz, previous: "ru", enabled: [abc, russian, uzbek]) == "ru",
      "turning off returns to the source used before")
check(ToggleLogic.offTarget(uzbek: uz, previous: "gone", enabled: [russian, abc, uzbek]) == "abc",
      "falls back to the first Latin source when the previous one was removed")
check(ToggleLogic.offTarget(uzbek: uz, previous: nil, enabled: [russian, cyrillic, uzbek]) == "ru",
      "falls back to any other source when none is Latin")
check(ToggleLogic.offTarget(uzbek: uz, previous: uz, enabled: [uzbek, abc]) == "abc",
      "never returns to Özbek itself")
check(ToggleLogic.offTarget(uzbek: uz, previous: nil, enabled: [uzbek]) == nil,
      "nothing to switch to when Özbek is the only source")

check(ToggleLogic.previousToRemember(current: "ru") == "ru", "remembers the source being left")

let sources = [russian, abc, uzbek]
check(PasswordGuard.step(secure: true, current: uz, uzbek: uz, previous: nil, enabled: sources, leftFor: nil)
      == PasswordGuard.Step(select: "abc", leftFor: "abc"),
      "a password field leaves Özbek for a Latin source")
check(PasswordGuard.step(secure: true, current: uz, uzbek: uz, previous: "ru", enabled: sources, leftFor: nil).select == "abc",
      "skips a non-Latin previous source, which password fields do not accept")
check(PasswordGuard.step(secure: true, current: "abc", uzbek: uz, previous: nil, enabled: sources, leftFor: "abc")
      == PasswordGuard.Step(select: nil, leftFor: "abc"),
      "stays put while the password field keeps focus")
check(PasswordGuard.step(secure: false, current: "abc", uzbek: uz, previous: nil, enabled: sources, leftFor: "abc")
      == PasswordGuard.Step(select: uz, leftFor: nil),
      "returns to Özbek once the password field is left")
check(PasswordGuard.step(secure: false, current: "ru", uzbek: uz, previous: nil, enabled: sources, leftFor: "abc")
      == PasswordGuard.Step(select: nil, leftFor: nil),
      "keeps a source the person picked meanwhile")
check(PasswordGuard.step(secure: true, current: "abc", uzbek: uz, previous: nil, enabled: sources, leftFor: nil)
      == PasswordGuard.Step(select: nil, leftFor: nil),
      "leaves other sources alone in password fields")
check(PasswordGuard.step(secure: true, current: uz, uzbek: uz, previous: nil, enabled: [russian, uzbek], leftFor: nil)
      == PasswordGuard.Step(select: nil, leftFor: nil),
      "does nothing when no Latin source is enabled")

let imID = "com.sanjarbarakayev.inputmethod.xattot"
check(LayoutMode.inputMethod.sourceID == imID && LayoutMode.inputMethod.rawValue == "inputMethod", "the input method has its fixed IDs")
let digraphID = LayoutMode.digraph.sourceID
let tugmaliID = LayoutMode.tugmali.sourceID
let digraph = SourceInfo(id: digraphID, isASCIICapable: true)
let tugmali = SourceInfo(id: tugmaliID, isASCIICapable: true)

check(LayoutMode.active(stored: nil, enabledIDs: [tugmaliID, "abc"]) == .tugmali, "only Tugmali enabled means Tugmali")
check(LayoutMode.active(stored: .tugmali, enabledIDs: [digraphID, "abc"]) == .digraph, "only the digraph layout enabled means digraph")
check(LayoutMode.active(stored: .tugmali, enabledIDs: [digraphID, tugmaliID]) == .tugmali, "both enabled follows the stored mode")
check(LayoutMode.active(stored: nil, enabledIDs: [digraphID, tugmaliID]) == .inputMethod, "both layouts enabled and nothing stored means the input method")
check(LayoutMode.active(stored: nil, enabledIDs: ["abc"]) == .inputMethod, "none enabled and nothing stored means the input method")
check(LayoutMode.active(stored: nil, enabledIDs: []) == .inputMethod, "no sources at all means the input method")
check(LayoutMode.active(stored: .digraph, enabledIDs: [imID, digraphID, tugmaliID]) == .digraph, "a stored mode wins over several enabled sources")
check(LayoutMode.active(stored: nil, enabledIDs: [imID, "abc"]) == .inputMethod, "only the input method enabled means the input method")
check(LayoutMode.allCases == [.inputMethod, .digraph, .tugmali], "the menu lists the input method first")
check(LayoutMode.active(stored: .tugmali, enabledIDs: ["abc"]) == .tugmali, "none enabled follows the stored mode")

check(LayoutMode.isOzbek(digraphID) && LayoutMode.isOzbek(tugmaliID), "both layouts count as Özbek")
check(LayoutMode.isOzbek(imID), "the input method counts as Özbek")
check(!LayoutMode.isOzbek("abc") && !LayoutMode.isOzbek(nil), "other sources and no source are not Özbek")

check(LayoutMode.switchSteps(to: .tugmali, enabledIDs: [digraphID, "abc"])
      == LayoutMode.Switch(enable: tugmaliID, disable: [digraphID], select: tugmaliID),
      "switching enables the target, disables the other, then selects the target")
check(LayoutMode.switchSteps(to: .tugmali, enabledIDs: [digraphID, tugmaliID, "abc"]).enable == nil,
      "nothing to enable when the target already is")
check(LayoutMode.switchSteps(to: .tugmali, enabledIDs: [tugmaliID, "abc"]).disable.isEmpty,
      "nothing to disable when only the target is enabled")

check(LayoutMode.completion(of: .tugmali, enabledIDs: [digraphID, "abc"]) == nil,
      "a pending switch waits while the target is not enabled")
check(LayoutMode.completion(of: .tugmali, enabledIDs: [digraphID, tugmaliID, "abc"])
      == LayoutMode.Switch(enable: nil, disable: [digraphID], select: tugmaliID),
      "a pending switch completes once the target is enabled, disabling the other layout")
check(LayoutMode.completion(of: .tugmali, enabledIDs: [tugmaliID, "abc"])?.disable.isEmpty == true,
      "a completed switch disables nothing when only the target is enabled")

check(ToggleLogic.previousToRemember(current: digraphID) == nil && ToggleLogic.previousToRemember(current: tugmaliID) == nil,
      "does not remember either Özbek layout")
check(LayoutMode.switchSteps(to: .inputMethod, enabledIDs: [digraphID, tugmaliID, "abc"])
      == LayoutMode.Switch(enable: imID, disable: [digraphID, tugmaliID], select: imID),
      "switching to the input method enables it and disables both layouts")
check(LayoutMode.switchSteps(to: .digraph, enabledIDs: [imID, digraphID, "abc"]).disable == [imID],
      "switching to a layout disables the input method")
check(ToggleLogic.previousToRemember(current: imID) == nil, "does not remember the input method")
check(ToggleLogic.previousToRemember(current: nil) == nil, "remembers nothing without a current source")

let both = [digraph, abc, tugmali]
check(PasswordGuard.step(secure: true, current: tugmaliID, uzbek: tugmaliID, previous: nil, enabled: both, leftFor: nil)
      == PasswordGuard.Step(select: "abc", leftFor: "abc"),
      "a password field leaves Tugmali for ABC")
check(PasswordGuard.step(secure: false, current: "abc", uzbek: tugmaliID, previous: nil, enabled: both, leftFor: "abc")
      == PasswordGuard.Step(select: tugmaliID, leftFor: nil),
      "returns to Tugmali once the password field is left")
check(PasswordGuard.step(secure: true, current: tugmaliID, uzbek: tugmaliID, previous: digraphID, enabled: both, leftFor: nil).select == "abc",
      "the password guard never picks the other Özbek layout")
check(ToggleLogic.offTarget(uzbek: tugmaliID, previous: digraphID, enabled: both) == "abc",
      "turning off never returns to the other Özbek layout")

check(PasswordGuard.step(secure: true, current: imID, uzbek: imID, previous: nil, enabled: [abc, SourceInfo(id: imID, isASCIICapable: true)], leftFor: nil)
      == PasswordGuard.Step(select: nil, leftFor: nil),
      "guardIgnoresInputMethod: a password field never moves the input method")
check(PasswordGuard.step(secure: true, current: imID, uzbek: imID, previous: "abc", enabled: sources, leftFor: "abc")
      == PasswordGuard.Step(select: nil, leftFor: nil),
      "the input method is left alone even with a stale leftFor")
check(ToggleLogic.offTarget(uzbek: imID, previous: digraphID, enabled: both + [SourceInfo(id: imID, isASCIICapable: true)]) == "abc",
      "turning off never returns to an Özbek source, the input method included")

let arc = SecureInputNotice.Holder(name: "Arc", canRestart: true)
let idle = SecureInputNotice.lines(on: false, secure: false, waiting: false, holder: nil)
check(idle == SecureInputNotice.Lines(state: "Özbekça: öçirilgan", toggle: "Yoqiş", reason: nil, restart: nil),
      "no notice without secure input")
check(SecureInputNotice.lines(on: true, secure: false, waiting: false, holder: nil).toggle == "Öçiriş",
      "offers to turn off when on")
check(SecureInputNotice.lines(on: false, secure: false, waiting: true, holder: arc) == idle,
      "ignores a wait that secure input already ended")
check(SecureInputNotice.lines(on: false, secure: true, waiting: false, holder: arc)
      == SecureInputNotice.Lines(state: "Özbekça: öçirilgan", toggle: "Parol maydoni yopilganda yoqiş",
                                 reason: "Parol rejimi yoqilgan, ehtimol: Arc", restart: "Arc'ni qayta işga tuşiriş…"),
      "names the likely holder and offers to restart it")
check(SecureInputNotice.lines(on: false, secure: true, waiting: true, holder: arc)
      == SecureInputNotice.Lines(state: "Özbekça: parol maydoni yopilganda yoqiladi", toggle: "Öçiriş",
                                 reason: "Parol rejimi yoqilgan, ehtimol: Arc", restart: "Arc'ni qayta işga tuşiriş…"),
      "says Özbek comes back once the password field closes")
check(SecureInputNotice.lines(on: false, secure: true, waiting: false, holder: nil).reason == "Parol rejimi yoqilgan",
      "still explains when the holder is unknown")
check(SecureInputNotice.lines(on: false, secure: true, waiting: false, holder: nil).restart == nil,
      "no restart without a known holder")
check(SecureInputNotice.lines(on: false, secure: true, waiting: false,
                              holder: .init(name: "loginwindow", canRestart: false)).restart == nil,
      "no restart for a system process")
check(SecureInputNotice.lines(on: true, secure: true, waiting: false, holder: arc).restart == nil,
      "no restart while Özbek is on, since nothing is blocked")

check(LoginOffer.shouldAsk(asked: false, launchesAtLogin: false, layoutEnabled: true),
      "asks once the layout is enabled")
check(!LoginOffer.shouldAsk(asked: true, launchesAtLogin: false, layoutEnabled: true), "never asks twice")
check(!LoginOffer.shouldAsk(asked: false, launchesAtLogin: true, layoutEnabled: true),
      "does not ask when it already launches at login")
check(!LoginOffer.shouldAsk(asked: false, launchesAtLogin: false, layoutEnabled: false),
      "waits until the layout is enabled")

let shortcut = Shortcut.standard
check(shortcut.display == "⌃⌥O", "default shortcut reads ⌃⌥O")
check(shortcut.carbonModifiers == UInt32(controlKey | optionKey), "default maps to Carbon control+option")
let full = Shortcut(keyCode: 49, modifiers: [.command, .shift, .option, .control])
check(full.display == "⌃⌥⇧⌘Space", "modifier symbols follow Apple's order")
check(Shortcut(keyCode: 31, modifiers: [.shift]).isUsable == false, "Shift alone is not a usable shortcut")
check(Shortcut(keyCode: 31, modifiers: [.command]).isUsable, "Command plus a key is usable")

let stored = Shortcut(keyCode: 0, modifiers: [.command, .option])
let suite = UserDefaults(suiteName: "xattot.tests")!
suite.removePersistentDomain(forName: "xattot.tests")
check(Shortcut.load(from: suite) == .standard, "loads the default when nothing is stored")
stored.save(to: suite)
check(Shortcut.load(from: suite) == stored, "round-trips through UserDefaults")
suite.removePersistentDomain(forName: "xattot.tests")

check(BundleInstaller.action(installed: nil, embedded: "a1") == .install, "installs when nothing is installed")
check(BundleInstaller.action(installed: "a1", embedded: "a1") == .none, "leaves an identical version alone")
check(BundleInstaller.action(installed: "a1", embedded: "b2") == .replace, "replaces a different version")
check(BundleInstaller.action(installed: "a1", embedded: nil) == .none, "does nothing without an embedded copy")
check(BundleInstaller.action(installed: nil, embedded: nil) == .none, "does nothing with neither present")

print(failures == 0 ? "all passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
