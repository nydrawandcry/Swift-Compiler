cmake_minimum_required(VERSION 3.20)

project(Swift_Compiler)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(FLEX REQUIRED)
if(NOT FLEX_EXECUTABLE)
    message(FATAL_ERROR "Flex not found. Install Flex and try again.")
endif ()

FLEX_TARGET(
        Lexer
        ${CMAKE_SOURCE_DIR}/lexer/lexer.l
        ${CMAKE_BINARY_DIR}/lexer.cpp
)

add_executable(
        Swift_Compiler
        src/main.cpp
        ${FLEX_Lexer_OUTPUTS}
)
