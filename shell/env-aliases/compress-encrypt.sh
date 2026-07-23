# Compresses files into 7z
compress-encrypt () {
    if [ "$#" -lt 2 ]; then
        echo "Usage: compress-encrypt <archive-name.7z> <files/directories...>"
        return 1
    fi

    archive="$1"
    shift

    7z a -t7z "$archive" "$@" -mhe=on -p
}
