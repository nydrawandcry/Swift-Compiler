%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>
  #include "utils/AST/Expr.h"
  #include "utils/AST/tree_nodes.hpp"

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
%token AWAIT TRY
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

    // AssignmentPrecedence: right associative
%right <token>
    EQUAL INFIX_MULT_ASSIGN INFIX_OVERFLOW_MULT_ASSIGN
    INFIX_DIV_ASSIGN INFIX_MOD_ASSIGN INFIX_PLUS_ASSIGN
    INFIX_OVERFLOW_PLUS_ASSIGN INFIX_MINUS_ASSIGN INFIX_OVERFLOW_MINUS_ASSIGN
    INFIX_LSHIFT_ASSIGN INFIX_OVERFLOW_LSHIFT_ASSIGN
    INFIX_RSHIFT_ASSIGN INFIX_OVERFLOW_RSHIFT_ASSIGN
    INFIX_BITWISE_AND_ASSIGN INFIX_BITWISE_XOR_ASSIGN INFIX_BITWISE_OR_ASSIGN
    INFIX_POINTWISE_BITWISE_AND_ASSIGN INFIX_POINTWISE_BITWISE_OR_ASSIGN
    INFIX_POINTWISE_BITWISE_XOR_ASSIGN

    // FunctionArrowPrecedence: right associative
%right <token> ARROW

    // TernaryPrecedence: right associative
%right <token> INFIX_QUESTION

    // DefaultPrecedence: no associativity
%nonassoc <token> INFIX_CUSTOM

    // LogicalDisjunctionPrecedence: left associative
%left <token> INFIX_LOGICAL_OR INFIX_POINTWISE_BITWISE_OR INFIX_POINTWISE_BITWISE_XOR

    // LogicalConjunctionPrecedence: left associative
%left <token> INFIX_LOGICAL_AND INFIX_POINTWISE_BITWISE_AND

    // ComparisonPrecedence: non-associative
%nonassoc <token>
    INFIX_LESS INFIX_LESS_EQUAL INFIX_GREATER INFIX_GREATER_EQUAL
    INFIX_EQUALITY INFIX_INEQUALITY INFIX_IDENTICAL INFIX_NOT_IDENTICAL
    INFIX_PATTERN_MATCH INFIX_POINTWISE_LESS INFIX_POINTWISE_LESS_EQUAL
    INFIX_POINTWISE_GREATER INFIX_POINTWISE_GREATER_EQUAL
    INFIX_POINTWISE_EQUAL INFIX_POINTWISE_NOT_EQUAL

    // NilCoalescingPrecedence: right associative
%right <token> INFIX_NIL_COALESCING

    // CastingPrecedence: AS / IS are keyword tokens
%nonassoc AS IS

    // RangeFormationPrecedence: non-associative
%nonassoc <token> INFIX_HALF_OPEN_RANGE INFIX_CLOSED_RANGE

    // AdditionPrecedence: left associative
%left <token>
    INFIX_PLUS INFIX_MINUS INFIX_BITWISE_OR INFIX_BITWISE_XOR
    INFIX_OVERFLOW_PLUS INFIX_OVERFLOW_MINUS

    // MultiplicationPrecedence: left associative
%left <token> INFIX_MULT INFIX_DIV INFIX_MOD INFIX_BITWISE_AND INFIX_OVERFLOW_MULT

    // BitwiseShiftPrecedence: non-associative
%nonassoc <token> INFIX_LSHIFT INFIX_RSHIFT INFIX_OVERFLOW_LSHIFT INFIX_OVERFLOW_RSHIFT

    // Prefix/postfix forms
%token <token> PREFIX_PLUS PREFIX_MINUS PREFIX_EXCLAMATION PREFIX_BITWISE_NOT
%token <token> PREFIX_BITWISE_AND PREFIX_CLOSED_RANGE PREFIX_HALF_OPEN_RANGE
%token <token> PREFIX_INCREMENT PREFIX_DECREMENT PREFIX_CUSTOM

%token <token> POSTFIX_EXCLAMATION POSTFIX_QUESTION POSTFIX_CLOSED_RANGE
%token <token> POSTFIX_INCREMENT POSTFIX_DECREMENT POSTFIX_CUSTOM

    // специальные символы: '=', '?', '->'
    
%token NEWLINE

    // Для конструкций, которые лексер поддерживает, а парсер еще нет
//пока не используется
%token <token> UNSUPPORTED_KEYWORD
%token LEX_ERROR

%code provides {
    extern ast::Context expressionAST;
}

%type <expr> expression

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
      newline_list_opt
    | newline_list_opt global_decl_list
;

// список объявлений, разрешены несколько разделителей до и после списка
global_decl_list:
      global_decl_list_core
    | global_decl_list_core separator
;

// разрешается только несколько newline подряд
// до ; обязательно должен быть какой нибудь statement, иначе ошибка
// (следовательно из за этого и несколько ; подряд нельзя)

// при этом разрешается еще такая конструкция, когда между стейтент и ; несколько newline
// let a = 10
//
// ;
global_decl_list_core:
      statement
    | global_decl_list_core separator statement
;

newline_list_opt:
      /* empty */
    | newline_list
;

separator:
      newline_list
    | newline_list_opt ';' newline_list_opt
;

newline_list:
      NEWLINE
    | newline_list NEWLINE
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
      newline_list_opt
    | newline_list_opt declaration_list
;

declaration_list:
      declaration_list_core
    | declaration_list_core separator
;

declaration_list_core:
      declaration
    | declaration_list_core separator declaration
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
      newline_list_opt
    | newline_list_opt enum_member_list
;

enum_member_list:
      enum_member_list_core
    | enum_member_list_core separator
;

enum_member_list_core:
      enum_member
    | enum_member_list_core separator enum_member
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
      newline_list_opt
    | newline_list_opt statement_list
;

statement_list:
      statement_list_core
    | statement_list_core separator
;

statement_list_core:
      statement
    | statement_list_core separator statement
;

statement:
      declaration
    | expression
    | if_statement
    | while_statement
    | for_statement
    | repeat_while_statement
    | return_statement
    | BREAK
    | CONTINUE
    | DEFER code_block
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
      expression
//    | availability_condition убрала это, тк оно еще не реализовано и вылазиет ошибка
//    | case_condition
    | optional_binding_condition
;

else_clause_opt:
      /* empty */
    | ELSE code_block
    | ELSE if_statement
;

// ----------- условия

// optional_binding_condition - проверяет переменную есть ли в ней значение (не нулл) и помещает значение в переменную если та указана
    // `if let name ...` ИЛИ `if let name = optName ...`
optional_binding_condition:
      LET IDENTIFIER
    | LET IDENTIFIER EQUAL expression
    | VAR IDENTIFIER
    | VAR IDENTIFIER EQUAL expression
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
//объявлением, условием, ретурном и тд (тут был expression_root : expression)

expression:
      prefix_expression
        { $$ = $1; }
    | expression EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MULT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_MULT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_DIV_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MOD_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_PLUS_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_PLUS_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MINUS_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_MINUS_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LSHIFT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_LSHIFT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_RSHIFT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_RSHIFT_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_AND_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_XOR_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_OR_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_AND_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_OR_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_XOR_ASSIGN expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_QUESTION expression ':' expression %prec INFIX_QUESTION
        { $$ = create_ternary_expr(expressionAST, $1, $2, $3, $5); }
    | expression INFIX_CUSTOM expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LOGICAL_OR expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_OR expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_XOR expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LOGICAL_AND expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_BITWISE_AND expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LESS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LESS_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_GREATER expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_GREATER_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_EQUALITY expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_INEQUALITY expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_IDENTICAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_NOT_IDENTICAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_PATTERN_MATCH expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_LESS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_LESS_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_GREATER expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_GREATER_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_POINTWISE_NOT_EQUAL expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_NIL_COALESCING expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression AS type %prec AS
        { $$ = $1; }
    | expression AS POSTFIX_QUESTION type %prec AS
        { $$ = $1; }
    | expression AS POSTFIX_EXCLAMATION type %prec AS
        { $$ = $1; }
    | expression IS type %prec IS
        { $$ = $1; }
    | expression INFIX_HALF_OPEN_RANGE expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_CLOSED_RANGE expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_PLUS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MINUS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_OR expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_XOR expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_PLUS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_MINUS expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MULT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_DIV expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_MOD expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_BITWISE_AND expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_MULT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_LSHIFT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_RSHIFT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_LSHIFT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
    | expression INFIX_OVERFLOW_RSHIFT expression
        { $$ = create_infix_expr(expressionAST, $1, $2, $3); }
;

prefix_expression:
      postfix_expression
        { $$ = $1; }
    | PREFIX_PLUS postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_MINUS postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_EXCLAMATION postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_BITWISE_NOT postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_BITWISE_AND postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_CLOSED_RANGE postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_HALF_OPEN_RANGE postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_INCREMENT postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_DECREMENT postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
    | PREFIX_CUSTOM postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
;

postfix_expression:
      primary_expression
        { $$ = $1; }
    | postfix_expression POSTFIX_EXCLAMATION
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression POSTFIX_CLOSED_RANGE
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression POSTFIX_QUESTION
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression POSTFIX_INCREMENT
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression POSTFIX_DECREMENT
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression POSTFIX_CUSTOM
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression '(' argument_list_opt ')'
        { $$ = create_call_expr(expressionAST, $1, $3); }
;

primary_expression:
      literal
        { $$ = $1; }
    | IDENTIFIER
        { $$ = create_expr(expressionAST, ast::ExprKind::Identifier, $1); }
    | TYPE
        { $$ = create_expr(expressionAST, ast::ExprKind::Identifier, $1); }
    | SELF
        { $$ = create_self_expr(expressionAST); }
    | '(' expression ')'
        { $$ = create_group_expr(expressionAST, $2); }
;

literal:
      INTEGER_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::IntegerLiteral, $1); }
    | FLOATING_POINT_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::FloatingLiteral, $1); }
    | BOOLEAN_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::BooleanLiteral, $1); }
    | NIL_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::NilLiteral, $1); }
    | STRING_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::StringLiteral, $1); }
    | RAW_STRING_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::RawStringLiteral, $1); }
    | MULTILINE_STRING_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::MultilineStringLiteral, $1); }
    | RAW_MULTILINE_STRING_LITERAL
        { $$ = create_expr(expressionAST, ast::ExprKind::RawMultilineStringLiteral, $1); }
;

argument_list_opt:
      /* empty */
        { $$ = nullptr; }
    | argument_list
        { $$ = $1; }
;

argument_list:
      argument
        { $$ = create_argument_list(expressionAST, $1); }
    | argument_list ',' argument
        { $$ = append_argument(expressionAST, $1, $3); }
;

argument:
      expression
        { $$ = $1; }
    | IDENTIFIER ':' expression
        { $$ = create_named_argument(expressionAST, $1, $3); }
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