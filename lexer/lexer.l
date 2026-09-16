%option noyywrap
%option never-interactive
%option yylineno

%{
#include <stdio.h>
#include <string.h>
%}

%x STRING
%x COMMENT

    /* -~-~-~-~-~-~-~-~-~ NAMED GROUPS -~-~-~-~-~-~-~-~-~ */

    CUSTOM_OPERATOR [\/=\-+!*%<>&|^~?.]+

%%

    /* -~-~-~-~-~-~-~-~-~-~- RULES -~-~-~-~-~-~-~-~-~-~- */

        /* -~-~-~-~-~-~-~-~-~-~- KEYWORDS -~-~-~-~-~-~-~-~-~-~- */

            /* DECLARATIONS */

"associatedtype"    { printf("KEYWORD: associatedtype\n"); }
"borrowing"         { printf("KEYWORD: borrowing\n"); }
"class"             { printf("KEYWORD: class\n"); }
"consuming"         { printf("KEYWORD: consuming\n"); }
"deinit"            { printf("KEYWORD: deinit\n"); }
"enum"              { printf("KEYWORD: enum\n"); }
"extension"         { printf("KEYWORD: extension\n"); }
"fileprivate"       { printf("KEYWORD: fileprivate\n"); }
"func"              { printf("KEYWORD: func\n"); }
"import"            { printf("KEYWORD: import\n"); }
"init"              { printf("KEYWORD: init\n"); }
"inout"             { printf("KEYWORD: inout\n"); }
"internal"          { printf("KEYWORD: internal\n"); }
"let"               { printf("KEYWORD: let\n"); }
"nonisolated"       { printf("KEYWORD: nonisolated\n"); }
"open"              { printf("KEYWORD: open\n"); }
"operator"          { printf("KEYWORD: operator\n"); }
"precedencegroup"   { printf("KEYWORD: precedencegroup\n"); }
"private"           { printf("KEYWORD: private\n"); }
"protocol"          { printf("KEYWORD: protocol\n"); }
"public"            { printf("KEYWORD: public\n"); }
"rethrows"          { printf("KEYWORD: rethrows\n"); }
"static"            { printf("KEYWORD: static\n"); }
"struct"            { printf("KEYWORD: struct\n"); }
"subscript"         { printf("KEYWORD: subscript\n"); }
"typealias"         { printf("KEYWORD: typealias\n"); }
"var"               { printf("KEYWORD: var\n"); }

            /* STATEMENTS */

"break"             { printf("KEYWORD: break\n"); }
"case"              { printf("KEYWORD: case\n"); }
"catch"             { printf("KEYWORD: catch\n"); }
"continue"          { printf("KEYWORD: continue\n"); }
"default"           { printf("KEYWORD: default\n"); }
"defer"             { printf("KEYWORD: defer\n"); }
"do"                { printf("KEYWORD: do\n"); }
"else"              { printf("KEYWORD: else\n"); }
"fallthrough"       { printf("KEYWORD: fallthrough\n"); }
"for"               { printf("KEYWORD: for\n"); }
"guard"             { printf("KEYWORD: guard\n"); }
"if"                { printf("KEYWORD: if\n"); }
"in"                { printf("KEYWORD: in\n"); }
"repeat"            { printf("KEYWORD: repeat\n"); }
"return"            { printf("KEYWORD: return\n"); }
"switch"            { printf("KEYWORD: switch\n"); }
"throw"             { printf("KEYWORD: throw\n"); }
"where"             { printf("KEYWORD: where\n"); }
"while"             { printf("KEYWORD: while\n"); }

            /* EXPRESSIONS AND TYPES */

"Any"               { printf("KEYWORD: Any\n"); }
"as"                { printf("KEYWORD: as\n"); }
"await"             { printf("KEYWORD: await\n"); }
"is"                { printf("KEYWORD: is\n"); }
"self"              { printf("KEYWORD: self\n"); }
"Self"              { printf("KEYWORD: Self\n"); }
"super"             { printf("KEYWORD: super\n"); }
"throws"            { printf("KEYWORD: throws\n"); }
"try"               { printf("KEYWORD: try\n"); }

            /* LITERAL KEYWORDS */

"true"              { printf("BOOLEAN_LITERAL: true\n"); }
"false"             { printf("BOOLEAN_LITERAL: false\n"); }
"nil"               { printf("NIL_LITERAL: nil\n"); }

            /* KEYWORDS USED IN PATTERNS: _ */

_                   { printf("KEYWORD: used in patterns _\n"); }

            /* KEYWORDS THAT BEGIN WITH A NUMBER SIGN (#) */

"#available"        { printf("KEYWORD: #available\n"); }
"#colorLiteral"     { printf("KEYWORD: #colorLiteral\n"); }
"#else"             { printf("KEYWORD: #else\n"); }
"#elseif"           { printf("KEYWORD: #elseif\n"); }
"#endif"            { printf("KEYWORD: #endif\n"); }
"#fileLiteral"      { printf("KEYWORD: #fileLiteral\n"); }
"#if"               { printf("KEYWORD: #if\n"); }
"#imageLiteral"     { printf("KEYWORD: #imageLiteral\n"); }
"#keyPath"          { printf("KEYWORD: #keyPath\n"); }
"#selector"         { printf("KEYWORD: #selector\n"); }
"#sourceLocation"   { printf("KEYWORD: #sourceLocation\n"); }
"#unavailable"      { printf("KEYWORD: #unavailable\n"); }

            /*
            * Swift 5.9+:
            * #column, #file, #line, etc. are implemented as standard-library macros,
            * not reserved keywords.
            * They will maybe be handled separately.
            */

            /* KEYWORDS RESERVED IN PARTICULAR CONTEXTS */
                /* todo outside the context in which they appear in the grammar,
                    they can be used as identifiers
                        так что это не обычный keyword, а CONTEXTUAL_KEYWORD
                        парсер разберется */

"associativity"      { printf("CONTEXTUAL_KEYWORD: associativity\n"); }
"async"              { printf("CONTEXTUAL_KEYWORD: async\n"); }
"convenience"        { printf("CONTEXTUAL_KEYWORD: convenience\n"); }
"didSet"             { printf("CONTEXTUAL_KEYWORD: didSet\n"); }
"dynamic"            { printf("CONTEXTUAL_KEYWORD: dynamic\n"); }
"final"              { printf("CONTEXTUAL_KEYWORD: final\n"); }
"get"                { printf("CONTEXTUAL_KEYWORD: get\n"); }
"indirect"           { printf("CONTEXTUAL_KEYWORD: indirect\n"); }
"infix"              { printf("CONTEXTUAL_KEYWORD: infix\n"); }
"lazy"               { printf("CONTEXTUAL_KEYWORD: lazy\n"); }
"left"               { printf("CONTEXTUAL_KEYWORD: left\n"); }
"mutating"           { printf("CONTEXTUAL_KEYWORD: mutating\n"); }
"none"               { printf("CONTEXTUAL_KEYWORD: none\n"); }
"nonmutating"        { printf("CONTEXTUAL_KEYWORD: nonmutating\n"); }
"optional"           { printf("CONTEXTUAL_KEYWORD: optional\n"); }
"override"           { printf("CONTEXTUAL_KEYWORD: override\n"); }
"package"            { printf("CONTEXTUAL_KEYWORD: package\n"); }
"postfix"            { printf("CONTEXTUAL_KEYWORD: postfix\n"); }
"precedence"         { printf("CONTEXTUAL_KEYWORD: precedence\n"); }
"prefix"             { printf("CONTEXTUAL_KEYWORD: prefix\n"); }
"Protocol"           { printf("CONTEXTUAL_KEYWORD: Protocol\n"); }
"required"           { printf("CONTEXTUAL_KEYWORD: required\n"); }
"right"              { printf("CONTEXTUAL_KEYWORD: right\n"); }
"set"                { printf("CONTEXTUAL_KEYWORD: set\n"); }
"some"               { printf("CONTEXTUAL_KEYWORD: some\n"); }
"Type"               { printf("CONTEXTUAL_KEYWORD: Type\n"); }
"unowned"            { printf("CONTEXTUAL_KEYWORD: unowned\n"); }
"weak"               { printf("CONTEXTUAL_KEYWORD: weak\n"); }
"willSet"            { printf("CONTEXTUAL_KEYWORD: willSet\n"); }

        /* IDENTIFIERS */

[A-Za-z_][A-Za-z_0-9] * { /* todo пока вот так по-простому */
    printf("IDENTIFIER: %s\n", yytext);
}

        /* NUMERIC LITERALS */

        /* STRINGS */

        /* COMMENTS */

        /* OPERATORS */

            /* identity */

"==="  { printf("OPERATOR: ===\n"); }
"!=="  { printf("OPERATOR: !==\n"); }

            /* range operators */

"..."  { printf("OPERATOR: ...\n"); }
"..<"  { printf("OPERATOR: ..<\n"); }

            /* compound assignment */

"+="   { printf("OPERATOR: +=\n"); }
"-="   { printf("OPERATOR: -=\n"); }
"*="   { printf("OPERATOR: *=\n"); }
"/="   { printf("OPERATOR: /=\n"); }
"%="   { printf("OPERATOR: %%=\n"); }

            /* overflow */

"&+"   { printf("OPERATOR: &+\n"); }
"&-"   { printf("OPERATOR: &-\n"); }
"&*"   { printf("OPERATOR: &*\n"); }

            /* comparison */

">="   { printf("OPERATOR: >=\n"); }
"<="   { printf("OPERATOR: <=\n"); }
"=="   { printf("OPERATOR: ==\n"); }
"!="   { printf("OPERATOR: !=\n"); }
">"    { printf("OPERATOR: >\n"); }
"<"    { printf("OPERATOR: <\n"); }

            /* nil coalescing */

"??"   { printf("OPERATOR: ??\n"); }

            /* logical */

"&&"   { printf("OPERATOR: &&\n"); }
"||"   { printf("OPERATOR: ||\n"); }
"!"    { printf("OPERATOR: !\n"); }

            /* member and function */

"->"   { printf("OPERATOR: ->\n"); }
"."    { printf("OPERATOR: .\n"); }
":"    { printf("OPERATOR: :\n"); }

            /* bitwise */

">>"   { printf("OPERATOR: >>\n"); }
"<<"   { printf("OPERATOR: <<\n"); }
"~"    { printf("OPERATOR: ~\n"); }
"&"    { printf("OPERATOR: &\n"); }
"|"    { printf("OPERATOR: |\n"); }
"^"    { printf("OPERATOR: ^\n"); }

            /* assignment and arithmetic */

"="    { printf("OPERATOR: =\n"); }
"+"    { printf("OPERATOR: +\n"); }
"-"    { printf("OPERATOR: -\n"); }
"*"    { printf("OPERATOR: *\n"); }
"/"    { printf("OPERATOR: /\n"); }
"%"    { printf("OPERATOR: %%\n"); }

            /* ternary */

"?"    { printf("OPERATOR: ?\n"); }

            /* custom */

{CUSTOM_OPERATOR}   { printf("CUSTOM_OPERATOR: %s\n", yytext); }

        /* PUNCTUATION */

        /* WHITESPACES */

[ \t\r]+     ;
\n           ;


    /* ERRORS */

. {
    fprintf(stderr,
        "Lexer error at line %d: unexpected symbol '%s'\n",
        yylineno,
        yytext);
}

<<EOF>> {
    return 0;
}

%%