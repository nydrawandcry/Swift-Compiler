#pragma once

#include <string_view>
#include <unordered_map>
#include <optional>

/**
 * Операторы (построение своей системы операторов и их приоритетов)
 */
namespace operators
{
    /**
     * Старые декларации Бизона в порядке, сохраненным по прежним описаниям
     */
    enum class Precedence {
        Assignment,
        FunctionArrow,
        Ternary,
        Default,
        Unclassified,
        LogicalDisjunction,
        LogicalConjunction,
        Comparison,
        NilCoalescing,
        Casting,
        Range,
        Addition,
        Multiplication,
        BitwiseShift
    };

    /**
     * Ассоциативность
     */
    enum class Associativity { Left, Right, None };

    inline std::optional<Precedence> builtInPrecedenceGroup(std::string_view name)
    {
        using enum Precedence;

        static const std::unordered_map<std::string_view, Precedence> groups = {
            {"AssignmentPrecedence", Assignment},
            {"FunctionArrowPrecedence", FunctionArrow},
            {"TernaryPrecedence", Ternary},
            {"DefaultPrecedence", Default},
            {"LogicalDisjunctionPrecedence", LogicalDisjunction},
            {"LogicalConjunctionPrecedence", LogicalConjunction},
            {"ComparisonPrecedence", Comparison},
            {"NilCoalescingPrecedence", NilCoalescing},
            {"CastingPrecedence", Casting},
            {"RangeFormationPrecedence", Range},
            {"AdditionPrecedence", Addition},
            {"MultiplicationPrecedence", Multiplication},
            {"BitwiseShiftPrecedence", BitwiseShift}
        };

        const auto found = groups.find(name);
        if (found == groups.end()) {
            return std::nullopt;
        }
        return found->second;
    }

    /**
     * Нахождение инфиксной приоритетности у оператора
     * @param spelling
     * @return
     */
    inline Precedence infixPrecedence(std::string_view spelling)
    {
        using enum Precedence;

        static const std::unordered_map<std::string_view, Precedence> precedences = {
            {"=", Assignment}, {"*=", Assignment}, {"&*=", Assignment},
            {"/=", Assignment}, {"%=", Assignment}, {"+=", Assignment},
            {"&+=", Assignment}, {"-=", Assignment}, {"&-=", Assignment},
            {"<<=", Assignment}, {"&<<=", Assignment}, {">>=", Assignment},
            {"&>>=", Assignment}, {"&=", Assignment}, {"^=", Assignment},
            {"|=", Assignment}, {".&=", Assignment}, {".|=", Assignment},
            {".^=", Assignment},
            {"?", Ternary},
            {"||", LogicalDisjunction}, {".|", LogicalDisjunction}, {".^", LogicalDisjunction},
            {"&&", LogicalConjunction}, {".&", LogicalConjunction},
            {"<", Comparison}, {"<=", Comparison}, {">", Comparison}, {">=", Comparison},
            {"==", Comparison}, {"!=", Comparison}, {"===", Comparison}, {"!==", Comparison},
            {"~=", Comparison}, {".<", Comparison}, {".<=", Comparison}, {".>", Comparison},
            {".>=", Comparison}, {".==", Comparison}, {".!=", Comparison},
            {"??", NilCoalescing},
            {"as", Casting}, {"as?", Casting}, {"as!", Casting}, {"is", Casting},
            {"..<", Range}, {"...", Range},
            {"+", Addition}, {"-", Addition}, {"|", Addition}, {"^", Addition},
            {"&+", Addition}, {"&-", Addition},
            {"*", Multiplication}, {"/", Multiplication}, {"%", Multiplication},
            {"&", Multiplication}, {"&*", Multiplication},
            {"<<", BitwiseShift}, {">>", BitwiseShift}, {"&<<", BitwiseShift}, {"&>>", BitwiseShift}
        };

        const auto found = precedences.find(spelling);

        return found != precedences.end() ? found->second : Unclassified;
    }

    /**
     * Определение ассоциативности по приоритету
     * @param precedence приоритет
     * @return ассоциативность
     */
    inline Associativity associativity(Precedence precedence)
    {
        using enum Precedence;
        switch (precedence) {
            case Assignment:
            case FunctionArrow:
            case Ternary:
            case NilCoalescing:
                return Associativity::Right;
            case LogicalDisjunction:
            case LogicalConjunction:
            case Addition:
            case Multiplication:
                return Associativity::Left;
            default:
                return Associativity::None;
        }
    }
}