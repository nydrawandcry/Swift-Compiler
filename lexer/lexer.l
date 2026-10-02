%option noyywrap
%option never-interactive
%option yylineno
%option stack

%{
#include <stdio.h>
#include <string.h>
#include <vector>
#include "../utils/Buffer/Buffer.h"

Buffer buffer;
int commentDepth = 0;
// счетчик для вложенной интерполяции
std::vector<int> interpolationDepths;
// флаг, чтобы не возвращать строку если в ней есть ошибки
bool stringInvalid = false;
// счетчик # при открытии raw строкиы
int rawDelimiterLength = 0;
// находимся ли мы в первой строке после """
bool multilineFirstLine = false;
// структура данных для хранения информации о предыдущих строках (для вложенности)
struct StringContext {
    Buffer buffer;
    bool stringInvalid;
    int rawDelimiterLength;
    bool multilineFirstLine;
};
//контейнер данных о предыдущих строках
std::vector<StringContext> stringContexts;

// для вывода чисел
std::string digitBuffer = "";

int intBuf = 0;
float floatBuf = 0;
double doubleBuf = 0;

// функция для удаления нижнего подчеркивания
void deleteUnderscores(const char* source, std::string& str);
// функция для подсчета #
int countHashes(const char* text, int length, int start);
// функция для подсчета # при закрытии многострочного raw текста
int countClosingHashes(const char* text, int length);
// функция добавления в строку (буфер) escape последовательности
void appendRawStringEscape(const char* replacement);
    // для многострочного текста
// проверка, что содержимое многострочной строки не началось раньше перевода строки (потенциально какая то некрасивая функция функция)
void checkMultilineContentStart();
// добавление перевода строки в многострочном тексте
void appendMultilineNewline();
// добавление текста
void appendMultilineText(const char* text);
// вывод текста
void printMultilineString(const char* tokenType, const std::string& indentation);
// удаление отступов из строк текста
std::string removeMultilineIndentation(const std::string& text, const std::string& indentation, bool& indentationIsValid);
// сохранить данные предыдущей строки и подготовить переменные к новой строке
void beginString(int hashCount, bool isMultiline);
// вернуть сохраненные данные после завершения строки
void endString();
// очистить данные при завершении/прерывании сканирования
void clearStringContexts();
%}

%x STRING
%x COMMENT
%x RAW_STRING
%x MULTILINE_STRING
%x RAW_MULTILINE_STRING
%x AFTER_OPERATOR
%s INTERPOLATION

    /* -~-~-~-~-~-~-~-~-~ NAMED GROUPS -~-~-~-~-~-~-~-~-~ */

        /* -~-~-~-~-~-~-~-~-~-~- OPERATORS -~-~-~-~-~-~-~-~-~-~- */

            /*
             Custom operators can begin with one of the ASCII characters /, =, -, +, !, *, %, <, >, &, |, ^, ?, or ~,
             or one of the Unicode characters defined in the grammar below (which include characters from the
             Mathematical Operators, Miscellaneous Symbols, and Dingbats Unicode blocks, among others).
             After the first character, combining Unicode characters are also allowed (надо не надо?? щас реализация без юникода)
            */

OPERATOR                 [\/=\-+!\*%<>&|^\~?]+
DOT_OPERATOR             \.[.\/=\-+!\*%<>&|^\~?]+

        /* -~-~-~-~-~-~-~-~-~-~- DIGITS -~-~-~-~-~-~-~-~-~-~- */
    /* подшаблон для целых чисел (todo ????????) */
DECIMAL_DIGITS    [0-9][0-9_]*
    /* подшаблон для экспоненты */
DECIMAL_EXPONENT  [eE][+-]?{DECIMAL_DIGITS}
    /* подшаблон для шестнадцатеричных чисел */
HEX_DIGITS        [0-9a-fA-F][0-9a-fA-F_]*
    /* подшаблон для экспоненты */
HEX_EXPONENT      [pP][+-]?{DECIMAL_DIGITS}

INT_BINARY        0b[01][01_]*
INT_DECIMAL       {DECIMAL_DIGITS}
INT_OCTAL         0o[0-7][0-7_]*
INT_HEXADECIMAL   0x{HEX_DIGITS}

FLOAT_DECIMAL     {DECIMAL_DIGITS}\.{DECIMAL_DIGITS}({DECIMAL_EXPONENT})?|{DECIMAL_DIGITS}{DECIMAL_EXPONENT}
FLOAT_HEXADECIMAL 0x{HEX_DIGITS}(\.{HEX_DIGITS})?{HEX_EXPONENT}

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

        /* TYPES */

Int                  { printf("TYPE (Int): %s\n", yytext); }
Int8                 { printf("TYPE (Int8): %s\n", yytext); }
Int16                { printf("TYPE (Int16): %s\n", yytext); }
Int32                { printf("TYPE (Int32): %s\n", yytext); }
Int64                { printf("TYPE (Int64): %s\n", yytext); }
UInt                 { printf("TYPE (UInt): %s\n", yytext); }
UInt8                { printf("TYPE (UInt8): %s\n", yytext); }
UInt16               { printf("TYPE (UInt16): %s\n", yytext); }
UInt32               { printf("TYPE (UInt32): %s\n", yytext); }
UInt64               { printf("TYPE (UInt64): %s\n", yytext); }
Float                { printf("TYPE (Float): %s\n", yytext); }
Float80              { printf("TYPE (Float80): %s\n", yytext); }
Double               { printf("TYPE (Double): %s\n", yytext); }
Bool                 { printf("TYPE (Bool): %s\n", yytext); }
String               { printf("TYPE (String): %s\n", yytext); }
Character            { printf("TYPE (Character): %s\n", yytext); }

        /* IDENTIFIERS */

[A-Za-z_][A-Za-z_0-9]* { /* todo пока вот так по-простому */
    printf("IDENTIFIER: %s\n", yytext);
}

        /* NUMERIC LITERALS */

            /* VALID FLOATS */

{FLOAT_HEXADECIMAL} {
    deleteUnderscores(yytext, digitBuffer);
    doubleBuf = std::stod(digitBuffer);

    printf("FLOATING_POINT_LITERAL (hexadecimal): %.15g\n", doubleBuf);
}

{FLOAT_DECIMAL} {
    deleteUnderscores(yytext, digitBuffer);
    doubleBuf = std::stod(digitBuffer);

    printf("FLOATING_POINT_LITERAL (decimal): %.15g\n", doubleBuf);
}

            /* FLOAT ERRORS */

{DECIMAL_DIGITS}\.{DECIMAL_DIGITS}[eE][+-]? {
    fprintf(stderr,
        "Lexer error at line %d: incomplete decimal exponent '%s'\n",
        yylineno,
        yytext);
}

{DECIMAL_DIGITS}[eE][+-]? {
    fprintf(stderr,
        "Lexer error at line %d: incomplete decimal exponent '%s'\n",
        yylineno,
        yytext);
}


0x{HEX_DIGITS}(\.{HEX_DIGITS})?[pP][+-]? {
    fprintf(stderr,
        "Lexer error at line %d: incomplete hexadecimal exponent '%s'\n",
        yylineno,
        yytext);
}

            /* VALID INTEGERS */

{INT_BINARY} {
    deleteUnderscores(yytext + 2, digitBuffer);
    intBuf = std::stoi(digitBuffer, nullptr, 2);

    printf("INTEGER_LITERAL (binary): %d\n", intBuf);}

{INT_OCTAL} {
    deleteUnderscores(yytext + 2, digitBuffer);
    intBuf = std::stoi(digitBuffer, nullptr, 8);

    printf("INTEGER_LITERAL (octal): %d\n", intBuf);}

{INT_DECIMAL} {
    deleteUnderscores(yytext, digitBuffer);
    intBuf = std::stoi(digitBuffer, nullptr, 10);

    printf("INTEGER_LITERAL (decimal): %d\n", intBuf);}

{INT_HEXADECIMAL} {
    deleteUnderscores(yytext + 2, digitBuffer);
    intBuf = std::stoi(digitBuffer, nullptr, 16);

    printf("INTEGER_LITERAL (hexadecimal): %d\n", intBuf);}

            /* UPPERCASE PREFIX ERRORS */

0B[0-9A-Za-z_]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid binary prefix in '%s'; use '0b'\n",
        yylineno,
        yytext);
}

0O[0-9A-Za-z_]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid octal prefix in '%s'; use '0o'\n",
        yylineno,
        yytext);
}

0X[0-9A-Za-z_]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid hexadecimal prefix in '%s'; use '0x'\n",
        yylineno,
        yytext);
}

             /* INVALID BASED INTEGERS */

0b[0-9A-Za-z_]* { /* todo спросить, корректные ли проверки на ошибки и в правильном ли месте */
    fprintf(stderr,
        "Lexer error at line %d: invalid binary literal '%s'\n",
         yylineno,
         yytext
    );
}

0o[0-9A-Za-z_]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid octal literal '%s'\n",
        yylineno,
        yytext);
}

0x[0-9A-Za-z_]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid hexadecimal literal '%s'\n",
        yylineno,
        yytext);
}

            /* NUMBER FOLLOWED BY IDENTIFIER */

{DECIMAL_DIGITS}[A-Za-z_][A-Za-z_0-9]* {
    fprintf(stderr,
        "Lexer error at line %d: invalid decimal literal '%s'\n",
        yylineno,
        yytext);
}

        /* STRINGS */

        /* MULTILINE STRINGS */

\"\"\" {
    beginString(0, true);
    yy_push_state(MULTILINE_STRING);
}

<MULTILINE_STRING>^[ \t]*\"\"\" {
        // отступ перед закрытием строки """
    std::string indentation(yytext, yyleng - 3);
    printMultilineString("MULTILINE_STRING", indentation);
    endString();
    yy_pop_state();
}

<MULTILINE_STRING>\"\"\" {
    checkMultilineContentStart();
    fprintf(stderr,
        "Lexer error at line %d: closing multiline string delimiter must begin on a new line\n",
        yylineno);
    stringInvalid = true;
    buffer.append(yytext);
}

    /* продолжение строки через / и перенос строки */
<MULTILINE_STRING>\\[ \t]*\r\n|\\[ \t]*\r|\\[ \t]*\n {
    checkMultilineContentStart();
}

<MULTILINE_STRING>\\n         { checkMultilineContentStart(); buffer.append("\n"); }
<MULTILINE_STRING>\\t         { checkMultilineContentStart(); buffer.append("\t"); }
<MULTILINE_STRING>\\\\        { checkMultilineContentStart(); buffer.append("\\"); }
<MULTILINE_STRING>\\\"        { checkMultilineContentStart(); buffer.append("\""); }
<MULTILINE_STRING>\\0         { checkMultilineContentStart(); buffer.append("\0"); }
<MULTILINE_STRING>\\r         { checkMultilineContentStart(); buffer.append("\r"); }
<MULTILINE_STRING>\\'         { checkMultilineContentStart(); buffer.append("'"); }

<MULTILINE_STRING>\\\( {
    checkMultilineContentStart();
    if (!stringInvalid && !buffer.get().empty()) {
        printf("MULTILINE_STRING: %s\n", buffer.get().c_str());
    }

    buffer.reset(yylineno);
    printf("INTERPOLATION_START: %s\n", yytext);
    interpolationDepths.push_back(1);
    yy_push_state(INTERPOLATION);
}

<MULTILINE_STRING>\\. {
    checkMultilineContentStart();
    fprintf(stderr,
        "Lexer error at line %d: invalid escape sequence '%s'\n",
        yylineno,
        yytext);
    stringInvalid = true;
}

<MULTILINE_STRING>[^\\\"\r\n]+ {
    checkMultilineContentStart();
    buffer.append(yytext);
}
<MULTILINE_STRING>\" { checkMultilineContentStart(); buffer.append("\""); }

<MULTILINE_STRING>\r\n|\r|\n {
    appendMultilineNewline();
}

<MULTILINE_STRING><<EOF>> {
    fprintf(stderr,
        "Lexer error at line %d: unterminated multiline string literal\n",
        buffer.getStartLine());
    clearStringContexts();
    return 0;
}

        /* RAW MULTILINE STRINGS */

#+\"\"\" {
    beginString(yyleng - 3, true);
    yy_push_state(RAW_MULTILINE_STRING);
}

<RAW_MULTILINE_STRING>^[ \t]*\"\"\"#+ {
    int hashCount = countClosingHashes(yytext, yyleng);

    if (hashCount == rawDelimiterLength) {
        std::string indentation(yytext, yyleng - 3 - rawDelimiterLength);
        printMultilineString("RAW_MULTILINE_STRING", indentation);
        endString();
        yy_pop_state();
    }
    else if (hashCount < rawDelimiterLength) {
        checkMultilineContentStart();
        buffer.append(yytext);
    }
    else {
        checkMultilineContentStart();
        fprintf(stderr,
            "Lexer error at line %d: too many '#' characters in closing delimiter\n",
            yylineno);
        stringInvalid = true;
        buffer.append(yytext);
    }
}

<RAW_MULTILINE_STRING>\"\"\"#+ {
    int hashCount = countClosingHashes(yytext, yyleng);

    checkMultilineContentStart();
    if (hashCount == rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: closing multiline string delimiter must begin on a new line\n",
            yylineno);
        stringInvalid = true;
    }
    buffer.append(yytext);
}

    /* продолжение строки через / и перенос строки */
<RAW_MULTILINE_STRING>\\#+[ \t]*\r\n|\\#+[ \t]*\r|\\#+[ \t]*\n {
    int hashCount = countHashes(yytext, yyleng, 1);

    checkMultilineContentStart();
    if (hashCount == rawDelimiterLength) {
    }
    else if (hashCount > rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string escape sequence '%s'\n",
            yylineno,
            yytext);
        stringInvalid = true;
    }
    else {
        appendMultilineText(yytext);
    }
}

<RAW_MULTILINE_STRING>\\#+\( {
    int hashCount = countHashes(yytext, yyleng, 1);

    checkMultilineContentStart();
    if (hashCount < rawDelimiterLength) {
        buffer.append(yytext);
    }
    else if (hashCount > rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string interpolation escape '%s'\n",
            yylineno,
            yytext);
        stringInvalid = true;
    }
    else {
        if (!stringInvalid && !buffer.get().empty()) {
            printf("RAW_MULTILINE_STRING: %s\n", buffer.get().c_str());
        }

        buffer.reset(yylineno);
        printf("INTERPOLATION_START: %s\n", yytext);
        interpolationDepths.push_back(1);
        yy_push_state(INTERPOLATION);
    }
}

<RAW_MULTILINE_STRING>\\#+n     { checkMultilineContentStart(); appendRawStringEscape("\n"); }
<RAW_MULTILINE_STRING>\\#+t     { checkMultilineContentStart(); appendRawStringEscape("\t"); }
<RAW_MULTILINE_STRING>\\#+r     { checkMultilineContentStart(); appendRawStringEscape("\r"); }
<RAW_MULTILINE_STRING>\\#+0     { checkMultilineContentStart(); appendRawStringEscape("\0"); }
<RAW_MULTILINE_STRING>\\#+\\    { checkMultilineContentStart(); appendRawStringEscape("\\"); }
<RAW_MULTILINE_STRING>\\#+\"    { checkMultilineContentStart(); appendRawStringEscape("\""); }
<RAW_MULTILINE_STRING>\\#+\'    { checkMultilineContentStart(); appendRawStringEscape("'"); }

<RAW_MULTILINE_STRING>\\#+. {
    int hashCount = countHashes(yytext, yyleng, 1);

    checkMultilineContentStart();
    if (hashCount >= rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string escape sequence '%s'\n",
            yylineno,
            yytext);
        stringInvalid = true;
    }
    else {
        buffer.append(yytext);
    }
}

<RAW_MULTILINE_STRING>\"\"\"        { checkMultilineContentStart(); buffer.append(yytext); }
<RAW_MULTILINE_STRING>\"            { checkMultilineContentStart(); buffer.append("\""); }
<RAW_MULTILINE_STRING>[^\"\\\r\n]+  { checkMultilineContentStart(); buffer.append(yytext); }
<RAW_MULTILINE_STRING>\\            { checkMultilineContentStart(); buffer.append("\\"); }

<RAW_MULTILINE_STRING>\r\n|\r|\n {
    appendMultilineNewline();
}

<RAW_MULTILINE_STRING><<EOF>> {
    fprintf(stderr,
        "Lexer error at line %d: unterminated raw multiline string literal\n",
        buffer.getStartLine());
    clearStringContexts();
    return 0;
}

\" {
    beginString(0, false);
    yy_push_state(STRING);
}

    /* escape последовательности */

<STRING>\\n         { buffer.append("\n"); }
<STRING>\\t         { buffer.append("\t"); }
<STRING>\\\\        { buffer.append("\\"); }
<STRING>\\\"        { buffer.append("\""); }
<STRING>\\0         { buffer.append("\0"); }
<STRING>\\r         { buffer.append("\r"); }
<STRING>\\'         { buffer.append("'"); }

    /* интерполяция */

<STRING>\\\( {
    if (!stringInvalid && !buffer.get().empty()) {
        printf("STRING: %s\n", buffer.get().c_str());
    }

    buffer.reset(yylineno);

    printf("INTERPOLATION_START: \\(\n");
    interpolationDepths.push_back(1);
    yy_push_state(INTERPOLATION);
}

<INTERPOLATION>"(" {
    ++interpolationDepths.back();
    printf("PUNCTUATION: (\n");
}

<INTERPOLATION>")" {
    --interpolationDepths.back();

    if (interpolationDepths.back() == 0) {
        printf("INTERPOLATION_END: )\n");

        interpolationDepths.pop_back(); //конец текущей интерполяции

        yy_pop_state(); //возврат в строку из которой вошли
    } else {
        printf("PUNCTUATION: )\n");
    }
}

<INTERPOLATION>\r\n|\r|\n {
    fprintf(stderr,
        "Lexer error at line %d: newline is not allowed in string interpolation\n",
        yylineno);

    clearStringContexts();
    return 0;
}

<INTERPOLATION><<EOF>> {
    fprintf(stderr,
        "Lexer error at line %d: unterminated string interpolation\n",
        yylineno);

    interpolationDepths.clear();
    return 0; //по хорошему стоит везде на еофах так сделать
}

    /* ошибочная escape */
<STRING>\\. {
    fprintf(stderr,
        "Lexer error at line %d: invalid escape sequence '%s'\n",
        yylineno,
        yytext);

    stringInvalid = true;
}

<STRING>[^\\\"\n]+  { buffer.append(yytext); }

<STRING>\" {
    if (!stringInvalid && !buffer.get().empty()) {
        printf("STRING: %s\n", buffer.get().c_str());
    }
    endString();
    yy_pop_state();
}

    /* перевод строки - строка не закрыта */
<STRING>\n {
    fprintf(stderr,
            "Lexer error at line %d: unterminated string literal\n",
            buffer.getStartLine());

    stringInvalid = true;
    endString();
    yy_pop_state();
}
    /* конец файла внутри строки */
<STRING><<EOF>> {
    fprintf(stderr,
            "Lexer error at line %d: unterminated string literal\n",
            buffer.getStartLine());

    clearStringContexts();
    return 0;
}

        /* RAW STRINGS */

            /* открытие строки */

#+\" {
    beginString(yyleng - 1, false);

    yy_push_state(RAW_STRING);
}

            /* интерполяция в raw строках
               если # меньше чем надо, то считается за обычный текст
               если # больше чем надо, - некорректный ескейп (ошибка)
            */

<RAW_STRING>\\#+\( {
    int hashCount = countHashes(yytext, yyleng, 1);

    if (hashCount < rawDelimiterLength) {
        buffer.append(yytext);
    }
    else if (hashCount > rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string interpolation escape '%s'\n",
            yylineno,
            yytext);

        stringInvalid = true;
    }
    else {
        if (!stringInvalid && !buffer.get().empty()) {
            printf("RAW_STRING: %s\n", buffer.get().c_str());
        }

        buffer.reset(yylineno);
        printf("INTERPOLATION_START: %s\n", yytext);
        interpolationDepths.push_back(1);
        yy_push_state(INTERPOLATION);
    }
}

            /* ескейп последовательности */

<RAW_STRING>\\#+n {
    appendRawStringEscape("\n");
}

<RAW_STRING>\\#+t {
    appendRawStringEscape("\t");
}

<RAW_STRING>\\#+r {
    appendRawStringEscape("\r");
}

<RAW_STRING>\\#+0 {
    appendRawStringEscape("\0");
}

<RAW_STRING>\\#+\\ {
    appendRawStringEscape("\\");
}

<RAW_STRING>\\#+\" {
    appendRawStringEscape("\"");
}

<RAW_STRING>\\#+\' {
    appendRawStringEscape("'");
}

<RAW_STRING>\\#+. {
    int hashCount = countHashes(yytext, yyleng, 1);

    if (hashCount >= rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string escape sequence '%s'\n",
            yylineno,
            yytext);

        stringInvalid = true;
    }
    else {
        buffer.append(yytext);
    }
}

            /* закрытие строки
               если # меньше чем при открытии строки - считается обычным текстом
               (продолжением строки)
            */

<RAW_STRING>\"#+ {
    int hashCount = countHashes(yytext, yyleng, 1);

    if (hashCount == rawDelimiterLength) {

        if (!stringInvalid && !buffer.get().empty()) {
            printf("RAW_STRING: %s\n", buffer.get().c_str());
        }

        endString();

        yy_pop_state();
    }
    else if (hashCount < rawDelimiterLength) {
        buffer.append(yytext);
    }
    else {
        fprintf(stderr,
            "Lexer error at line %d: too many '#' characters in closing delimiter\n",
            yylineno);

        stringInvalid = true;
        buffer.append(yytext);
    }
}


<RAW_STRING>\" {
    buffer.append("\"");
}
<RAW_STRING>[^\"\\\r\n]+ {
    buffer.append(yytext);
}
<RAW_STRING>\\ {
    buffer.append("\\");
}

<RAW_STRING><<EOF>> {
    fprintf(stderr,
            "Lexer error at line %d: unterminated raw string literal\n",
            buffer.getStartLine());

    clearStringContexts();
    return 0;
}

        /* COMMENTS */

"//"[^\n]* {
    printf("WHITESPACE\n"); //swift считает комментарии пробельными разделителями
}

"/*"{OPERATOR}? {
    yyless(2);
    printf("WHITESPACE\n");
    commentDepth = 1;
    yy_push_state(COMMENT);
}
<COMMENT>"/*" {
    commentDepth++;
}
<COMMENT>"*/" {
    commentDepth--;
    if(commentDepth == 0) {
        yy_pop_state();
    }
}
<COMMENT>"\n" {
    printf("NEWLINE\n");
}
<COMMENT>. {
    /* игнорирование символов в комментарии */
}
<COMMENT><<EOF>> {
    fprintf(stderr,
        "Lexer error at line %d: unfinished multiline comment\n",
        yylineno
    );
    BEGIN(INITIAL);
}

    /* последовательность которая могла бы считаться оператором,
    но является зарезервированной под конец комментария. выдаем ошибку */
"*/"{OPERATOR}? {
    yyless(2);
    fprintf(stderr,
        "Lexer error at line %d: unexpected end of block comment\n",
        yylineno
    );
}

        /* OPERATORS */

{DOT_OPERATOR}|{OPERATOR}  {
    for(int i = 1; i + 1 < yyleng; ++i)
    {
        bool opensComment = yytext[i] == '/' &&
                            (yytext[i + 1] == '/' ||
                            yytext[i + 1] == '*');
        bool closesComment = yytext[i] == '*' && yytext[i + 1] == '/';

        if(opensComment || closesComment)
        {
            yyless(i);
            break;
        }
    }

    if(yyleng == 1 && yytext[0] == '.')
    {
        printf("DOT: .\n");
    }
    else
    {
        printf("OPERATOR: %s\n", yytext);
        yy_push_state(AFTER_OPERATOR);
    }
}

            /* operators / punctuation */
            /* пересекающиеся группы */

    /* ошибка на `. `
       ` .` - разрешено */
"."[ \t\r\n] {
    fprintf(stderr,
        "Lexer error at line %d: extraneous whitespace after '.' is not permitted\n",
        yylineno
    );
}

"."    { printf("DOT: .\n"); }
":"    { printf("COLON: :\n"); }

        /* PUNCTUATION */

","   { printf("PUNCTUATION: ,\n"); }

"("   { printf("PUNCTUATION: (\n"); }
")"   { printf("PUNCTUATION: )\n"); }

"{"   { printf("PUNCTUATION: {\n"); }
"}"   { printf("PUNCTUATION: }\n"); }

"["   { printf("PUNCTUATION: [\n"); }
"]"   { printf("PUNCTUATION: ]\n"); }

";"   { printf("PUNCTUATION: ;\n"); }

"@"   { printf("PUNCTUATION: @\n"); }
"#"   { printf("PUNCTUATION: #\n"); }

"`"   { printf("PUNCTUATION: `\n"); }

        /* WHITESPACES */

[ \t\r]+/({OPERATOR}|{DOT_OPERATOR}) { printf("WHITESPACE\n"); }

<AFTER_OPERATOR>[ \t\r]+ {
    /* найден whitespace после оператора */
    yy_pop_state();
    printf("WHITESPACE\n");
}

<AFTER_OPERATOR>\n+ {
    /* найден newline после оператора */
    yy_pop_state();
    printf("NEWLINE\n");
}

<AFTER_OPERATOR>. {
    /* нет whitespace/newline после оператора */
    yy_pop_state();
    yyless(0);
}

[ \t\r]+     ;
\n+           { printf("NEWLINE\n"); }


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

    /* FUNCTIONS */

void deleteUnderscores(const char* source, std::string& str)
{
    str.clear();

    for (const char* p = source; *p != '\0'; ++p)
    {
        if (*p != '_')
        {
            str.push_back(*p);
        }
    }
}

int countHashes(const char* text, int length, int start)
{
    int count = 0;

    while (start < length && text[start] == '#') {
        ++count;
        ++start;
    }

    return count;
}

int countClosingHashes(const char* text, int length)
{
    // подсчет с конца
    int count = 0;

    while (length > 0 && text[length - 1] == '#') {
        ++count;
        --length;
    }

    return count;
}

void appendRawStringEscape(const char* replacement)
{
    int hashCount = countHashes(yytext, yyleng, 1);

    if (hashCount < rawDelimiterLength) {
        buffer.append(yytext);
    }
    else if (hashCount > rawDelimiterLength) {
        fprintf(stderr,
            "Lexer error at line %d: invalid raw string escape sequence '%s'\n",
            yylineno,
            yytext);

        stringInvalid = true;
    }
    else {
        buffer.append(replacement);
    }
}

void checkMultilineContentStart()
{
    if (multilineFirstLine) {
        fprintf(stderr,
            "Lexer error at line %d: multiline string literal content must begin on a new line\n",
            buffer.getStartLine());
        stringInvalid = true;
        multilineFirstLine = false;
    }
}

void appendMultilineNewline()
{
    if (multilineFirstLine) {
        multilineFirstLine = false;
    }
    else {
        buffer.append("\n");
    }
}

void appendMultilineText(const char* text)
{
    std::string normalized;

    for (int i = 0; text[i] != '\0'; i++) {
        if (text[i] == '\r') {
            if (text[i + 1] == '\n') {
                i++;
            }
            normalized.append("\n");
        }
        else {
            normalized.append(1, text[i]);
        }
    }

    buffer.append(normalized);
}

void printMultilineString(const char* tokenType, const std::string& indentation)
{
    bool indentationIsValid = true;
    std::string text = removeMultilineIndentation(buffer.get(), indentation, indentationIsValid);
        // проверка на валидное количество отступов
    if (!indentationIsValid) {
        fprintf(stderr,
            "Lexer error at line %d: multiline string indentation does not match closing delimiter\n",
            buffer.getStartLine());
        stringInvalid = true;
    }

    if (!stringInvalid && !text.empty()) {
        printf("%s: %s\n", tokenType, text.c_str());
    }

    buffer.reset(yylineno);
}

std::string removeMultilineIndentation(const std::string& text, const std::string& indentation, bool& indentationIsValid)
{
    std::string result;
    int lineStart = 0;

    while (lineStart < text.size()) {
        int lineEnd = text.find('\n', lineStart);
        bool hasNewline = lineEnd != std::string::npos;

        if (!hasNewline) {
            lineEnd = text.size();
        }

        std::string line = text.substr(lineStart, lineEnd - lineStart);
        bool isBlank = line.find_first_not_of(" \t") == std::string::npos;

        if (!isBlank) {
            if (line.compare(0, indentation.size(), indentation) != 0) {
                indentationIsValid = false;
            }
            else {
                result.append(line.substr(indentation.size()));
            }
        }

        if (hasNewline) {
            result.append("\n");
            lineStart = lineEnd + 1;
        }
        else {
            break;
        }
    }

    if (!result.empty() && result.back() == '\n') {
        result.pop_back();
    }

    return result;
}

void beginString(int hashCount, bool isMultiline)
{
    // Сначала сохраняем данные предыдущей строки.
    stringContexts.push_back({
        buffer,
        stringInvalid,
        rawDelimiterLength,
        multilineFirstLine
    });

    // Теперь подготавливаем данные новой строки.
    buffer.reset(yylineno);
    stringInvalid = false;
    rawDelimiterLength = hashCount;
    multilineFirstLine = isMultiline;
}

void endString()
{
    bool finishedStringInvalid = stringInvalid;

    StringContext saved = stringContexts.back();
    stringContexts.pop_back();

    buffer = saved.buffer;
    rawDelimiterLength = saved.rawDelimiterLength;
    multilineFirstLine = saved.multilineFirstLine;

    // ошибка внешней строки сохраняется.
    // ошибка вложенной строки также делает внешнюю ошибочной.
    stringInvalid = saved.stringInvalid || finishedStringInvalid;
}

void clearStringContexts()
{
    stringContexts.clear();
    interpolationDepths.clear();

    buffer.reset(yylineno);
    rawDelimiterLength = 0;
    multilineFirstLine = false;
    stringInvalid = false;

    BEGIN(INITIAL);
}
