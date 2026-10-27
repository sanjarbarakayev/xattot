// Types key sequences through the installed layout with UCKeyTranslate, the same
// translation apps get, and checks the result. Usage: swift verify_installed.swift
import Carbon

let sourceID = "com.sanjarbarakayev.keyboardlayout.xattot.keylayout.UzbekLatin"
let shift: UInt32 = 0x02, option: UInt32 = 0x08, caps: UInt32 = 0x04, command: UInt32 = 0x01

let filter = [kTISPropertyInputSourceID as String: sourceID] as CFDictionary
guard let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
      let source = sources.first,
      let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
else {
    print("FAIL: \(sourceID) is not visible to the Text Input Sources service")
    exit(1)
}
let name = Unmanaged<CFString>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyLocalizedName)!).takeUnretainedValue()
print("found: \(name) (\(sourceID))")

let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
let layout = UnsafeRawPointer(CFDataGetBytePtr(data)!).assumingMemoryBound(to: UCKeyboardLayout.self)

func type(_ keys: [(UInt16, UInt32)]) -> String {
    var state: UInt32 = 0
    var result = ""
    for (code, mods) in keys {
        var chars = [UniChar](repeating: 0, count: 8)
        var length = 0
        UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
                       0, &state, chars.count, &length, &chars)
        result += String(utf16CodeUnits: chars, count: length)
    }
    return result
}

let c: UInt16 = 8, h: UInt16 = 4, s: UInt16 = 1, o: UInt16 = 31, g: UInt16 = 5
let a: UInt16 = 0, apostrophe: UInt16 = 39, backtick: UInt16 = 50, space: UInt16 = 49
let w: UInt16 = 13, i: UInt16 = 34, d: UInt16 = 2, e: UInt16 = 14, ret: UInt16 = 36
let cases: [(String, [(UInt16, UInt32)], String)] = [
    ("c h", [(c, 0), (h, 0)], "ç"),
    ("C h", [(c, shift), (h, 0)], "Ç"),
    ("C H", [(c, shift), (h, shift)], "Ç"),
    ("caps c h", [(c, caps), (h, caps)], "Ç"),
    ("s h", [(s, 0), (h, 0)], "ş"),
    ("S h", [(s, shift), (h, 0)], "Ş"),
    ("o '", [(o, 0), (apostrophe, 0)], "ö"),
    ("O '", [(o, shift), (apostrophe, 0)], "Ö"),
    ("g `", [(g, 0), (backtick, 0)], "ğ"),
    ("G '", [(g, shift), (apostrophe, 0)], "Ğ"),
    ("c a", [(c, 0), (a, 0)], "ca"),
    ("s s h", [(s, 0), (s, 0), (h, 0)], "sş"),
    ("s opt-h", [(s, 0), (h, option)], "sh"),
    ("w i s h", [(w, 0), (i, 0), (s, 0), (h, 0)], "wish"),
    ("W I S H", [(w, shift), (i, shift), (s, shift), (h, shift)], "WISH"),
    ("c a s h", [(c, 0), (a, 0), (s, 0), (h, 0)], "cash"),
    ("c o d e", [(c, 0), (o, 0), (d, 0), (e, 0)], "code"),
    ("w space s h", [(w, 0), (space, 0), (s, 0), (h, 0)], "w ş"),
    ("w return s h", [(w, 0), (ret, 0), (s, 0), (h, 0)], "w\rş"),
    ("s a ' a", [(s, 0), (a, 0), (apostrophe, 0), (a, 0)], "sa\u{02BC}a"),
    ("a s ' a", [(a, 0), (s, 0), (apostrophe, 0), (a, 0)], "as\u{02BC}a"),
    ("a ' s h", [(a, 0), (apostrophe, 0), (s, 0), (h, 0)], "a\u{02BC}ş"),
    ("' a ' space", [(apostrophe, 0), (a, 0), (apostrophe, 0), (space, 0)], "'a' "),
    ("w ' a", [(w, 0), (apostrophe, 0), (a, 0)], "w'a"),
    ("o opt-'", [(o, 0), (apostrophe, option)], "o\u{02BC}"),
    ("opt-c opt-s opt-g opt-o", [(c, option), (s, option), (g, option), (o, option)], "çşğö"),
    ("opt-u o", [(32, option), (o, 0)], "ö"),
    ("opt-e space", [(14, option), (space, 0)], "\u{00B4}"),
    ("cmd-c", [(c, command)], "c"),
]

var failed = 0
for (label, keys, expected) in cases {
    let got = type(keys)
    let ok = got == expected
    failed += ok ? 0 : 1
    print("\(ok ? "ok  " : "FAIL") \(label) -> \(got)\(ok ? "" : " (expected \(expected))")")
}
print(failed == 0 ? "all \(cases.count) passed" : "\(failed) failed")
exit(failed == 0 ? 0 : 1)
