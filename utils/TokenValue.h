#pragma once

#include <string>

/* Хранение основных данных о токенах */

/*
 * Позиция токена
 */
struct SourceLocation {
    int first_line;
    int first_column;
    int last_line;
    int last_column;
};

/*
 * Все поддерживаемые типы данных токенов
 */
enum class DataType {
    Unknown,

    Int,
    Int8,
    Int16,
    Int32,
    Int64,

    UInt,
    UInt8,
    UInt16,
    UInt32,
    UInt64,

    Float,
    Float80,
    Double,

    Bool,
    String,
    Character
};

/*
 * Тип оператора (если токен - оператор)
 */
enum class OperatorType {
    INFIX,
    PREFIX,
    POSTFIX
};

/*
 * Значение токена (общее)
 */
struct TokenValue {
    std::string text;

    DataType dataType = DataType::Unknown; //для токена с типом

    OperatorType operatorType = OperatorType::INFIX; //для токена - оператора

    unsigned long long integerValue = 0; //для long long и других
    double floatingValue = 0.0; //для float
    int numberBase = 10; //для целых чисел
};
