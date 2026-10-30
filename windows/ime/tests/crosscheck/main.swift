import Foundation

// Types each corpus line through the Swift engine and prints the text, caret marked with `|`,
// after every key and after the final word boundary. replay.cpp prints the same for the C++ port.
// Usage: replay <inputmethod/Resources> < corpus. Named main.swift so swiftc runs its top-level code.

let resources = URL(fileURLWithPath: CommandLine.arguments[1])
guard let bundled = try? WordListLexicon.load(from: resources) else {
    FileHandle.standardError.write("bundled lexicon did not load\n".data(using: .utf8)!)
    exit(1)
}
let small = WordListLexicon(
    english: ["push", "change", "shop", "don't", "video", "chap", "chrome", "log", "chin", "sham", "show"],
    uzbekExceptions: ["çap", "çin", "şam"])

func unescape(_ s: Substring) -> String {
    var out = ""
    var escaped = false
    for c in s {
        if escaped {
            out.append(c == "n" ? "\n" : c == "t" ? "\t" : c)
            escaped = false
        } else if c == "\\" {
            escaped = true
        } else {
            out.append(c)
        }
    }
    return out
}

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\t", with: "\\t")
}

func notation(_ key: Key) -> String {
    switch key {
    case .character(let c, let option): return (option ? "⌥" : "") + String(c)
    case .named(.backspace): return "⌫"
    case .named(.returnKey): return "↵"
    case .named(.tab): return "⇥"
    case .named(.escape): return "⎋"
    case .named(.left): return "←"
    case .named(.right): return "→"
    case .named, .shortcut: return "⌘"
    }
}

func snapshot(_ client: FakeClient) -> String {
    let chars = Array(client.text)
    return escape(String(chars[..<client.caret]) + "|" + String(chars[client.caret...]))
}

var output = ""
while let line = readLine(strippingNewline: true) {
    let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
    let config = parts[0].split(separator: ",")
    let lexicon: Lexicon = config[1] == "small" ? small : config[1] == "bundled" ? bundled as Lexicon : EmptyLexicon()
    var engine = Engine(lexicon: lexicon, mode: config[0] == "marked" ? .marked : .eager)
    var client = FakeClient(stale: config[2] == "1", smartQuotes: config[3] == "1")
    var snapshots: [String] = []
    for key in FakeClient.keys(unescape(parts[1])) {
        client.type(notation(key), into: &engine)
        snapshots.append(snapshot(client))
    }
    client.finish(&engine)
    snapshots.append(snapshot(client))
    output += line + "\t" + snapshots.joined(separator: "\t") + "\n"
}
FileHandle.standardOutput.write(output.data(using: .utf8)!)
exit(failures == 0 ? 0 : 1)
