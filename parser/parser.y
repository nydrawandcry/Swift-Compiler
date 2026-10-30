%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>
  #include "utils/AST/Expr.h"

  ast::Context expressionAST;

  int yylex();
  void yyerror(const char* message);
  int parseErrors = 0;

%}

%code requires {
    #include "utils/TokenValue.h"
    #include "utils/AST/Expr.h"

    #define YYLTYPE SourceLocation
    #define YYLTYPE_IS_DECLARED 1
    #define YYLTYPE_IS_TRIVIAL 1
}

%union {
    TokenValue* token;
    ast::Expr* expr;
}

%locations

%error-verbose
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
//пока не используется
%token <token> UNSUPPORTED_KEYWORD
%token LEX_ERROR

%code provides {
    extern ast::Context expressionAST;
}

%type <expr> expression
%type <expr> sequence_expression
%type <expr> infix_operator

%type <expr> prefix_expression
%type <expr> postfix_expression
%type <expr> primary_expression
%type <expr> literal

%type <expr> argument_list_opt
%type <expr> argument_list
%type <expr> argument

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
    | EQUAL expression_root
    | type_annotation EQUAL expression_root
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
    | expression_root
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
// господи https://docs.swift.org/latest/documentation/the-swift-programming-language/statements/#If-Statement
if_statement:
    IF condition_list code_block else_clause_opt
;

condition_list:
      condition
    | condition_list ',' condition
;

// скобки круглые опциональные (есть в експрешн)
condition:
      expression_root
//    | availability_condition убрала это, тк оно еще не реализовано и вылазиет ошибка
//    | case_condition
    | optional_binding_condition
;

else_clause_opt:
      /* empty */
    | ELSE code_block
    | ELSE if_statement
;

initializer:
    EQUAL expression_root
;

// ----------- условия

// optional_binding_condition - проверяет переменную есть ли в ней значение (не нулл) и помещает значение в переменную если та указана
    // `if let name ...` ИЛИ `if let name = optName ...`
optional_binding_condition:
      LET IDENTIFIER
    | LET IDENTIFIER initializer
    | VAR IDENTIFIER
    | VAR IDENTIFIER initializer
;

// проверка на соответствие с образцом
// (что то типа аналога `==`)
//case_condition:
    /* todo тут я так понимаю надо какие то паттерны реализовывать (добавить правило для них и сюда втулить) */
    /* https://docs.swift.org/latest/documentation/the-swift-programming-language/patterns/ */
//;

// todo availability_condition
// проверка доступности апи для определенной платформы (не знаю может и не надо, у нас вроде лексер не распознает такие слова)
/*
    availability-condition → #available ( availability-arguments )
    availability-condition → #unavailable ( availability-arguments )
    availability-arguments → availability-argument | availability-argument , availability-arguments
    availability-argument → platform-name platform-version
    availability-argument → *

    platform-name → iOS | iOSApplicationExtension
    platform-name → ...
    platform-version → decimal-digits
    platform-version → ...
*/

// -----------------

// while
while_statement:
    WHILE expression_root code_block
;

// for in
for_statement:
    FOR IDENTIFIER IN expression_root code_block
;

// repeat
repeat_while_statement:
    REPEAT code_block WHILE expression_root
;

// return
return_statement:
      RETURN
    | RETURN expression_root
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

// ------------ выражения и AST

//выражение, используемое внешней конструкцией:
//объявлением, условием, ретурном и тд
expression_root:
    expression
;

expression:
      prefix_expression
    | sequence_expression
;

sequence_expression:
      prefix_expression infix_operator prefix_expression
    | sequence_expression infix_operator prefix_expression
;

infix_operator:
      INFIX_OPERATOR
    | EQUAL
;

prefix_expression:
      postfix_expression
    | PREFIX_OPERATOR postfix_expression
;

postfix_expression:
      primary_expression
    | postfix_expression POSTFIX_OPERATOR
    | postfix_expression '(' argument_list_opt ')'
;

primary_expression:
      literal
    | IDENTIFIER
    | TYPE
    | SELF
    | '(' expression ')'
;

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

argument_list_opt:
      /* empty */
    | argument_list
;

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
    ++parseErrors;

    std::cerr
        << "Parser error at "
        << yylloc.first_line
        << ':'
        << yylloc.first_column
        << ": "
        << message
        << '\n';
}