#pragma once

#include "utils/TokenValue.h"

#include <iomanip>
#include <memory>
#include <ostream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace ast
{
    enum class ExprKind {
        Identifier,

        IntegerLiteral,
        FloatingLiteral,
        BooleanLiteral,
        NilLiteral,

        StringLiteral,
        RawStringLiteral,
        MultilineStringLiteral,
        RawMultilineStringLiteral,

        Prefix,
        Postfix,
        Call,

        ArgumentList,
        Argument,

        Group,
        Sequence,
        InfixOperator
    };

    struct Expr {
        ExprKind kind;
        SourceLocation location;

        //имя, текст операции, содержимое аргумента и тд
        std::string text;

        //данные литерала: числовое значение и тд
        TokenValue value;

        std::vector<Expr*> children;
    };

    class Context {
    public:
        //завершённые выражения из объявлений, условий, ретурнов и тд
        std::vector<Expr*> roots;

        Expr* make(
            ExprKind kind,
            SourceLocation location,
            const std::string& text = ""
        ) {
            auto node = std::make_unique<Expr>();

            node->kind = kind;
            node->location = location;
            node->text = text;

            Expr* result = node.get();

            nodes.push_back(std::move(node));

            return result;
        }

        Expr* literal(
            ExprKind kind,
            const TokenValue* token,
            SourceLocation location
        ) {
            Expr* node = make(kind, location, token->text);

            node->value = *token;

            return node;
        }

        Expr* unary(
            ExprKind kind,
            const std::string& text,
            Expr* operand,
            SourceLocation location
        ) {
            Expr* node = make(kind, location, text);

            node->children.push_back(operand);

            return node;
        }

        Expr* call(
            Expr* callee,
            Expr* arguments,
            SourceLocation location
        ) {
            Expr* node = make(ExprKind::Call, location);

            node->children = {callee, arguments};

            return node;
        }

        Expr* sequence(
            Expr* first,
            Expr* op,
            Expr* next,
            SourceLocation location
        ) {
            Expr* node = make(ExprKind::Sequence, location);

            node->children = {first, op, next};

            return node;
        }

        Expr* appendSequence(
            Expr* sequenceNode,
            Expr* op,
            Expr* next,
            SourceLocation location
        ) {
            sequenceNode->children.push_back(op);
            sequenceNode->children.push_back(next);

            sequenceNode->location = location;

            return sequenceNode;
        }

        Expr* appendArgument(
            Expr* list,
            Expr* argument,
            SourceLocation location
        ) {
            list->children.push_back(argument);
            list->location = location;

            return list;
        }

        void clear()
        {
            roots.clear();
            nodes.clear();
        }

    private:
        //владеет памятью всех узлой
        std::vector<std::unique_ptr<Expr>> nodes;
    };

    inline const char* kindName(ExprKind kind)
    {
        switch (kind) {
            case ExprKind::Identifier:
                return "IdentifierExpr";

            case ExprKind::IntegerLiteral:
                return "IntegerLiteralExpr";

            case ExprKind::FloatingLiteral:
                return "FloatingLiteralExpr";

            case ExprKind::BooleanLiteral:
                return "BooleanLiteralExpr";

            case ExprKind::NilLiteral:
                return "NilLiteralExpr";

            case ExprKind::StringLiteral:
                return "StringLiteralExpr";

            case ExprKind::RawStringLiteral:
                return "RawStringLiteralExpr";

            case ExprKind::MultilineStringLiteral:
                return "MultilineStringLiteralExpr";

            case ExprKind::RawMultilineStringLiteral:
                return "RawMultilineStringLiteralExpr";

            case ExprKind::Prefix:
                return "PrefixExpr";

            case ExprKind::Postfix:
                return "PostfixExpr";

            case ExprKind::Call:
                return "CallExpr";

            case ExprKind::ArgumentList:
                return "ArgumentList";

            case ExprKind::Argument:
                return "Argument";

            case ExprKind::Group:
                return "GroupExpr";

            case ExprKind::Sequence:
                return "SequenceExpr";

            case ExprKind::InfixOperator:
                return "InfixOperator";
        }

        return "UnknownExpr";
    }

    inline std::string escaped(const std::string& text) //escape последовательности
    {
        std::ostringstream out;

        for (unsigned char ch : text) {
            switch (ch) {
                case '\\':
                    out << "\\\\";
                    break;

                case '"':
                    out << "\\\"";
                    break;

                case '\n':
                    out << "\\n";
                    break;

                case '\r':
                    out << "\\r";
                    break;

                case '\t':
                    out << "\\t";
                    break;

                case '\0':
                    out << "\\0";
                    break;

                default:
                    if (ch < 32 || ch == 127) {
                        out << "\\x"
                            << std::hex
                            << std::setw(2)
                            << std::setfill('0')
                            << static_cast<unsigned int>(ch);
                    }
                    else {
                        out << static_cast<char>(ch);
                    }
            }
        }

        return out.str();
    }

    inline void print(
        const Expr* node,
        std::ostream& out,
        int indent = 0
    ) {
        if (!node) {
            return;
        }

        out << std::string(indent, ' ')
            << kindName(node->kind);

        const bool isString =
            node->kind == ExprKind::StringLiteral ||
            node->kind == ExprKind::RawStringLiteral ||
            node->kind == ExprKind::MultilineStringLiteral ||
            node->kind == ExprKind::RawMultilineStringLiteral;

        if (!node->text.empty() || isString) {
            out << " \""
                << escaped(node->text)
                << '"';
        }

        out << " @ "
            << node->location.first_line << ':'
            << node->location.first_column << '-'
            << node->location.last_line << ':'
            << node->location.last_column
            << '\n';

        for (const Expr* child : node->children) {
            print(child, out, indent + 2);
        }
    }

    inline void printAll(
        const Context& context,
        std::ostream& out) {
        for (const Expr* root : context.roots) {
            print(root, out);
        }
}
}