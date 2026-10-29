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

    // OPERATORS
%token PREFIX_OPERATOR
%token INFIX_OPERATOR
%token POSTFIX_OPERATOR
%token EQUAL
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

// объявления (список)
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
      statement
;

// объявление
declaration:
      variable_declaration
    | function_declaration
    | struct_declaration
    | class_declaration
    | enum_declaration
    | protocol_declaration
    | extension_declaration
    | import_declaration
    | typealias_declaration
;

    // ---------- переменные

// объявление переменной
variable_declaration:
      LET IDENTIFIER type_annotation
    | VAR IDENTIFIER type_annotation_opt // opt ли вообще
    /* todo с операторами бы разобраться, присваивание нужно будет дописать */
;

// аннотация типа (опциональная)
type_annotation_opt:
    /* empty */
    | type_annotation
;

type_annotation:
    COLON type
;

    // ---------- функции

// объявление функции
function_declaration:
    FUNC IDENTIFIER '(' parameter_list_opt ')' function_body_opt
    /* todo добавить возвращаемый тип через -> */
;

function_body_opt:
    /* empty */
    | code_block
;

// параметры
parameter_list_opt:
    /* empty */
    | parameter_list
;

parameter_list:
      parameter
    | parameter_list ',' parameter
;

parameter:
      IDENTIFIER COLON type
    /* todo там какие то ярлыки еще, `_`, значения по умолчанию и inout */
;

    // ---------- структуры

struct_declaration:
    STRUCT IDENTIFIER '{' declaration_list_opt '}'
;

    // ---------- классы

class_declaration:
    CLASS IDENTIFIER '{' declaration_list_opt '}'
;

    // ---------- енамы

enum_declaration:
    ENUM IDENTIFIER '{' enum_member_list_opt '}'
;

enum_member_list_opt:
    /* empty */
    | enum_member_list
;

enum_member_list:
      enum_member
    | enum_member_list separator enum_member
    | enum_member_list separator
;

enum_member:
      CASE identifier_list
    | declaration
;

identifier_list:
      IDENTIFIER
    | identifier_list ',' IDENTIFIER
;

        /*   !todo доделать объявления!   */

// тип переменной
type:
      type_identifier
    // todo массивы и тд и тп
;

type_identifier:
      IDENTIFIER
    | TYPE
    | type_identifier DOT IDENTIFIER
;

// блок кода
code_block:
    '{' statement_list_opt '}'
;

statement_list_opt:
    /* empty */
    | statement_list
;

statement_list:
      statement
    | statement_list separator statement
    | statement_list separator
;

statement:
      declaration
    | expression
    | if_statement
    | while_statement
    | for_statement
    | repeat_while_statement
    | return_statement
    | break_statement
    | continue_statement
    | defer_statement
    | do_statement
;

// чем дальше в лес, иф элс иф элс
if_statement:
      IF expression code_block
    | IF expression code_block ELSE code_block
    | IF expression code_block ELSE if_statement
;

// while
while_statement:
    WHILE expression code_block
;

// for in
for_statement:
    FOR IDENTIFIER IN expression code_block
;

// repeat
repeat_while_statement:
    REPEAT code_block WHILE expression
;

// return
return_statement:
      RETURN
    | RETURN expression
;

// break
break_statement:
    BREAK
;

// continue
continue_statement:
    CONTINUE
;

// defer
defer_statement:
    DEFER code_block
;

// do-catch
do_statement:
      DO code_block
    | DO code_block catch_clause
;

catch_clause:
    CATCH code_block
;

// ------------ выражения
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

// ---------- вызов функции
// опциональный список аргументов функции
argument_list_opt:
      /* empty */
    | argument_list
;

// список аргументов функции
argument_list:
      argument
    | argument_list ',' argument
;

argument:
      expression
    | IDENTIFIER COLON expression
;

%%

//а здесь будет реализация всех функций которые нужны будут в парсере