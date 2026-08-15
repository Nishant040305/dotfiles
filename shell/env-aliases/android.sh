android() {
    local shared=false
    local start_app="com.magneticchen.daijishou"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--shared)
                shared=true
                printf "${_CLR_INFO}[android]${_CLR_RESET} Using shared display.\n"
                shift
                ;;

            -a|--app)
                local query=""

                if [[ $# -ge 2 && "$2" != -* ]]; then
                    query="$2"
                    shift 2
                else
                    shift
                fi

                printf "${_CLR_INFO}[android]${_CLR_RESET} App query: ${_CLR_ACCENT}%s${_CLR_RESET}\n" "${query:-<all>}"

                printf "${_CLR_INFO}[android]${_CLR_RESET} Fetching package list...\n"
                local packages
                packages=$(adb shell pm list packages | sed 's/^package://')

                printf "${_CLR_INFO}[android]${_CLR_RESET} Looking for exact package match...\n"
                local match=""

                if [[ -n $query ]]; then
                    match=$(printf '%s\n' "$packages" | grep -Fxi -- "$query")
                fi

                if [[ -n $match ]]; then
                    printf "${_CLR_SUCCESS}[android]${_CLR_RESET} Exact match found: ${_CLR_ACCENT}%s${_CLR_RESET}\n" "$match"
                else
                    if [[ -n $query ]]; then
                        packages=$(printf '%s\n' "$packages" | grep -i -- "$query")
                    fi

                    printf "${_CLR_INFO}[android]${_CLR_RESET} Opening app picker...\n"

                    match=$(
                        printf '%s\n' "$packages" |
                        fzf \
                            --prompt="Launch package> " \
                            ${query:+--query="$query"}
                    )

                    if [[ -z $match ]]; then
                        printf "${_CLR_WARN}[android]${_CLR_RESET} No package selected.\n"
                        return 1
                    fi
                fi

                start_app="$match"
                printf "${_CLR_SUCCESS}[android]${_CLR_RESET} Selected package: ${_CLR_ACCENT}%s${_CLR_RESET}\n" "$start_app"
                ;;

            -h|--help)
                cat <<EOF
Usage: android [OPTIONS]

Launch scrcpy with sensible defaults.

Options:
  -a, --app [query]
        Launch an app.
        If a query is supplied, search for matching package names.
        If omitted, browse all installed packages.

  -s, --shared
        Mirror the physical display instead of creating a virtual display.

  -h, --help
        Show this help.

Examples:
  android
  android --shared
  android --app
  android --app youtube
  android --app com.termux
  android --shared --app chrome
EOF
                return
                ;;

            *)
                printf "${_CLR_ERROR}[android]${_CLR_RESET} Unknown option: ${_CLR_ACCENT}%s${_CLR_RESET}\n" "$1"
                return 1
                ;;
        esac
    done

    printf "${_CLR_INFO}[android]${_CLR_RESET} Listing devices...\n"
    adb devices

    local args=(
        --video-bit-rate=32M
        --max-fps=60
        --keyboard=aoa
        --mouse=uhid
        --render-driver=vulkan
        --turn-screen-off
        --fullscreen
    )

    if ! $shared; then
        printf "${_CLR_INFO}[android]${_CLR_RESET} Using virtual display.\n"
        args+=(
            --flex-display
            --new-display=1920x1080/200
        )
    fi

    args+=(--start-app="$start_app")

    printf "${_CLR_SUCCESS}[android]${_CLR_RESET} Launching ${_CLR_BOLD}scrcpy${_CLR_RESET}:\n"
    printf "${_CLR_DIM}  %q${_CLR_RESET}" scrcpy "${args[@]}"
    printf "\n\n"

    scrcpy "${args[@]}"
}
