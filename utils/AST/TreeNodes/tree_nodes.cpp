#include "./tree_nodes.hpp"
#include "utils/InfixOperators.h"

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

    std::string dot_id(const ast::Expr* expression)
    {
        return "node_" +
            std::to_string(
                static_cast<std::uintptr_t>(
                    reinterpret_cast<std::uintptr_t>(expression)
                )
            );
    }

    std::string dot_escape(const std::string& text)
    {
        std::string result;

        for (char character : text) {
            switch (character) {
                case '\\':
                    result += "\\\\";
                    break;
                case '"':
                    result += "\\\"";
                    break;
                case '\n':
                    result += "\\n";
                    break;
                case '\r':
                    result += "\\r";
                    break;
                default:
                    result += character;
                    break;
            }
        }

        return result;
    }

    void print_expr_to_dot_impl(
        const ast::Expr* expression,
        std::unordered_set<const ast::Expr*>& printed
    ) {
        if (!expression || !printed.insert(expression).second) {
            return;
        }

        const std::string id = dot_id(expression);
        std::string label = ast::kindName(expression->kind);

        if (!expression->text.empty()) {
            label += "\\n";
            label += expression->text;
        }

        std::cout
            << "  "
            << id
            << " [label=\""
            << dot_escape(label)
            << "\"];\n";

        for (const ast::Expr* child : expression->children) {
            if (!child) {
                continue;
            }

            std::cout
                << "  "
                << id
                << " -> "
                << dot_id(child)
                << ";\n";

            print_expr_to_dot_impl(child, printed);
        }
    }
}

ast::Expr* create_expr(
    ast::Context& context,
    ast::ExprKind kind,
    const std::string* text
) {
    ast::Expr* node = context.make(
        kind,
        empty_location(),
        text ? *text : ""
    );

    return node;
}

ast::Expr* create_variable_declaration(
    ast::Context& context,
    const std::string* name,
    bool isConstant,
    ast::Expr* declaredType,
    ast::Expr* initialValue
) {
    ast::ExprKind kind = ast::ExprKind::VariableDeclaration;

    if (isConstant) {
        kind = ast::ExprKind::ConstantDeclaration;
    }

    ast::Expr* node = context.make(
        kind,
        empty_location(),
        *name
    );

    node->children.push_back(declaredType);
    node->children.push_back(initialValue);

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
    const std::string* operatorText
) {
    ast::Expr* node = context.unary(
        kind,
        operatorText ? *operatorText : "",
        expression,
        expression_location(expression)
    );

    return node;
}

ast::Expr* create_infix_expr(
    ast::Context& context,
    ast::Expr* left,
    const std::string* operatorText,
    ast::Expr* right
) {
    ast::Expr* node = create_expr(
        context,
        ast::ExprKind::InfixOperator,
        operatorText
    );

    node->location = expression_location(left);

    if (right) {
        node->location.last_line = right->location.last_line;
        node->location.last_column = right->location.last_column;
    }

    node->children.push_back(left);
    node->children.push_back(right);

    return node;
}

ast::Expr* create_ternary_expr(
    ast::Context& context,
    ast::Expr* condition,
    const std::string* questionText,
    ast::Expr* trueExpression,
    ast::Expr* falseExpression
) {
    ast::Expr* node = create_expr(
        context,
        ast::ExprKind::Ternary,
        questionText
    );

    node->location = expression_location(condition);

    if (falseExpression) {
        node->location.last_line = falseExpression->location.last_line;
        node->location.last_column = falseExpression->location.last_column;
    }

    node->children.push_back(condition);
    node->children.push_back(trueExpression);
    node->children.push_back(falseExpression);

    return node;
}

//хуятина строит дерево из списка операндов (с корректными приоритетами)
//correct_precedence у гришечки переставлял узлы готового дерева, и делал это не совсем правильно
ast::Expr* fold_expression_sequence(
    ast::Context& context,
    ast::Expr* expression,
    const ast::Expr*& conflictingOperator
) {
    if (expression->kind != ast::ExprKind::Sequence) {
        return expression;
    }

    struct PendingOperator {
        ast::Expr* node;
        operators::Precedence precedence;
    };

    std::vector<PendingOperator> pendingOperators;
    std::vector<ast::Expr*> operands{expression->children.front()};

    const auto reduce = [&] {
        ast::Expr* op = pendingOperators.back().node;
        pendingOperators.pop_back();

        ast::Expr* right = operands.back();
        operands.pop_back();
        ast::Expr* left = operands.back();

        if (op->kind == ast::ExprKind::Ternary) {
            operands.back() = create_ternary_expr(context, left, &op->text, op->children.front(), right);
        } else {
            operands.back() = create_infix_expr(context, left, &op->text, right);
        }
    };

    for (std::size_t i = 1; i < expression->children.size(); i += 2) {
        ast::Expr* op = expression->children[i];
        const auto precedence = operators::infixPrecedence(op->text);

        while (!pendingOperators.empty()) {
            const auto previous = pendingOperators.back().precedence;

            //правый операнд у операции "приведение типа" заканчивается на типе,
                //который "поглощается" грамматикой
            if (previous != operators::Precedence::Casting) {
                if (previous < precedence) {
                    break;
                }
                if (previous == precedence) {
                    const auto associativity = operators::associativity(precedence);
                    if (associativity == operators::Associativity::Right) {
                        break;
                    }
                    if (associativity == operators::Associativity::None) {
                        conflictingOperator = op;
                        return nullptr;
                    }
                }
            }

            reduce();
        }

        pendingOperators.push_back({op, precedence});
        operands.push_back(expression->children[i + 1]);
    }

    while (!pendingOperators.empty()) {
        reduce();
    }

    return operands.back();
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
    const std::string* name,
    ast::Expr* expression
) {
    ast::Expr* argument = context.make(
        ast::ExprKind::Argument,
        expression_location(expression),
        name ? *name : ""
    );

    argument->children.push_back(expression);
    return argument;
}

void global_print_to_dot(
    const ast::Expr* root
) {
    std::cout << "digraph AST {\n";

    std::unordered_set<const ast::Expr*> printed;
    print_expr_to_dot_impl(root, printed);

    std::cout << "}\n";
}

void print_expr_to_dot(
    const ast::Expr* root
) {
    std::unordered_set<const ast::Expr*> printed;
    print_expr_to_dot_impl(root, printed);
}
