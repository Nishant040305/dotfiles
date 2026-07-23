# C++ extreme compilation for debugging
cpp() {
	# fast = -std=c++23 -O0 -g1
	# best = -std=c++23 -Og -g3 -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC -fsanitize=address,undefined,leak -fno-sanitize-recover=all -fstack-protector-strong -fno-omit-frame-pointer

    if [ "$#" -eq 0 ]; then
        echo "Usage: cpp <file.cpp>"
        return 1
    fi

    g++ -std=c++23 -Og -g3 \
    -Wall -Wextra -Wpedantic \
    -Wshadow -Wconversion -Wsign-conversion \
    -Wfloat-equal -Wduplicated-cond -Wlogical-op \
    -Wuseless-cast -Wformat=2 -Wnull-dereference \
    -Wdouble-promotion -Wimplicit-fallthrough \
    -Wcast-align -Wstrict-overflow=5 \
    -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC \
    -fsanitize=address,undefined,leak \
    -fno-sanitize-recover=all \
    -fstack-protector-strong \
    -fno-omit-frame-pointer \
    -o out "$1" && \
    if [ -f input.txt ]; then
        ./out < input.txt
    else
        ./out
    fi
    rm -f out
}

alias c++=cpp

