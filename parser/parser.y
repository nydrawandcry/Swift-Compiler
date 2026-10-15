%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>

%}


/* -~-~-~-~-~-~-~-~-~-~- KEYWORDS -~-~-~-~-~-~-~-~-~-~- */

    // DECLARATIONS
%token LET VAR FUNC IMPORT
%token STRUCT CLASS ENUM PROTOCOL EXTENSION
%token TYPEALIAS
%token INIT DEINIT SUBSCRIPT ASSOCIATEDTYPE

    // STATEMENTS
%token IF ELSE GUARD
%token FOR IN WHILE REPEAT
%token RETURN BREAK CONTINUE FALLTHROUGH
%token DEFER DO CATCH THROW SWITCH CASE DEFAULT

    // EXPRESSIONS AND TYPES
%token IDENTIFIER
%token TYPE

    // LITERAL KEYWORDS
%token TRUE FALSE NIL
%token SELF SUPER
%token AS IS AWAIT TRY
%token ANY SELF_TYPE

    // KEYWORDS RESERVED IN PARTICULAR CONTEXTS
%token PUBLIC PRIVATE FILEPRIVATE INTERNAL OPEN
%token STATIC FINAL OVERRIDE REQUIRED
%token MUTATING NONMUTATING
%token ASYNC THROWS RETHROWS
%token GET SET WILLSET DIDSET


/* -~-~-~-~-~-~-~-~-~-~- LITERALS -~-~-~-~-~-~-~-~-~-~- */

    // NUMERIC LITERALS
%token INTEGER_LITERAL
%token FLOATING_POINT_LITERAL
%token BOOLEAN_LITERAL
%token NIL_LITERAL

    // STRINGS
%token STRING_LITERAL
%token RAW_STRING_LITERAL
%token MULTILINE_STRING_LITERAL
%token RAW_MULTILINE_STRING_LITERAL

    // операторы и специальные символы
%token DOT COLON NEWLINE

// я в крайнем недоразумении от сложившейся ситуации с операторами...
    /*
       приоритет определяется в зависимости от группы приоритета, к которой
       принадлежит оператор -
       https://developer.apple.com/documentation/swift/operator-declarations
       при этом если операторы в одной группе вроде там еще влияет ассоциативность
       ПРИ ЭТОМ можно еще задавать свои группы приоритетов
       и когда задаешь свой оператор, то можешь указать группу приоритета,
            иначе твой оператор будет принадлежать к дефолтной
    */

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