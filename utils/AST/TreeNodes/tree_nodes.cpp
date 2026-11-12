#include "./tree_nodes.hpp"

#include <cstdint>
#include <iostream>
#include <string>
#include <unordered_set>

namespace
{
    SourceLocation empty_location()
    {
        return {0, 0, 0, 0};
    }

    SourceLocation expression_location(const ast::Expr* expression)
    {
        return expression ? expression->location : empty_location();
    }
}

ast::Expr* create_expr(
    ast::Context& context,
    ast::ExprKind kind,
    TokenValue* token
) {
    ast::Expr* node = context.make(
        kind,
        empty_location(),
        token ? token->text : ""
    );

    if (token) {
        node->value = *token;
    }

    return node;
}

ast::Expr* create_program(
    ast::Context& context,
    ast::Expr* statements
) {
    ast::Expr* program = context.make(
        ast::ExprKind::Program,
        empty_location()
    );

    if (statements) {
        program->children.push_back(statements);
    }

    context.roots.push_back(program);

    return program;
}

ast::Expr* create_statement_list(
    ast::Context& context,
    ast::Expr* statement
) {
    ast::Expr* list = context.make(
        ast::ExprKind::StatementList,
        expression_location(statement)
    );

    if (statement) {
        list->children.push_back(statement);
    }

    return list;
}

ast::Expr* append_statement(
    ast::Context& context,
    ast::Expr* list,
    ast::Expr* statement
) {
    if (!list) {
        return create_statement_list(context, statement);
    }

    if (statement) {
        list->children.push_back(statement);
        list->location = expression_location(statement);
    }

    return list;
}

ast::Expr* create_self_expr(
    ast::Context& context
) {
    return context.make(
        ast::ExprKind::Identifier,
        empty_location(),
        "self"
    );
}

ast::Expr* create_un_expr(
    ast::Context& context,
    ast::ExprKind kind,
    ast::Expr* expression,
    TokenValue* operatorToken
) {
    ast::Expr* node = context.unary(
        kind,
        operatorToken ? operatorToken->text : "",
        expression,
        expression_location(expression)
    );

    if (operatorToken) {
        node->value = *operatorToken;
    }

    return node;
}

ast::Expr* create_infix_expr(
    ast::Context& context,
    ast::Expr* left,
    TokenValue* operatorToken,
    ast::Expr* right
) {
    ast::Expr* operatorNode = create_expr(
        context,
        ast::ExprKind::InfixOperator,
        operatorToken
    );

    if (left && left->kind == ast::ExprKind::Sequence) {
        return context.appendSequence(
            left,
            operatorNode,
            right,
            expression_location(right)
        );
    }

    return context.sequence(
        left,
        operatorNode,
        right,
        expression_location(right)
    );
}

ast::Expr* create_ternary_expr(
    ast::Context& context,
    ast::Expr* condition,
    TokenValue* questionToken,
    ast::Expr* trueExpression,
    ast::Expr* falseExpression
) {
    ast::Expr* questionNode = create_expr(
        context,
        ast::ExprKind::InfixOperator,
        questionToken
    );

    ast::Expr* colonNode = context.make(
        ast::ExprKind::InfixOperator,
        empty_location(),
        ":"
    );

    ast::Expr* result = context.sequence(
        condition,
        questionNode,
        trueExpression,
        expression_location(falseExpression)
    );

    return context.appendSequence(
        result,
        colonNode,
        falseExpression,
        expression_location(falseExpression)
    );
}

ast::Expr* create_group_expr(
    ast::Context& context,
    ast::Expr* expression
) {
    ast::Expr* node = context.make(
        ast::ExprKind::Group,
        expression_location(expression)
    );

    node->children.push_back(expression);
    return node;
}

ast::Expr* create_call_expr(
    ast::Context& context,
    ast::Expr* callee,
    ast::Expr* arguments
) {
    return context.call(
        callee,
        arguments,
        expression_location(callee)
    );
}

ast::Expr* create_argument_list(
    ast::Context& context,
    ast::Expr* argument
) {
    ast::Expr* list = context.make(
        ast::ExprKind::ArgumentList,
        expression_location(argument)
    );

    list->children.push_back(argument);
    return list;
}

ast::Expr* append_argument(
    ast::Context& context,
    ast::Expr* list,
    ast::Expr* argument
) {
    return context.appendArgument(
        list,
        argument,
        expression_location(argument)
    );
}

ast::Expr* create_named_argument(
    ast::Context& context,
    TokenValue* name,
    ast::Expr* expression
) {
    ast::Expr* argument = context.make(
        ast::ExprKind::Argument,
        expression_location(expression),
        name ? name->text : ""
    );

    argument->children.push_back(expression);
    return argument;
}
