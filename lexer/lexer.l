%option noyywrap
%option never-interactive
%option yylineno

%{
#include <stdio.h>
#include <string.h>
%}

%x STRING
%x COMMENT

/* todo именованные шаблоны */

%%

/* todo секция правил */

[ \t\r]
\n

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