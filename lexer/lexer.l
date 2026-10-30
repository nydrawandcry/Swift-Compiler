%option noyywrap
%option never-interactive
%option yylineno
%option stack

%{
#include <stdio.h>
#include <string.h>
#include <string>
#include <vector>
#include <memory>
#include <utility>
#include <cstdarg>
#include <stdexcept>
#include "../utils/Buffer/Buffer.h"
#include "parser.hpp"

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
// структура для хранения оператора и инфы о нем
struct Operator {
    OperatorType type;
    std::string str;
};
// считать начало файла разделителем
static bool prevWhitespace = true;
// был ли разделитель перед текущей лексемой
static bool currentLeftWhitespace = true;
// контекст и текст оператора, ожидающего проверки справа
static bool operatorLeftWhitespace = true;
static int operatorLine = 1;

static Operator currentOperator{OperatorType::INFIX, ""};
//контейнер данных о предыдущих строках
std::vector<StringContext> stringContexts;

// для вывода чисел
std::string digitBuffer = "";

int intBuf = 0;
float floatBuf = 0;
double doubleBuf = 0;

// ДЛЯ ПАРСЕРА И ИХ СВЯЗИ (я пока ничего не понимаю)
static int lexerLine = 1;
static int lexerColumn = 1;

static bool afterCR = false;
static bool matchAfterCR = false;

static SourceLocation currentMatch{1, 1, 1, 1};
//данные токена (хранение до завершения программы)
static std::vector<std::unique_ptr<TokenValue>> tokenValues;
//счетчик ошибок
int lexerErrors = 0;

// ФУНКЦИИ ДЛЯ ПАРСЕРА

//
void lexerError(const char* format, ...);
//
void advancePosition(const char* text, int length);
//
void recordMatch(const char* text, int length);
//
void rewindPosition(const char* text, int length);
//создание данных токена
TokenValue* makeValue(const std::string& text);
//
int finishInput();

//остальные функции

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
// напечатать оператор
void printOperator(bool rightWhitespace, bool followedByDot = false);
//чтение целых чисел (для парсера)
int readInteger(const char* text, int base, int skip);
//чтение чисел с плавающей точкой (для парсера)
int readFloating(const char* text, int base);

// для сохранения и сбрасывания флага перед каждым правилом (для определения типа оператора)
#define YY_USER_ACTION                                      \
    do {                                                    \
        recordMatch(yytext, yyleng);                        \
        yylineno = lexerLine;                               \
        if (YY_START != COMMENT &&                          \
            YY_START != AFTER_OPERATOR) {                   \
            currentLeftWhitespace = prevWhitespace;         \
            prevWhitespace = false;                         \
        }                                                   \
    } while (false);

#define KEEP_MATCHED(count) do {                            \
    yyless(count);                                          \
    rewindPosition(yytext, yyleng);                         \
    yylineno = lexerLine;                                   \
} while (false)
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

"associatedtype"    { return ASSOCIATEDTYPE; }
"borrowing"         { printf("KEYWORD: borrowing\n"); }
"class"             { return CLASS; }
"consuming"         { printf("KEYWORD: consuming\n"); }
"deinit"            { return DEINIT; }
"enum"              { return ENUM; }
"extension"         { return EXTENSION; }
"fileprivate"       { return FILEPRIVATE; }
"func"              { return FUNC; }
"import"            { return IMPORT; }
"init"              { return INIT; }
"inout"             { printf("KEYWORD: inout\n"); }
"internal"          { return INTERNAL; }
"let"               { return LET; }
"nonisolated"       { printf("KEYWORD: nonisolated\n"); }
"open"              { return OPEN; }
"operator"          { printf("KEYWORD: operator\n"); }
"precedencegroup"   { printf("KEYWORD: precedencegroup\n"); }
"private"           { return PRIVATE; }
"protocol"          { return PROTOCOL; }
"public"            { return PUBLIC; }
"rethrows"          { return RETHROWS; }
"static"            { return STATIC; }
"struct"            { return STRUCT; }
"subscript"         { return SUBSCRIPT; }
"typealias"         { return TYPEALIAS; }
"var"               { return VAR; }

            /* STATEMENTS */

"break"             { return BREAK; }
"case"              { return CASE; }
"catch"             { return CATCH; }
"continue"          { return CONTINUE; }
"default"           { return DEFAULT; }
"defer"             { return DEFER; }
"do"                { return DO; }
"else"              { return ELSE; }
"fallthrough"       { return FALLTHROUGH; }
"for"               { return FOR; }
"guard"             { return GUARD; }
"if"                { return IF; }
"in"                { return IN; }
"repeat"            { return REPEAT; }
"return"            { return RETURN; }
"switch"            { return SWITCH; }
"throw"             { return THROW; }
"where"             { printf("KEYWORD: where\n"); }
"while"             { return WHILE; }

            /* EXPRESSIONS AND TYPES */

"Any"               { return ANY; }
"as"                { return AS; }
"await"             { return AWAIT; }
"is"                { return IS; }
"self"              { return SELF; }
"Self"              { return SELF_TYPE; /*разница с обычным self!*/ }
"super"             { return SUPER; }
"throws"            { return THROWS; }
"try"               { return TRY; }

            /* LITERAL KEYWORDS */

"true" {
    yylval.token = makeValue(yytext);

    return BOOLEAN_LITERAL; //в парсере используется такой литерал
}
"false" {
    yylval.token = makeValue(yytext);

    return BOOLEAN_LITERAL;
}
"nil" {
    yylval.token = makeValue(yytext);

    return NIL_LITERAL; //аналогично ( TODO доработать)
}

            /* KEYWORDS USED IN PATTERNS: _ */

_ {
    return '_';
}

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
"async"              { return ASYNC; }
"convenience"        { printf("CONTEXTUAL_KEYWORD: convenience\n"); }
"didSet"             { return DIDSET; }
"dynamic"            { printf("CONTEXTUAL_KEYWORD: dynamic\n"); }
"final"              { return FINAL; }
"get"                { return GET; }
"indirect"           { printf("CONTEXTUAL_KEYWORD: indirect\n"); }
"infix"              { printf("CONTEXTUAL_KEYWORD: infix\n"); }
"lazy"               { printf("CONTEXTUAL_KEYWORD: lazy\n"); }
"left"               { printf("CONTEXTUAL_KEYWORD: left\n"); }
"mutating"           { return MUTATING; }
"none"               { printf("CONTEXTUAL_KEYWORD: none\n"); }
"nonmutating"        { return NONMUTATING; }
"optional"           { printf("CONTEXTUAL_KEYWORD: optional\n"); }
"override"           { return OVERRIDE; }
"package"            { printf("CONTEXTUAL_KEYWORD: package\n"); }
"postfix"            { printf("CONTEXTUAL_KEYWORD: postfix\n"); }
"precedence"         { printf("CONTEXTUAL_KEYWORD: precedence\n"); }
"prefix"             { printf("CONTEXTUAL_KEYWORD: prefix\n"); }
"Protocol"           { printf("CONTEXTUAL_KEYWORD: Protocol\n"); }
"required"           { return REQUIRED; }
"right"              { printf("CONTEXTUAL_KEYWORD: right\n"); }
"set"                { return SET; }
"some"               { printf("CONTEXTUAL_KEYWORD: some\n"); }
"Type"               { printf("CONTEXTUAL_KEYWORD: Type\n"); }
"unowned"            { printf("CONTEXTUAL_KEYWORD: unowned\n"); }
"weak"               { printf("CONTEXTUAL_KEYWORD: weak\n"); }
"willSet"            { return WILLSET; }

        /* TYPES */

Int {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Int;

    return TYPE;
}

Int8 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Int8;

    return TYPE;
}

Int16 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Int16;

    return TYPE;
}

Int32 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Int32;

    return TYPE;
}

Int64 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Int64;

    return TYPE;
}

UInt {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::UInt;

    return TYPE;
}

UInt8 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::UInt8;

    return TYPE;
}

UInt16 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::UInt16;

    return TYPE;
}

UInt32 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::UInt32;

    return TYPE;
}

UInt64 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::UInt64;

    return TYPE;
}

Float {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Float;

    return TYPE;
}

Float80 {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Float80;

    return TYPE;
}

Double {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Double;

    return TYPE;
}

Bool {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Bool;

    return TYPE;
}

String {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::String;

    return TYPE;
}

Character {
    yylval.token = makeValue(yytext);
    yylval.token->dataType = DataType::Character;

    return TYPE;
}

        /* IDENTIFIERS */

[A-Za-z_][A-Za-z_0-9]* { /* todo пока вот так по-простому */
    yylval.token = makeValue(yytext);
    return IDENTIFIER;
}

        /* NUMERIC LITERALS */

            /* VALID FLOATS */

{FLOAT_HEXADECIMAL} {
    return readFloating(yytext, 16);
}

{FLOAT_DECIMAL} {
    return readFloating(yytext, 10);
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
    return readInteger(yytext, 2, 2);
}

{INT_OCTAL} {
    return readInteger(yytext, 8, 2);
}

{INT_DECIMAL} {
    return readInteger(yytext, 10, 0);
}

{INT_HEXADECIMAL} {
    return readInteger(yytext, 16, 2);
}

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
    prevWhitespace = true;
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
        prevWhitespace = true;
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
    prevWhitespace = true;
    yy_push_state(INTERPOLATION);
}

<INTERPOLATION>"(" {
    prevWhitespace = true;

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
    if (!stringInvalid) {
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
        prevWhitespace = true;
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

        if (!stringInvalid) {
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
    prevWhitespace = true; //теперь устанавливаем тут флаг и не выводим whitespace
}

"/*"{OPERATOR}? {
    KEEP_MATCHED(2);
    prevWhitespace = true;
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
    return NEWLINE;
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
    KEEP_MATCHED(2);
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
            KEEP_MATCHED(i);
            break;
        }
    }

    if(yyleng == 1 && yytext[0] == '.')
    {
        return '.';
    }
    else
    {
        currentOperator.str.assign(yytext, yyleng);
        operatorLeftWhitespace = currentLeftWhitespace;
        operatorLine = yylineno;
        //printf("OPERATOR: %s\n", yytext);
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

"."   { return '.'; }
":"   { prevWhitespace = true; return ':'; }

        /* PUNCTUATION */

","   { prevWhitespace = true; return ','; }

"("   { prevWhitespace = true; return '('; }
")"   { return ')'; }

"{"   { prevWhitespace = true; return '{'; }
"}"   { return '}'; }

"["   { prevWhitespace = true; return '['; }
"]"   { return ']'; }

";"   { prevWhitespace = true; return ';'; }

"@"   { return '@'; }
"#"   { return '#'; }

"`"   { return '`'; }

        /* WHITESPACES */

[ \t\r]+/({OPERATOR}|{DOT_OPERATOR}) { prevWhitespace = true; }

<AFTER_OPERATOR>[ \t\r]+ {
    /* найден whitespace после оператора */
    printOperator(true);
    prevWhitespace = true;
    yy_pop_state();
}

<AFTER_OPERATOR>\n+ {
    /* найден newline после оператора */
    printOperator(true);
    yy_pop_state();
    KEEP_MATCHED(0);
}

<AFTER_OPERATOR>("//"|"/*") {
    // комментарий считается whitespace после оператора
    printOperator(true);

    yy_pop_state();
    KEEP_MATCHED(0);
}

<AFTER_OPERATOR>. {
    // пробела справа нет, но возможен разделитель-пунктуация
    const char next = yytext[0];

    const bool rightWhitespace = next == ')' ||
                                 next == ']' ||
                                 next == '}' ||
                                 next == ',' ||
                                 next == ';' ||
                                 next == ':';

    printOperator(rightWhitespace, next == '.');

    yy_pop_state();
    KEEP_MATCHED(0);
}

<AFTER_OPERATOR><<EOF>> {
    // считаем конец файла разделителем справа (тк начало файла - разделитель слева)
    printOperator(true);

    yy_pop_state();
}

[ \t\r]+ { prevWhitespace = true; }

\n+ {
    prevWhitespace = true;
    return NEWLINE;
}


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

void lexerError(const char* format, ...) {
    ++lexerErrors;

    va_list args;
    va_start(args, format);

    std::vfprintf(stderr, format, args);

    va_end(args);
}

void advancePosition(const char* text, int length) {
    for (int i = 0; i < length; ++i) {
        if (text[i] == '\r') {
            ++lexerLine;
            lexerColumn = 1;
            afterCR = true;
        }
        else if (text[i] == '\n') {
            if (!afterCR) {
                ++lexerLine;
            }

            lexerColumn = 1;
            afterCR = false;
        }
        else {
            ++lexerColumn;
            afterCR = false;
        }
    }
}

void recordMatch(const char* text, int length) {
    currentMatch = {
        lexerLine,
        lexerColumn,
        lexerLine,
        lexerColumn
    };

    matchAfterCR = afterCR;

    advancePosition(text, length);

    currentMatch.last_line = lexerLine;
    currentMatch.last_column = lexerColumn;

    yylloc = currentMatch;

    // у нового токена пока нет доп данных
    yylval.token = nullptr;
}

void rewindPosition(const char* text, int length) {
    lexerLine = currentMatch.first_line;
    lexerColumn = currentMatch.first_column;

    afterCR = matchAfterCR;

    advancePosition(text, length);

    currentMatch.last_line = lexerLine;
    currentMatch.last_column = lexerColumn;

    yylloc = currentMatch;
}

TokenValue* makeValue(const std::string& text) {
    auto value = std::make_unique<TokenValue>();

    value->text = text;

    TokenValue* result = value.get();

    tokenValues.push_back(std::move(value));

    return result;
}

int finishInput() {
    yylval.token = nullptr;

    yylloc = {
        lexerLine,
        lexerColumn,
        lexerLine,
        lexerColumn
    };

    return 0;
}

    /* ОСТАЛЬНЫЕ ФУНКЦИИ */

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

    if (!stringInvalid) {
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

void printOperator(bool rightWhitespace, bool followedByDot)
{
    // делаем исключения для одиночных !, ? и следующей вплотную точки
    if (!operatorLeftWhitespace &&
        (currentOperator.str == "!" ||
         currentOperator.str == "?" ||
         followedByDot)) {
        currentOperator.type = OperatorType::POSTFIX;
    }
    else if (operatorLeftWhitespace == rightWhitespace) {
        currentOperator.type = OperatorType::INFIX;
    }
    else if (operatorLeftWhitespace) {
        currentOperator.type = OperatorType::PREFIX;
    }
    else {
        currentOperator.type = OperatorType::POSTFIX;
    }

    // отдельное правило для равно =
    // патамушта присваивание не может быть префиксным или постфиксным
    if (currentOperator.str == "=") {
        if (currentOperator.type != OperatorType::INFIX) {
            fprintf(
                stderr,
                "Lexer error at line %d: '=' cannot be used "
                "as a prefix or postfix operator\n",
                operatorLine
            );

            currentOperator.str.clear();
            return;
        }

        printf("EQUAL: %s\n", currentOperator.str.c_str());
        currentOperator.str.clear();
        return;
    }

    const char* tokenName = "";

    switch (currentOperator.type) {
        case OperatorType::INFIX:
            tokenName = "INFIX_OPERATOR";
            break;

        case OperatorType::PREFIX:
            tokenName = "PREFIX_OPERATOR";
            break;

        case OperatorType::POSTFIX:
            tokenName = "POSTFIX_OPERATOR";
            break;
    }

    printf("%s: %s\n", tokenName, currentOperator.str.c_str());

    currentOperator.str.clear();
}

int readInteger(const char* text, int base, int skip) {
    std::string digits;

    deleteUnderscores(text + skip, digits);

    try {
        unsigned long long value =
            std::stoull(digits, nullptr, base);

        yylval.token = makeValue(text);

        yylval.token->integerValue = value;
        yylval.token->numberBase = base;

        return INTEGER_LITERAL;
    }
    catch (const std::invalid_argument&) {
        lexerError(
            "Lexer error at line %d: invalid integer '%s'\n",
            currentMatch.first_line,
            text
        );
    }
    catch (const std::out_of_range&) {
        lexerError(
            "Lexer error at line %d: integer out of range '%s'\n",
            currentMatch.first_line,
            text
        );
    }

    return LEX_ERROR;
}

int readFloating(const char* text, int base) {
    std::string digits;

    deleteUnderscores(text, digits);

    try {
        double value = std::stod(digits);

        yylval.token = makeValue(text);

        yylval.token->floatingValue = value;
        yylval.token->numberBase = base;

        return FLOATING_POINT_LITERAL;
    }
    catch (const std::invalid_argument&) {
        lexerError(
            "Lexer error at line %d: invalid float '%s'\n",
            currentMatch.first_line,
            text
        );
    }
    catch (const std::out_of_range&) {
        lexerError(
            "Lexer error at line %d: float out of range '%s'\n",
            currentMatch.first_line,
            text
        );
    }

    return LEX_ERROR;
}