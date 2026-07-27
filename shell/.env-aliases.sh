# ---------------------------------------------------------
# Environment aliases & functions
# ---------------------------------------------------------
# Each alias/function lives in its own file under env-aliases/
# This loader sources them all at shell startup.

_env_aliases_dir="$HOME/.dotfiles/shell/env-aliases"

if [ -d "$_env_aliases_dir" ]; then
    for _alias_file in "$_env_aliases_dir"/*.sh; do
        [ -f "$_alias_file" ] && source "$_alias_file"
    done
fi

unset _env_aliases_dir _alias_file
