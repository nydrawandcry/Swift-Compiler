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

namespace
{
    using Precedence = operators::Precedence;

    struct PendingOperator {
        ast::Expr* node;
        Precedence precedence;
    };

    enum class FoldAction {
        Reduce,
        Defer,
        Error
    };

    struct FoldDecision {
        FoldAction action;
        std::string errorMessage;
    };

    // ищем приоритет
    Precedence resolve_infix_precedence(
        const ast::Context& context,
        const ast::Expr* operatorNode
    ) {
        const auto declaration = context.infixOperatorDeclarations.find(operatorNode->text);

        if (declaration != context.infixOperatorDeclarations.end()) {
            return declaration->second;
        }

        return operators::infixPrecedence(operatorNode->text);
    }

    // действие с оператором на вершине стека, когда встречается новый оператор
    FoldDecision evaluate_operator_precedence(
        const PendingOperator& pendingOperator,
        const ast::Expr* currentOperator,
        Precedence currentPrecedence,
        const ast::Expr* rightOperand
    ) {
        const Precedence previousPrecedence = pendingOperator.precedence;

        // после оператора приведения типов справа находится сам тип
        if (rightOperand && rightOperand->kind == ast::ExprKind::TypeName) {
            return {FoldAction::Reduce, {}};
        }

        // у дефолта нет порядка относительно групп выше тернарки
        if ((previousPrecedence == Precedence::Default &&
             currentPrecedence > Precedence::Default) ||
            (currentPrecedence == Precedence::Default &&
             previousPrecedence > Precedence::Default)) {
            return {
                FoldAction::Error,
                "operators '" + pendingOperator.node->text +
                "' and '" + currentOperator->text +
                "' are in unrelated precedence groups; add parentheses"
            };
        }

        if (previousPrecedence < currentPrecedence) {
            return {FoldAction::Defer, {}};
        }

        if (previousPrecedence > currentPrecedence) {
            return {FoldAction::Reduce, {}};
        }

        switch (operators::associativity(currentPrecedence)) {
            case operators::Associativity::Left:
                return {FoldAction::Reduce, {}};

            case operators::Associativity::Right:
                return {FoldAction::Defer, {}};

            case operators::Associativity::None:
                return {
                    FoldAction::Error,
                    "operator '" + currentOperator->text +
                    "' cannot be chained at this precedence without parentheses"
                };
        }

        return {
            FoldAction::Error,
            "internal error: unexpected operator associativity"
        };
    }

    // создание узла для одного оператора
    ast::Expr* build_operator_expr(
        ast::Context& context,
        const ast::Expr* operatorNode,
        ast::Expr* left,
        ast::Expr* right
    ) {
        if (operatorNode->kind == ast::ExprKind::Ternary) {
            return create_ternary_expr(
                context,
                left,
                &operatorNode->text,
                operatorNode->children.front(),
                right
            );
        }

        return create_infix_expr(
            context,
            left,
            &operatorNode->text,
            right
        );
    }

    // сворачиваем один оператор и два соседних операнда
    bool reduce_top_operator(
        ast::Context& context,
        std::vector<ast::Expr*>& operands,
        std::vector<PendingOperator>& pendingOperators,
        std::string& errorMessage
    ) {
        if (pendingOperators.empty() || operands.size() < 2) {
            errorMessage = "invalid state while folding expression";
            return false;
        }

        const ast::Expr* operatorNode = pendingOperators.back().node;
        ast::Expr* left = operands[operands.size() - 2];
        ast::Expr* right = operands.back();
        ast::Expr* expression = build_operator_expr(context, operatorNode, left, right);

        if (!expression) {
            errorMessage = "failed to create expression node";
            return false;
        }

        pendingOperators.pop_back();
        operands.pop_back();
        operands.back() = expression;

        return true;
    }

    // свернуть операторы
    bool reduce_remaining_operators(
        ast::Context& context,
        std::vector<ast::Expr*>& operands,
        std::vector<PendingOperator>& pendingOperators,
        std::string& errorMessage
    ) {
        while (!pendingOperators.empty()) {
            if (!reduce_top_operator(context, operands, pendingOperators, errorMessage)) {
                return false;
            }
        }

        if (operands.size() != 1) {
            errorMessage = "invalid final expression structure";
            return false;
        }

        return true;
    }
}

ast::Expr* fold_expression_sequence(
    ast::Context& context,
    ast::Expr* expression,
    const ast::Expr*& conflictingOperator,
    std::string& errorMessage
) {
    conflictingOperator = nullptr;
    errorMessage.clear();

    if (!expression || expression->kind != ast::ExprKind::Sequence) {
        return expression;
    }


    std::vector<PendingOperator> pendingOperators;
    std::vector<ast::Expr*> operands;

    pendingOperators.reserve(expression->children.size() / 2);
    operands.reserve(expression->children.size() / 2 + 1);
    operands.push_back(expression->children.front());

    // рассматриваем по парам оператор, операнд
    for (std::size_t i = 1; i < expression->children.size(); i += 2) {
        ast::Expr* currentOperator = expression->children[i];
        const Precedence currentPrecedence = resolve_infix_precedence(
            context,
            currentOperator
        );

        while (!pendingOperators.empty()) {
            const FoldDecision decision = evaluate_operator_precedence(
                pendingOperators.back(),
                currentOperator,
                currentPrecedence,
                operands.back()
            );

            if (decision.action == FoldAction::Defer) {
                break;
            }

            if (decision.action == FoldAction::Error) {
                conflictingOperator = currentOperator;
                errorMessage = decision.errorMessage;
                return nullptr;
            }

            if (!reduce_top_operator(
                    context,
                    operands,
                    pendingOperators,
                    errorMessage)) {
                return nullptr;
            }
        }

        pendingOperators.push_back({currentOperator, currentPrecedence});
        operands.push_back(expression->children[i + 1]);
    }

    if (!reduce_remaining_operators(
            context,
            operands,
            pendingOperators,
            errorMessage)) {
        return nullptr;
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
