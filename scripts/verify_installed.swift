// Types key sequences through the installed layout with UCKeyTranslate, the same
// translation apps get, and checks the result. Usage: swift verify_installed.swift
import Carbon

let idPrefix = "com.sanjarbarakayev.keyboardlayout.xattot.keylayout."
let shift: UInt32 = 0x02
let option: UInt32 = 0x08
let caps: UInt32 = 0x04
let command: UInt32 = 0x01

typealias Case = (String, [(UInt16, UInt32)], String)

func layoutData(for suffix: String) -> UnsafePointer<UCKeyboardLayout>? {
    let id = idPrefix + suffix
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
        let source = sources.first,
        let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else {
        print("FAIL: \(id) is not visible to the Text Input Sources service")
        return nil
    }
    let name = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyLocalizedName)!)
        .takeUnretainedValue()
    print("found: \(name) (\(id))")
    let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
    return UnsafeRawPointer(CFDataGetBytePtr(data)!).assumingMemoryBound(to: UCKeyboardLayout.self)
}

func type(_ layout: UnsafePointer<UCKeyboardLayout>, _ keys: [(UInt16, UInt32)]) -> String {
    var state: UInt32 = 0
    var result = ""
    for (code, mods) in keys {
        var chars = [UniChar](repeating: 0, count: 8)
        var length = 0
        UCKeyTranslate(
            layout, code, UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
            0, &state, chars.count, &length, &chars)
        result += String(utf16CodeUnits: chars, count: length)
    }
    return result
}

let s: UInt16 = 1
let h: UInt16 = 4
let apostrophe: UInt16 = 39
let backtick: UInt16 = 50
let leftBracket: UInt16 = 33
let semicolon: UInt16 = 41
let nine: UInt16 = 25
let tugmaliCases: [Case] = [
    ("[", [(leftBracket, 0)], "ö"),
    ("Shift [", [(leftBracket, shift)], "Ö"),
    ("caps ;", [(semicolon, caps)], "Ş"),
    ("'", [(apostrophe, 0)], "ç"),
    ("`", [(backtick, 0)], "\u{02BC}"),
    ("opt-[", [(leftBracket, option)], "["),
    ("shift-opt-'", [(apostrophe, shift | option)], "\""),
    ("opt-9", [(nine, option)], "\u{201C}"),
    ("cmd-[", [(leftBracket, command)], "["),
    ("s h", [(s, 0), (h, 0)], "sh"),
]

var failed = 0
var total = 0
guard let layout = layoutData(for: "UzbekLatinTugmali") else { exit(1) }
for (label, keys, expected) in tugmaliCases {
    let got = type(layout, keys)
    let ok = got == expected
    failed += ok ? 0 : 1
    total += 1
    print("\(ok ? "ok  " : "FAIL") \(label) -> \(got)\(ok ? "" : " (expected \(expected))")")
}
print(failed == 0 ? "all \(total) passed" : "\(failed) failed")
exit(failed == 0 ? 0 : 1)
