cmake_minimum_required(VERSION 3.20)

project(Swift_Compiler)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(FLEX REQUIRED)
find_package(BISON 2.7 REQUIRED)

if(NOT FLEX_EXECUTABLE)
    message(FATAL_ERROR "Flex not found. Install Flex and try again.")
endif ()

FLEX_TARGET(
        Lexer
        ${CMAKE_CURRENT_SOURCE_DIR}/lexer/lexer.l
        ${CMAKE_CURRENT_BINARY_DIR}/lexer.cpp
)

BISON_TARGET(
        Parser
        ${CMAKE_CURRENT_SOURCE_DIR}/parser/parser.y
        ${CMAKE_CURRENT_BINARY_DIR}/parser.cpp

        DEFINES_FILE
        ${CMAKE_CURRENT_BINARY_DIR}/parser.hpp

        COMPILE_FLAGS
        "-Wall -v"
)

ADD_FLEX_BISON_DEPENDENCY(Lexer Parser)

add_executable(
        Swift_Compiler
        src/main.cpp
        utils/Buffer/Buffer.cpp
        utils/Buffer/Buffer.h

        ${BISON_Parser_OUTPUTS}
        ${FLEX_Lexer_OUTPUTS}
)

target_include_directories(
        Swift_Compiler
        PRIVATE

        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
)
