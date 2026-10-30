%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>
  #include "utils/LexerSupport.h"

  void yyerror(const char* message);

%}

%code requires {
    #include "utils/TokenValue.h"

    #define YYLTYPE_IS_TRIVIAL 1
}

%union {
    TokenValue* token;
}

%locations

%define api.location.type {SourceLocation}
%define parse.error detailed
%define parse.lac full


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
%token <token> IDENTIFIER
%token <token> TYPE

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
%token <token> INTEGER_LITERAL
%token <token> FLOATING_POINT_LITERAL
%token <token> BOOLEAN_LITERAL
%token <token> NIL_LITERAL

    // STRINGS
%token <token> STRING_LITERAL
%token <token> RAW_STRING_LITERAL
%token <token> MULTILINE_STRING_LITERAL
%token <token> RAW_MULTILINE_STRING_LITERAL
%token <token> INTERPOLATION_START
%token <token> INTERPOLATION_END

    // OPERATORS
%token <token> PREFIX_OPERATOR
%token <token> INFIX_OPERATOR
%token <token> POSTFIX_OPERATOR
%token EQUAL
%token NEWLINE

    // Для конструкций, которые лексер поддерживает, а парсер еще нет
%token <token> UNSUPPORTED_KEYWORD

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

// список объявлений, разрешены несколько разделителей до и после списка
global_decl_list:
    newline_list_opt global_decl_list_core newline_list_opt
;

// разрешается только несколько newline подряд
// до ; обязательно должен быть какой нибудь statement, иначе ошибка
// (следовательно из за этого и несколько ; подряд нельзя)

// при этом разрешается еще такая конструкция, когда между стейтент и ; несколько newline
// let a = 10
//
// ;
global_decl_list_core:
      global_decl
    | global_decl_list_core newline_list global_decl
    | global_decl_list_core newline_list_opt ';' newline_list_opt global_decl
    | global_decl_list_core newline_list_opt ';'
;

newline_list_opt:
      /* empty */
    | newline_list
;

newline_list:
      NEWLINE
    | newline_list NEWLINE
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

// чет типа интерфейса?
// задает всякие свойства и поведение которое реализует "наследник" этого протокола
protocol_declaration:
    PROTOCOL IDENTIFIER '{' declaration_list_opt '}'
;

// расширение какого либо типа
// по сути можно дополнить какой нибудь тип указанными функциями/свойствами
extension_declaration:
    EXTENSION type_identifier '{' declaration_list_opt '}'
;


import_declaration:
    IMPORT import_path
;

import_path:
      IDENTIFIER
    | import_path '.' IDENTIFIER
;

// создание альтернативного имени для существующего типа
typealias_declaration:
    TYPEALIAS IDENTIFIER EQUAL type
;

    // ---------- переменные

// объявление переменной
variable_declaration:
      LET IDENTIFIER variable_tail
    | VAR IDENTIFIER variable_tail
;

// пусто быть не может: либо указывается тип, либо выражение, либо и то и то
variable_tail:
      type_annotation
    | EQUAL expression
    | type_annotation EQUAL expression
;

type_annotation:
    ':' type
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
      IDENTIFIER ':' type
    /* todo там какие то ярлыки еще, `_`, значения по умолчанию и inout */
;

    // ---------- структуры

struct_declaration:
    STRUCT IDENTIFIER '{' declaration_list_opt '}'
;

declaration_list_opt:
      /* empty */
    | declaration_list
;

declaration_list:
      newline_list_opt declaration_list_core newline_list_opt
;

declaration_list_core:
      declaration
    | declaration_list_core newline_list declaration
    | declaration_list_core newline_list_opt ';' newline_list_opt declaration
    | declaration_list_core newline_list_opt ';'
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
      newline_list_opt enum_member_list_core newline_list_opt
;

enum_member_list_core:
      enum_member
    | enum_member_list_core newline_list enum_member
    | enum_member_list_core newline_list_opt ';' newline_list_opt enum_member
    | enum_member_list_core newline_list_opt ';'
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
    | type_identifier '.' IDENTIFIER
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
      newline_list_opt statement_list_core newline_list_opt
;

statement_list_core:
      statement
    | statement_list_core newline_list statement
    | statement_list_core newline_list_opt ';' newline_list_opt statement
    | statement_list_core newline_list_opt ';'
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
    | IDENTIFIER ':' expression
;

%%

//а здесь будет реализация всех функций которые нужны будут в парсере

void yyerror(const char* message) {
    std::cerr
        << "Parser error at "
        << yylloc.first_line
        << ':'
        << yylloc.first_column
        << ": "
        << message
        << '\n';
}