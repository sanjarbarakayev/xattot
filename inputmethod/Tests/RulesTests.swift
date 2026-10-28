func runRulesTests() {
    check(Rules.digraph("s", "h") == "ş", "s+h is ş")
    check(Rules.digraph("S", "H") == "Ş", "S+H is Ş")
    check(Rules.digraph("s", "H") == nil, "lowercase opener ignores H")
    check(Rules.digraph("c", "h") == "ç" && Rules.digraph("C", "h") == "Ç", "ch and Ch")
    check(Rules.digraph("o", "'") == "ö" && Rules.digraph("o", "`") == "ö", "o' and o`")
    check(Rules.digraph("G", "`") == "Ğ", "G` is Ğ")
    check(Rules.isOpener("g") && !Rules.isOpener("a"), "openers are c s o g and capitals")
    check(Rules.optionLetter("c") == "ç" && Rules.optionLetter("S") == "Ş", "Option letters")
    check(Rules.optionLetter("h") == "h" && Rules.optionLetter("'") == "ʼ", "Option+H plain h, Option+' tutuq")
    check(Rules.optionLetter("\"") == "ʼ", "Shift+Option+apostrophe also types tutuq")
    check(Rules.optionLetter("e") == nil, "other Option keys pass to ABC dead keys")
}
