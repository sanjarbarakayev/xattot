// Plain assertions runner: Command Line Tools ship without XCTest.
var failures = 0

func check(_ condition: Bool, _ label: String) {
    print("\(condition ? "ok  " : "FAIL") \(label)")
    if !condition { failures += 1 }
}
