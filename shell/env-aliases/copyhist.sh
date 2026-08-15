copyhist() {
    local n=${1:-1}

    tmux capture-pane -p |
    awk -v n="$n" '
        /^❯ / { p[++c] = NR }
        { lines[NR] = $0 }
        END {
            if (c <= n) start = 1
            else start = p[c - n]

            for (i = start; i < p[c]; i++)
                print lines[i]
        }
    ' | wl-copy
}
