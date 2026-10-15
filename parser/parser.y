%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>

%}

// ключевые слова
%token LET VAR

// идентификаторы и типы
%token IDENTIFIER
    /* todo типы добавить */

// литералы
%token INTEGER_LITERAL
%token FLOATING_POINT_LITERAL
%token BOOLEAN_LITERAL
%token NIL_LITERAL

// строковые литералы
%token STRING_LITERAL
%token RAW_STRING_LITERAL
%token MULTILINE_STRING_LITERAL
%token RAW_MULTILINE_STRING_LITERAL

// операторы и специальные символы
%token DOT NEWLINE

// черт пойми что с операторами, потом добавить

%start program

%%

// вся программа
program:
    /* empty */
    | global_decl_list
;

// объявления
global_decl_list:
      global_decl
    | global_decl_list separator global_decl
    | global_decl_list separator
;

separator:
      NEWLINE
    | ';'
;

global_decl:
      variable_declaration
    | expression
    /* todo дополнить */
;

// объявление переменной
variable_declaration:
    /* todo с операторами бы разобраться */
;

// тип переменной
type:
    /* todo */
;

// выражения
expression:
      literal
    | IDENTIFIER
    | IDENTIFIER '(' argument_list_opt ')'
    | '(' expression ')'
    /* todo добавить с операторами */
;

// литералы
literal:
      INTEGER_LITERAL
    | FLOATING_POINT_LITERAL
    | BOOLEAN_LITERAL
    | NIL_LITERAL
    | STRING_LITERAL
    | RAW_STRING_LITERAL
    | MULTILINE_STRING_LITERAL
    | RAW_MULTILINE_STRING_LITERAL
;

// опциональный список аргументов функции
argument_list_opt:
      /* empty */
    | argument_list
;

// список аргументов функции
argument_list:
      expression
    | argument_list ',' expression
;

%%

//а здесь будет реализация всех функций которые нужны будут в парсере