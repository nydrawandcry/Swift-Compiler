#pragma once

#include <string>

class Buffer {
public:
    void reset(int line);
    void append(const std::string& text);

    const std::string& get() const;
    int getStartLine() const;

private:
    std::string content;
    int startLine = -1;
};