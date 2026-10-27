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

check(ToggleLogic.isOn(current: uz, uzbek: uz), "active when Özbek is current")
check(!ToggleLogic.isOn(current: "abc", uzbek: uz), "inactive on ABC")
check(!ToggleLogic.isOn(current: nil, uzbek: uz), "inactive with no current source")

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

check(ToggleLogic.previousToRemember(current: "ru", uzbek: uz) == "ru", "remembers the source being left")
check(ToggleLogic.previousToRemember(current: uz, uzbek: uz) == nil, "does not remember Özbek")

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

let arc = SecureInputNotice.Holder(name: "Arc", canRestart: true)
let idle = SecureInputNotice.lines(on: false, secure: false, waiting: false, holder: nil)
check(idle == SecureInputNotice.Lines(state: "Özbek (Lotin): öçirilgan", toggle: "Yoqiş", reason: nil, restart: nil),
      "no notice without secure input")
check(SecureInputNotice.lines(on: true, secure: false, waiting: false, holder: nil).toggle == "Öçiriş",
      "offers to turn off when on")
check(SecureInputNotice.lines(on: false, secure: false, waiting: true, holder: arc) == idle,
      "ignores a wait that secure input already ended")
check(SecureInputNotice.lines(on: false, secure: true, waiting: false, holder: arc)
      == SecureInputNotice.Lines(state: "Özbek (Lotin): öçirilgan", toggle: "Parol maydoni yopilganda yoqiş",
                                 reason: "Parol rejimi yoqilgan, ehtimol: Arc", restart: "Arc'ni qayta işga tuşiriş…"),
      "names the likely holder and offers to restart it")
check(SecureInputNotice.lines(on: false, secure: true, waiting: true, holder: arc)
      == SecureInputNotice.Lines(state: "Özbek (Lotin): parol maydoni yopilganda yoqiladi", toggle: "Öçiriş",
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

print(failures == 0 ? "all passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
