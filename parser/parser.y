%{

//тут все обьявления
  #include <stdio.h>
  #include <stdlib.h>
  #include <iostream>
  #include <utility>
  #include "utils/AST/Expr.h"
  #include "utils/AST/TreeNodes/tree_nodes.hpp"

  ast::Context expressionAST;

  int yylex();
  void yyerror(const char* message);
  int parseErrors = 0;

   static void report_parse_error(SourceLocation location, const char* message);

   static ast::Expr* create_cast_operator(const char* spelling, SourceLocation location)
   {
        const std::string text{spelling};
        return expressionAST.literal(ast::ExprKind::InfixOperator, &text, location);
   }

%}

%code requires {
    #include "utils/AST/Expr.h"

    #define YYLTYPE SourceLocation
    #define YYLTYPE_IS_DECLARED 1
    #define YYLTYPE_IS_TRIVIAL 1
}

%union {
    std::string* text;
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
%token <text> IDENTIFIER
%token <text> TYPE

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
%token <text> INTEGER_LITERAL
%token <text> FLOATING_POINT_LITERAL
%token <text> BOOLEAN_LITERAL
%token <text> NIL_LITERAL

    // STRINGS
%token <text> STRING_LITERAL
%token <text> RAW_STRING_LITERAL
%token <text> MULTILINE_STRING_LITERAL
%token <text> RAW_MULTILINE_STRING_LITERAL

    // OPERATORS

%token <text> INFIX_OPERATOR PREFIX_OPERATOR POSTFIX_OPERATOR
%token <text> EQUAL ARROW INFIX_QUESTION POSTFIX_QUESTION POSTFIX_EXCLAMATION
%token AS IS
    
%token NEWLINE

%token LEX_ERROR

%code provides {
    extern ast::Context expressionAST;
    bool fold_pending_expressions();
}

%type <expr> expression sequence_expression ternary_operator cast_operator
%type <text> infix_operator postfix_operator

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

%type <expr> program
%type <expr> global_decl_list
%type <expr> global_decl_list_core
%type <expr> statement

%type <expr> declaration
%type <expr> variable_declaration
%type <expr> type_annotation
%type <expr> type
%type <expr> type_identifier

%%

// вся программа
program:
      newline_list_opt
        { $$ = create_program(expressionAST, nullptr); }
    | newline_list_opt global_decl_list
        { $$ = create_program(expressionAST, $2); }
;

// список объявлений, разрешены несколько разделителей до и после списка
global_decl_list:
      global_decl_list_core
        { $$ = $1; }
    | global_decl_list_core separator
        { $$ = $1; }
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
        { $$ = create_statement_list(expressionAST, $1); }
    | global_decl_list_core separator statement
        { $$ = append_statement(expressionAST, $1, $3); }
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
//пока нормально узелок создается для переменной, todo остальное нул птрами - заготовочки
declaration:
      variable_declaration
        { $$ = $1; }
    | function_declaration
        { $$ = nullptr; }
    | struct_declaration
        { $$ = nullptr; }
    | class_declaration
        { $$ = nullptr; }
    | enum_declaration
        { $$ = nullptr; }
    | protocol_declaration
        { $$ = nullptr; }
    | extension_declaration
        { $$ = nullptr; }
    | import_declaration
        { $$ = nullptr; }
    | typealias_declaration
        { $$ = nullptr; }
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
      LET IDENTIFIER type_annotation
        { $$ = create_variable_declaration(expressionAST, $2, true, $3, nullptr); }
    | LET IDENTIFIER EQUAL expression
        { $$ = create_variable_declaration(expressionAST, $2, true, nullptr, $4); }
    | LET IDENTIFIER type_annotation EQUAL expression
        { $$ = create_variable_declaration(expressionAST, $2, true, $3, $5); }
    | VAR IDENTIFIER type_annotation
        { $$ = create_variable_declaration(expressionAST, $2, false, $3, nullptr); }
    | VAR IDENTIFIER EQUAL expression
        { $$ = create_variable_declaration(expressionAST, $2, false, nullptr, $4); }
    | VAR IDENTIFIER type_annotation EQUAL expression
        { $$ = create_variable_declaration(expressionAST, $2, false, $3, $5); }
;

type_annotation:
    ':' type
        { $$ = $2; }
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
        { $$ = $1; }
    // todo массивы и тд и тп
;

type_identifier:
      IDENTIFIER
        { $$ = create_expr(expressionAST, ast::ExprKind::TypeName, $1); }
    | TYPE
        { $$ = create_expr(expressionAST, ast::ExprKind::TypeName, $1); }
    | type_identifier '.' IDENTIFIER
        {
            $$ = $1;
            $$->text += ".";
            $$->text += $3->text;
        }
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

// todo доделать для остальных
statement:
      declaration
        { $$ = $1; }
    | expression
        { $$ = $1; }
    | if_statement
        { $$ = nullptr; }
    | while_statement
        { $$ = nullptr; }
    | for_statement
        { $$ = nullptr; }
    | repeat_while_statement
        { $$ = nullptr; }
    | return_statement
        { $$ = nullptr; }
    | BREAK
        { $$ = nullptr; }
    | CONTINUE
        { $$ = nullptr; }
    | DEFER code_block
        { $$ = nullptr; }
    | do_statement
        { $$ = nullptr; }
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
      sequence_expression
      {
          $$ = $1;
          if($$->kind == ast::ExprKind::Sequence) {
            expressionAST.pendingSequences.push_back($$);
          }
      }
;

sequence_expression:
      prefix_expression
        { $$ = $1; }
    | sequence_expression infix_operator prefix_expression
        {
            auto* op = expressionAST.literal(ast::ExprKind::InfixOperator, $2, @2);
            $$ = expressionAST.appendSequence($1, op, $3, @$);
        }
    | sequence_expression ternary_operator prefix_expression
        { $$ = expressionAST.appendSequence($1, $2, $3, @$); }
    | sequence_expression cast_operator type
        { $$ = expressionAST.appendSequence($1, $2, $3, @$); }
;

infix_operator:
      INFIX_OPERATOR
    | EQUAL
;

ternary_operator:
    INFIX_QUESTION expression ':'
        {
            $$ = expressionAST.literal(ast::ExprKind::Ternary, $1, @1);
            $$->children.push_back($2);
        }
;

cast_operator:
      AS
        { $$ = create_cast_operator("as", @$); }
    | AS POSTFIX_QUESTION
        { $$ = create_cast_operator("as?", @$); }
    | AS POSTFIX_EXCLAMATION
        { $$ = create_cast_operator("as!", @$); }
    | IS
        { $$ = create_cast_operator("is", @$); }
;

prefix_expression:
      postfix_expression
        { $$ = $1; }
    | PREFIX_OPERATOR postfix_expression
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Prefix, $2, $1); }
;

postfix_expression:
      primary_expression
        { $$ = $1; }
    | postfix_expression postfix_operator
        { $$ = create_un_expr(expressionAST, ast::ExprKind::Postfix, $1, $2); }
    | postfix_expression '(' argument_list_opt ')'
        { $$ = create_call_expr(expressionAST, $1, $3); }
;

postfix_operator:
      POSTFIX_OPERATOR
    | POSTFIX_EXCLAMATION
    | POSTFIX_QUESTION
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

static void report_parse_error(SourceLocation location, const char* message)
{
    ++parseErrors;

    std::cerr
        << "Parser error at "
        << location.first_line
        << ':'
        << location.first_column
        << ": "
        << message
        << '\n';
}

void yyerror(const char* message)
{
    report_parse_error(yylloc, message);
}

bool fold_pending_expressions()
{
    for (ast::Expr* sequence : expressionAST.pendingSequences) {
        const ast::Expr* conflictingOperator = nullptr;
        ast::Expr* folded = fold_expression_sequence(expressionAST, sequence, conflictingOperator);

        if (!folded) {
            const std::string message = "operator '" + conflictingOperator->text +
                "' cannot be chained at this precedence without parentheses";
            report_parse_error(conflictingOperator->location, message.c_str());
            return false;
        }

        if (folded != sequence) {
            //кладем готовый узел по тому же адресу где лежала цепочка
            *sequence = std::move(*folded);
        }
    }

    expressionAST.pendingSequences.clear();
    return true;
}