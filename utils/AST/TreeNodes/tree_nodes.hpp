#pragma once

#include "utils/AST/Expr.h"

ast::Expr* create_expr(
    ast::Context& context,
    ast::ExprKind kind,
    TokenValue* token
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
    TokenValue* operatorToken
);

ast::Expr* create_infix_expr(
    ast::Context& context,
    ast::Expr* left,
    TokenValue* operatorToken,
    ast::Expr* right
);

ast::Expr* create_ternary_expr(
    ast::Context& context,
    ast::Expr* condition,
    TokenValue* questionToken,
    ast::Expr* trueExpression,
    ast::Expr* falseExpression
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

ast::Expr* create_named_argument(
    ast::Context& context,
    TokenValue* name,
    ast::Expr* expression
);
