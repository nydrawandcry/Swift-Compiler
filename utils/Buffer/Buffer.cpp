#include "Buffer.h"

void Buffer::reset(int line) {
    content.clear();
    startLine = line;
}

void Buffer::append(const std::string& text) {
    content += text;
}

const std::string& Buffer::get() const {
    return content;
}

int Buffer::getStartLine() const {
    return startLine;
}