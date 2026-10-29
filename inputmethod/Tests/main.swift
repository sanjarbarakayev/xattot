import Foundation

runRulesTests()
runDigraphTests()
runTutuqTests()
runForeignTests()
runKeysTests()
runGuardTests()
runQuoteTests()
runMarkedTests()
runAppModesTests()
runParityTests()
runKeyMapperTests()
runHostSessionTests()

if failures == 0 {
    print("all passed")
} else {
    print("\(failures) failed")
    exit(1)
}
