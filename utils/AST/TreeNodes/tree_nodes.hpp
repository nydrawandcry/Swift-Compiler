#pragma once

#include "utils/AST/Expr.h"

ast::Expr* create_expr(
    ast::Context& context,
    ast::ExprKind kind,
    const std::string* text
);

ast::Expr* create_program(
    ast::Context& context,
    ast::Expr* statements
);

ast::Expr* create_statement_list(
    ast::Context& context,
    ast::Expr* statement
);

ast::Expr* append_statement(
    ast::Context& context,
    ast::Expr* list,
    ast::Expr* statement
);

ast::Expr* create_self_expr(
    ast::Context& context
);

ast::Expr* create_un_expr(
    ast::Context& context,
    ast::ExprKind kind,
    ast::Expr* expression,
    const std::string* operatorText
);

ast::Expr* create_infix_expr(
    ast::Context& context,
    ast::Expr* left,
    const std::string* operatorText,
    ast::Expr* right
);

ast::Expr* create_ternary_expr(
    ast::Context& context,
    ast::Expr* condition,
    const std::string* questionText,
    ast::Expr* trueExpression,
    ast::Expr* falseExpression
);

ast::Expr* fold_expression_sequence(
    ast::Context& context,
    ast::Expr* expression,
    const ast::Expr*& conflictingOperator
);

ast::Expr* create_group_expr(
    ast::Context& context,
    ast::Expr* expression
);

ast::Expr* create_call_expr(
    ast::Context& context,
    ast::Expr* callee,
    ast::Expr* arguments
);

ast::Expr* create_argument_list(
    ast::Context& context,
    ast::Expr* argument
);

ast::Expr* append_argument(
    ast::Context& context,
    ast::Expr* list,
    ast::Expr* argument
);

ast::Expr* create_variable_declaration(
    ast::Context& context,
    const std::string* name,
    bool isConstant,
    ast::Expr* declaredType,
    ast::Expr* initialValue
);

ast::Expr* create_named_argument(
    ast::Context& context,
    const std::string* name,
    ast::Expr* expression
);

void global_print_to_dot(
    const ast::Expr* root
);

void print_expr_to_dot(
    const ast::Expr* root
);
