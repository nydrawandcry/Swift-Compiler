#pragma once

#include <string_view>
#include <unordered_map>

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
        Ternary,
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