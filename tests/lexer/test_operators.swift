// префикс

-a                  // PREFIX: -
+a                  // PREFIX: +
!a                  // PREFIX: !
!flag               // PREFIX: !
~mask               // PREFIX: ~

-42                 // PREFIX: -
+3.14               // PREFIX: +

...end              // PREFIX: ...
..<end              // PREFIX: ..<

// инфикс с пробелом

a + b               // INFIX: +
a - b               // INFIX: -
a * b               // INFIX: *
a / b               // INFIX: /
a ?? b              // INFIX: ??

a = b               // INFIX: =
a=b                 // INFIX: =
a += b              // INFIX: +=
a -= b              // INFIX: -=
a *= b              // INFIX: *=
a /= b              // INFIX: /=
a %= b              // INFIX: %=
a == b              // INFIX: ==
a != b              // INFIX: !=
a >= b              // INFIX: >=
a <= b              // INFIX: <=
a > b               // INFIX: >
a < b               // INFIX: <
a === b             // INFIX: ===
a !== b             // INFIX: !==
a && b              // INFIX: &&
a || b              // INFIX: ||
a ?? b              // INFIX: ??

a & b               // INFIX: &
a | b               // INFIX: |
a ^ b               // INFIX: ^
a << 2              // INFIX: <<
a >> 2              // INFIX: >>
a &+ b              // INFIX: &+
a &- b              // INFIX: &-
a &* b              // INFIX: &*

// инфикс без пробелов

a+b                 // INFIX: +
a-b                 // INFIX: -
a*b                 // INFIX: *
a/b                 // INFIX: /
a%b                 // INFIX: %

a==b                // INFIX: ==
a!=b                // INFIX: !=
a>=b                // INFIX: >=
a<=b                // INFIX: <=
a>b                 // INFIX: >
a<b                 // INFIX: <

a===b               // INFIX: ===
a!==b               // INFIX: !==

a&&b                // INFIX: &&
a||b                // INFIX: ||
a??b                // INFIX: ??

a&b                 // INFIX: &
a|b                 // INFIX: |
a^b                 // INFIX: ^
a<<b                // INFIX: <<
a>>b                // INFIX: >>

a&+b                // INFIX: &+
a&-b                // INFIX: &-
a&*b                // INFIX: &*

start...end         // INFIX: ...
start..<end         // INFIX: ..<

1...5               // INFIX: ...
1..<5               // INFIX: ..<

// постфикс

optional!           // POSTFIX: !
optional!.field     // POSTFIX: !
optional?.field     // POSTFIX: ?
optional?[index]    // POSTFIX: ?
callback?()         // POSTFIX: ?

start...            // POSTFIX: ...
values[start...]    // POSTFIX: ...


// кастомные операторы

+++a                // PREFIX: +++
a+++                // POSTFIX: +++
a+++b               // INFIX: +++
a +++ b             // INFIX: +++

**a                 // PREFIX: **
a**                 // POSTFIX: **
a**b                // INFIX: **

.+.a                // PREFIX: .+.
a.+.                // POSTFIX: .+.
a.+.b               // INFIX: .+.
a+++ b              // POSTFIX: +++
a +++b              // PREFIX: +++

// исключение: следующая вплотную точка
a+++.field          // POSTFIX: +++

// скобки, запятые, двоеточия

(-a)                // PREFIX: -
(+a)                // PREFIX: +
(!flag)             // PREFIX: !

[-a,+b]             // PREFIX: -, PREFIX: +
call(-a,+b)         // PREFIX: -, PREFIX: +
update(&a)          // PREFIX: &

["key":-a]          // PREFIX: -

(optional!)         // POSTFIX: !
[optional!]         // POSTFIX: !
call(optional!)     // POSTFIX: !
call(optional!,b)   // POSTFIX: !


// несколько операторов в одном выражении

-a + b              // PREFIX: -, INFIX: +
a * -b              // INFIX: *, PREFIX: -
!flag && other      // PREFIX: !, INFIX: &&
optional! + b       // POSTFIX: !, INFIX: +
-a + optional!      // PREFIX: -, INFIX: +, POSTFIX: !


// комментарии как белые разделители

/* comment */-a                 // PREFIX: -
a/* left */+/* right */b         // INFIX: +
a /* outer /* inner */ end */ + b // INFIX: +


a/* comment */b+c   // INFIX: + — проверка сброса флага после b

maybeValue![0]      // POSTFIX: ! — справа нет разделителя и точки

// интерполяция

"\(-a)"             // PREFIX: -
"\(a+b)"            // INFIX: +
"\(optional!)"      // POSTFIX: !
"\(call(-a,+b))"    // PREFIX: -, PREFIX: +

#"\#(-a)"#          // PREFIX: -
#"\#(a+b)"#         // INFIX: +

a =b                // Lexer error
a= b                // Lexer error