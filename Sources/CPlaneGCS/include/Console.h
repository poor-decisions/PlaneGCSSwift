#ifndef BASE_H
#define BASE_H

#include <cstdarg>
#include <cstdio>

// Native replacement for the WASM-only Console.h shim in Salusoft89/planegcs
// (which used emscripten's EM_JS to call console.log). This just prints.
class Console
{
public:
    static void Log(const char* format, ...)
    {
        va_list args;
        va_start(args, format);
        vprintf(format, args);
        va_end(args);
    }
};

#endif // BASE_H
