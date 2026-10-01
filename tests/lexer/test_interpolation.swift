//тест, проверяющий интерполяцию (любую)


//STRING
let simple = "x = \(x)"
let repeated = "x = \(x), y = \(y)"

let parentheses = "result = \((x + (y * 2)))"
let textParentheses = "text = \(String("(inside)"))"

let nested = "A \(String("B \(x) C")) D"
let threeLevels = "A \(String("B \(String("C \(x) D")) E")) G"
let siblings = "A \(String("B \(x) C") + String("D \(y) E")) G"


//RAW-STRING
let raw = #"literal = \(x), value = \#(y)"#
let rawTwoHashes = ##"literal = \#(x), value = \##(y)"##
let normalInsideRaw = ##"A \##(String("B \(x) C")) D"##
let rawInsideNormal = "A \(String(#"B \#(x) C"#)) D"


//MULTILINE-STRING
let multiline = """
Before
x = \(x)
After
"""

let rawMultiline = ##"""
Literal: \(x)
Value: \##(y)
After
"""##

//экранирование (не должно быть интерполяции)
let escaped = "literal = \\(x)"

//RAW-STRING внутри интерполяции другой RAW-STRING
let rawInsideRaw = ##"A \##(String(#"B \#(x) C"#)) D"##