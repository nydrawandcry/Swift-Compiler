//тест, проверяющий вложенную интерполяцию
//в обычных и raw строках

let s = "A \(f("B \(x) C")) D"

appendLiteral("<a href=\"https://twitter.com/\(twitter)\">@\(twitter)</a>")

//raw строка внутри интерполяции другой raw строки

let s = ##"A \##(f(#"B"#)) C"##

let s = "\q \(f("ok")) accepted?"