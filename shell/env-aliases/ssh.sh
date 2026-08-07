# SSH & SCP shortcuts with host aliases
# Hosts stored in ~/.ssh-hosts (persists across sessions)
#
#   host add vayu Nishant@4.252.0.93 ~/Downloads/vayureader.pem
#   host add oracle ubuntu@10.0.0.5
#   host ls
#   host rm oracle
#
#   ssh vayu                     -> connect
#   ssh vayu uptime              -> run command
#   cp vayu file.txt :/srv/      -> upload
#   cp vayu :/srv/data.db .      -> download

_ssh_hosts_file="$HOME/.ssh-hosts"
declare -A _ssh_hosts

_ssh_load_hosts() {
    _ssh_hosts=()
    [[ -f $_ssh_hosts_file ]] || return
    while IFS='|' read -r a t k; do
        [[ -z $a || $a == \#* ]] && continue
        _ssh_hosts[$a]="${t}|${k:--}"
    done < "$_ssh_hosts_file"
}
_ssh_load_hosts

host() {
    case "$1" in
        add)
            [[ -z $2 || -z $3 ]] && { echo "host add <name> <user@host> [key]"; return 1; }
            echo "${2}|${3}|${4:--}" >> "$_ssh_hosts_file"
            _ssh_load_hosts
            echo "Added: $2 -> $3"
            ;;
        rm)
            sed -i "/^${2}|/d" "$_ssh_hosts_file"
            _ssh_load_hosts
            echo "Removed: $2"
            ;;
        ls|"")
            printf "%-12s %-25s %s\n" "NAME" "HOST" "KEY"
            for a in "${(@k)_ssh_hosts}"; do
                local e="${_ssh_hosts[$a]}"
                printf "%-12s %-25s %s\n" "$a" "${e%%|*}" "${e##*|}"
            done
            ;;
    esac
}

ssh() {
    local e="${_ssh_hosts[$1]}"
    [[ -z $e ]] && { command ssh "$@"; return; }
    local t="${e%%|*}" k="${e##*|}"; shift
    local o=(-o ConnectTimeout=10 -o ServerAliveInterval=30)
    [[ $k != "-" ]] && o+=(-i "$k")
    command ssh "${o[@]}" "$t" "$@"
}

cp() {
    local e="${_ssh_hosts[$1]}"
    [[ -z $e ]] && { command cp "$@"; return; }
    local t="${e%%|*}" k="${e##*|}"; shift
    local o=(-o ConnectTimeout=10 -o ServerAliveInterval=30)
    [[ $k != "-" ]] && o+=(-i "$k")
    local a=()
    for arg in "$@"; do
        [[ $arg == :* ]] && a+=("${t}:${arg#:}") || a+=("$arg")
    done
    scp -r "${o[@]}" "${a[@]}"
}
