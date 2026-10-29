#pragma once

#include "../TokenValue.h"

int yylex();
int scanNext();

void resetLexerSupport();
void releaseTokenValues();

int lexerErrorCount();
void lexerError(const char* format, ...);

void markMatch(const char* text, int length);
void rewindMatch(const char* text, int keptLength);

SourceLocation matchLocation();
SourceLocation eofLocation();

SourceLocation spanTo(
    const SourceLocation& start,
    const SourceLocation& end
);

SourceLocation pointAfter(
    const SourceLocation& location
);

void queueToken(
    int kind,
    const std::string& text = ""
);

void queueTokenAt(
    int kind,
    const std::string& text,
    const SourceLocation& location
);

void queueNumber(
    int kind,
    const char* text,
    int length,
    int base
);

void queueOperator(
    int kind,
    const std::string& text,
    OperatorType role,
    const SourceLocation& location
);

bool hasPendingTokens();

const char* tokenName(int kind);
