#include "LexerSupport.h"
#include "parser.hpp"

#include <cstdarg>
#include <cstdio>
#include <deque>
#include <memory>
#include <utility>
#include <vector>

namespace {

struct PendingToken {
    int kind;
    TokenValue value;
    SourceLocation location;
};

std::deque<PendingToken> pending;

std::vector<std::unique_ptr<TokenValue>> values;

int errors = 0;

int line = 1;
int column = 1;

bool afterCR = false;

SourceLocation matched{};
bool matchedAfterCR = false;

void advance(const char* text, int length) {
    for (int i = 0; i < length; ++i) {
        if (text[i] == '\r') {
            ++line;
            column = 1;
            afterCR = true;
        }
        else if (text[i] == '\n') {
            if (!afterCR) {
                ++line;
            }

            column = 1;
            afterCR = false;
        }
        else {
            ++column;
            afterCR = false;
        }
    }
}

bool carriesValue(int kind) {
    switch (kind) {
        case IDENTIFIER:
        case TYPE:

        case INTEGER_LITERAL:
        case FLOATING_POINT_LITERAL:
        case BOOLEAN_LITERAL:
        case NIL_LITERAL:

        case STRING_LITERAL:
        case RAW_STRING_LITERAL:
        case MULTILINE_STRING_LITERAL:
        case RAW_MULTILINE_STRING_LITERAL:

        case PREFIX_OPERATOR:
        case INFIX_OPERATOR:
        case POSTFIX_OPERATOR:

        case INTERPOLATION_START:
        case INTERPOLATION_END:

        case UNSUPPORTED_KEYWORD:
            return true;

        default:
            return false;
    }
}

DataType typeFromText(const std::string& text) {
    #define TYPE_CASE(name) \
        if (text == #name) return DataType::name;

    TYPE_CASE(Int)
    TYPE_CASE(Int8)
    TYPE_CASE(Int16)
    TYPE_CASE(Int32)
    TYPE_CASE(Int64)

    TYPE_CASE(UInt)
    TYPE_CASE(UInt8)
    TYPE_CASE(UInt16)
    TYPE_CASE(UInt32)
    TYPE_CASE(UInt64)

    TYPE_CASE(Float)
    TYPE_CASE(Float80)
    TYPE_CASE(Double)

    TYPE_CASE(Bool)
    TYPE_CASE(String)
    TYPE_CASE(Character)

    #undef TYPE_CASE

    return DataType::Unknown;
}

} // namespace

void resetLexerSupport() {
    pending.clear();
    values.clear();

    errors = 0;

    line = 1;
    column = 1;
    afterCR = false;

    matched = {1, 1, 1, 1};
    matchedAfterCR = false;
}

void releaseTokenValues() {
    pending.clear();
    values.clear();
}

int lexerErrorCount() {
    return errors;
}

void lexerError(const char* format, ...) {
    ++errors;

    va_list args;
    va_start(args, format);

    std::vfprintf(stderr, format, args);

    va_end(args);
}

void markMatch(const char* text, int length) {
    matched = {line, column, line, column};
    matchedAfterCR = afterCR;

    advance(text, length);

    matched.last_line = line;
    matched.last_column = column;
}

void rewindMatch(const char* text, int keptLength) {
    line = matched.first_line;
    column = matched.first_column;
    afterCR = matchedAfterCR;

    advance(text, keptLength);

    matched.last_line = line;
    matched.last_column = column;
}

SourceLocation matchLocation() {
    return matched;
}

SourceLocation eofLocation() {
    return {line, column, line, column};
}

SourceLocation spanTo(
    const SourceLocation& start,
    const SourceLocation& end
) {
    return {
        start.first_line,
        start.first_column,
        end.last_line,
        end.last_column
    };
}

SourceLocation pointAfter(
    const SourceLocation& location
) {
    return {
        location.last_line,
        location.last_column,
        location.last_line,
        location.last_column
    };
}

void queueTokenAt(
    int kind,
    const std::string& text,
    const SourceLocation& location
) {
    TokenValue value;

    value.text = text;

    if (kind == TYPE) {
        value.dataType = typeFromText(text);
    }

    pending.push_back({
        kind,
        std::move(value),
        location
    });
}

void queueToken(
    int kind,
    const std::string& text
) {
    queueTokenAt(kind, text, matchLocation());
}

void queueNumber(
    int kind,
    const char* text,
    int length,
    int base
) {
    queueTokenAt(
        kind,
        std::string(text, length),
        matchLocation()
    );

    pending.back().value.numberBase = base;
}

void queueOperator(
    int kind,
    const std::string& text,
    OperatorType role,
    const SourceLocation& location
) {
    queueTokenAt(kind, text, location);

    pending.back().value.operatorType = role;
}

bool hasPendingTokens() {
    return !pending.empty();
}

int yylex() {

    if (pending.empty()) {
        scanNext();
    }

    if (pending.empty()) {
        yylval.token = nullptr;
        yylloc = eofLocation();

        return 0;
    }

    PendingToken token = std::move(pending.front());
    pending.pop_front();

    yylloc = token.location;
    yylval.token = nullptr;

    if (carriesValue(token.kind)) {
        auto value = std::make_unique<TokenValue>(
            std::move(token.value)
        );

        yylval.token = value.get();

        values.push_back(std::move(value));
    }

    return token.kind;
}

const char* tokenName(int kind) {
    switch (kind) {
        #define TOKEN_CASE(name) \
            case name: return #name;

        TOKEN_CASE(LET)
        TOKEN_CASE(VAR)
        TOKEN_CASE(FUNC)
        TOKEN_CASE(IMPORT)

        TOKEN_CASE(STRUCT)
        TOKEN_CASE(CLASS)
        TOKEN_CASE(ENUM)
        TOKEN_CASE(PROTOCOL)
        TOKEN_CASE(EXTENSION)
        TOKEN_CASE(TYPEALIAS)

        TOKEN_CASE(IF)
        TOKEN_CASE(ELSE)
        TOKEN_CASE(WHILE)
        TOKEN_CASE(FOR)
        TOKEN_CASE(IN)
        TOKEN_CASE(REPEAT)

        TOKEN_CASE(RETURN)
        TOKEN_CASE(BREAK)
        TOKEN_CASE(CONTINUE)

        TOKEN_CASE(IDENTIFIER)
        TOKEN_CASE(TYPE)

        TOKEN_CASE(INTEGER_LITERAL)
        TOKEN_CASE(FLOATING_POINT_LITERAL)
        TOKEN_CASE(BOOLEAN_LITERAL)
        TOKEN_CASE(NIL_LITERAL)

        TOKEN_CASE(STRING_LITERAL)
        TOKEN_CASE(RAW_STRING_LITERAL)
        TOKEN_CASE(MULTILINE_STRING_LITERAL)
        TOKEN_CASE(RAW_MULTILINE_STRING_LITERAL)

        TOKEN_CASE(PREFIX_OPERATOR)
        TOKEN_CASE(INFIX_OPERATOR)
        TOKEN_CASE(POSTFIX_OPERATOR)

        TOKEN_CASE(ARROW)
        TOKEN_CASE(NEWLINE)

        TOKEN_CASE(INTERPOLATION_START)
        TOKEN_CASE(INTERPOLATION_END)
        TOKEN_CASE(UNSUPPORTED_KEYWORD)

        #undef TOKEN_CASE

        case 0:
            return "EOF";

        default:
            return "TOKEN";
    }
}
