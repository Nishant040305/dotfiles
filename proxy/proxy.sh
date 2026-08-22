# Main proxy command dispatcher
proxy() {
    local command="${1:-help}"
    
    case "$command" in
        shell)
            _proxy_shell "$2" "$3"
            ;;
        system)
            _proxy_system "$2" "$3"
            ;;
        redsocks)
            shift
            _proxy_redsocks "$@"
            ;;
        masquerade)
            shift
            _proxy_masquerade "$@"
            ;;
        test)
            _proxy_test
            ;;
        get)
            _proxy_get
            ;;
        help)
            _proxy_help
            ;;
        *)
            _proxy_help
            ;;
    esac
}

# Shell proxy management
_proxy_shell() {
    local subcommand="$1"
    
    case "$subcommand" in
        enable)
            _proxyon
            ;;
        disable)
            _proxyoff
            ;;
        toggle)
            _proxy_shell_toggle "$2"
            ;;
        configure)
            _proxyauto
            ;;
        status)
            _proxy_status
            ;;
        *)
            echo -e "${_CLR_ERROR}Unknown shell subcommand: $subcommand${_CLR_RESET}"
            echo "Usage: proxy shell {enable|disable|toggle|configure|status}"
            return 1
            ;;
    esac
}

# Toggle shell proxy based on current environment variables
_proxy_shell_toggle() {
    local flag="$1"

    if [[ -n "${http_proxy:-}" || -n "${https_proxy:-}" || -n "${HTTP_PROXY:-}" || -n "${HTTPS_PROXY:-}" ]]; then
        _proxyoff "$flag"
    else
        _proxyon "$flag"
    fi
}

# System proxy management
_proxy_system() {
    local subcommand="$1"
    local value="$2"
    
    case "$subcommand" in
        set)
            if [[ -z "$value" ]]; then
                echo -e "${_CLR_ERROR}Usage: proxy system set <IP_SUFFIX>${_CLR_RESET}"
                echo "Example: proxy system set 172 (sets 172.31.x.x)"
                return 1
            fi
            _proxy_system_set "$value"
            ;;
        enable)
            _proxy_system_enable
            ;;
        disable)
            _proxy_system_disable
            ;;
        *)
            echo -e "${_CLR_ERROR}Unknown system subcommand: $subcommand${_CLR_RESET}"
            echo "Usage: proxy system {set <IP>|enable|disable}"
            return 1
            ;;
    esac
}

# Set system proxy with auto-prefixing
_proxy_system_set() {
    local raw="$1"
    local ip dots

    dots=$(grep -o '\.' <<< "$raw" | wc -l)
    case "$dots" in
        3)
            ip="$raw"
            ;;
        2)
            [[ "$raw" == .* ]] || { echo "Invalid IP: $raw"; return 1; }
            ip="172.31${raw}"
            ;;
        1)  
            ip="172.31.$raw"
            ;;
        *)
            echo "Invalid IP format: $raw"
            return 1
            ;;
    esac
    
    local proxy_url="http://edcguest:edcguest@${ip}:3128"

    echo -e "${_CLR_INFO}${_CLR_BOLD}⟳ Setting system proxy${_CLR_RESET} ${_CLR_DIM}to${_CLR_RESET} ${_CLR_ACCENT}$ip${_CLR_RESET}"
    
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key httpProxy "$proxy_url"
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key httpsProxy "$proxy_url"
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ftpProxy "$proxy_url"
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key NoProxyFor "localhost,127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ System proxy${_CLR_RESET} ${_CLR_DIM}configured${_CLR_RESET}"
}

# Set system proxy mode to manual (KDE ProxyType=1)
_proxy_system_enable() {
    echo -e "${_CLR_INFO}${_CLR_BOLD}⟳ Enabling system proxy${_CLR_RESET}"
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 1
    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ System proxy${_CLR_RESET} ${_CLR_DIM}enabled${_CLR_RESET}"
}

# Set system proxy mode to none (KDE ProxyType=0)
_proxy_system_disable() {
    echo -e "${_CLR_INFO}${_CLR_BOLD}⟳ Disabling system proxy${_CLR_RESET}"
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 0
    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ System proxy${_CLR_RESET} ${_CLR_DIM}disabled${_CLR_RESET}"
}

# Enable shell proxy using KDE system settings
_proxyon() {
    # Read proxy URL from KDE kioslaverc
    local proxy_url=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key httpProxy 2>/dev/null)
    
    if [[ -z "$proxy_url" ]]; then
        echo -e "${_CLR_ERROR}No system proxy configured. Use 'proxy system set <IP>' first.${_CLR_RESET}"
        return 1
    fi

    export http_proxy=$proxy_url
    export https_proxy=$proxy_url
    export HTTP_PROXY=$proxy_url
    export HTTPS_PROXY=$proxy_url

    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ Environment${_CLR_RESET} ${_CLR_DIM}proxy set to${_CLR_RESET} ${_CLR_INFO}$proxy_url${_CLR_RESET}"

    # Keep KDE system proxy UI in sync so tray/status match shell toggles
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 1 2>/dev/null || true

    if [[ "$1" == "--local" ]]; then
        return
    fi

    {
        echo "[connectivity]"
        echo "enabled=false"
    } | sudo tee "/etc/NetworkManager/conf.d/20-connectivity.conf" > /dev/null
    sudo systemctl restart NetworkManager

    {
        echo "[main]"
        echo "proxy=$proxy_url"
    } | sudo tee "/etc/dnf/dnf.conf" > /dev/null

    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ System proxy${_CLR_RESET} ${_CLR_DIM}configured${_CLR_RESET} ${_CLR_ACCENT}(NetworkManager, DNF)${_CLR_RESET}"
}

# Disable shell proxy
_proxyoff() {
    unset http_proxy
    unset https_proxy
    unset HTTP_PROXY
    unset HTTPS_PROXY

    # Keep KDE system proxy UI in sync so tray/status match shell toggles
    kwriteconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 0 2>/dev/null || true

    if [[ "$1" == "--local" ]]; then
        return
    fi

    sudo rm -f "/etc/NetworkManager/conf.d/20-connectivity.conf"
    sudo systemctl restart NetworkManager
    
    echo "[main]" | sudo tee "/etc/dnf/dnf.conf" > /dev/null

    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ System proxy${_CLR_RESET} ${_CLR_DIM}removed${_CLR_RESET} ${_CLR_ACCENT}(NetworkManager, DNF)${_CLR_RESET}"
}

# Check proxy status across all layers
_proxy_status() {
    local has_issue=0

    # 1. Shell environment
    if [[ -n "$http_proxy" || -n "$https_proxy" ]]; then
        echo -e "${_CLR_SUCCESS}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}Shell proxy:${_CLR_RESET}    ${_CLR_SUCCESS}${_CLR_BOLD}ENABLED${_CLR_RESET}  ${_CLR_DIM}(${http_proxy:-$https_proxy})${_CLR_RESET}"
    else
        echo -e "${_CLR_ERROR}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}Shell proxy:${_CLR_RESET}    ${_CLR_ERROR}${_CLR_BOLD}DISABLED${_CLR_RESET}"
        has_issue=1
    fi

    # 2. KDE system proxy
    local kde_type=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 2>/dev/null)
    if [[ "$kde_type" == "1" ]]; then
        local kde_proxy=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key httpProxy 2>/dev/null)
        echo -e "${_CLR_SUCCESS}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}System proxy:${_CLR_RESET}   ${_CLR_SUCCESS}${_CLR_BOLD}ENABLED${_CLR_RESET}  ${_CLR_DIM}(${kde_proxy})${_CLR_RESET}"
    else
        echo -e "${_CLR_ERROR}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}System proxy:${_CLR_RESET}   ${_CLR_ERROR}${_CLR_BOLD}DISABLED${_CLR_RESET}"
        has_issue=1
    fi

    # 3. Redsocks
    if systemctl is-active --quiet redsocks 2>/dev/null; then
        echo -e "${_CLR_SUCCESS}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}Redsocks:${_CLR_RESET}       ${_CLR_SUCCESS}${_CLR_BOLD}ENABLED${_CLR_RESET}"
    else
        echo -e "${_CLR_ERROR}${_CLR_BOLD}●${_CLR_RESET} ${_CLR_DIM}Redsocks:${_CLR_RESET}       ${_CLR_ERROR}${_CLR_BOLD}DISABLED${_CLR_RESET}"
    fi

    return $has_issue
}

# Toggle shell proxy based on KDE system settings
_proxyauto() {
    local kde_type=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 2>/dev/null)

    if [[ "$kde_type" == "1" ]]; then
        _proxyon --local
    else
        _proxyoff --local
    fi
}

# Redsocks transparent proxy redirection using system proxy host
_proxy_redsocks() {
  local command="$1"
  local ip="$2"
  
  case "$command" in
    enable)
      if [[ -n "$ip" ]]; then
        pkexec /usr/local/sbin/proxyredsocks enable "$ip"
      else
        pkexec /usr/local/sbin/proxyredsocks enable
      fi
      ;;
    disable)
      pkexec /usr/local/sbin/proxyredsocks disable
      ;;
    toggle)
      if systemctl is-active --quiet redsocks 2>/dev/null || \
         sudo -n iptables -t nat -L REDSOCKS -n 2>/dev/null | grep -q REDIRECT 2>/dev/null; then
        pkexec /usr/local/sbin/proxyredsocks disable
        return $?
      fi

      if [[ -n "$ip" ]]; then
        pkexec /usr/local/sbin/proxyredsocks enable "$ip"
      else
        pkexec /usr/local/sbin/proxyredsocks enable
      fi
      ;;
    status)
      pkexec /usr/local/sbin/proxyredsocks status
      ;;
    *)
      echo -e "${_CLR_ERROR}Usage: proxy redsocks {enable|disable|toggle|status} [IP]${_CLR_RESET}"
      echo "Examples:"
      echo "  proxy redsocks enable             (uses system proxy)"
      echo "  proxy redsocks enable 172.31.1.100"
      echo "  proxy redsocks toggle             (enable/disable based on current status)"
      echo "  proxy redsocks toggle 172.31.1.100"
      echo "  proxy redsocks disable"
      echo "  proxy redsocks status"
      return 1
      ;;
  esac
}

kitty-cmd() {
    local text="$1"
    shift
    local cmd="$*"
    local encoded
    encoded=$(printf '%s' "$cmd" | sed 's/ /%%20/g')
    printf '\e]8;;kitty-cmd://%s\e\\%s\e]8;;\e\\\n' "$encoded" "$text"
}


# VPN masquerade for hotspot clients
_proxy_masquerade() {
  local command="${1:-}"

  case "$command" in
    enable)
      pkexec /usr/local/sbin/masquerade enable "${2:-tun0}" "${3:-wlp2s0}"
      ;;
    disable)
      pkexec /usr/local/sbin/masquerade disable "${2:-tun0}" "${3:-wlp2s0}"
      ;;
    status)
      pkexec /usr/local/sbin/masquerade status "${2:-tun0}" "${3:-wlp2s0}"
      ;;
    *)
      echo -e "${_CLR_ERROR}Usage: proxy masquerade {enable|disable|status} [VPN_IF] [HOTSPOT_IF]${_CLR_RESET}"
      echo "  Defaults: VPN_IF=tun0, HOTSPOT_IF=wlp2s0"
      echo "Examples:"
      echo "  proxy masquerade enable"
      echo "  proxy masquerade enable tun0 wlp2s0"
      echo "  proxy masquerade disable"
      echo "  proxy masquerade status"
      return 1
      ;;
  esac
}

# Proxy testing command
_proxy_test() {
    local url="https://example.com"  # URL to test proxies against
    local proxy_file="$HOME/.dotfiles/proxy/proxy.txt"

    if [[ ! -f "$proxy_file" ]]; then
        echo -e "${_CLR_ERROR}Proxy file not found: $proxy_file${_CLR_RESET}"
        return 1
    fi

    local total=$(wc -l < "$proxy_file")
    local count=0

    echo -e "${_CLR_INFO}${_CLR_BOLD}Testing proxies...${_CLR_RESET}"

    while IFS= read -r ip; do
        count=$((count + 1))
        echo -ne "\rTesting proxy $count/$total..."

        local proxy="http://edcguest:edcguest@$ip:3128"

        if curl -x "$proxy" -s --connect-timeout 5 "$url" > /dev/null; then
            echo -e "\r${_CLR_SUCCESS}✓ Test passed:${_CLR_RESET} $ip\t\t${_CLR_ACCENT} $(kitty-cmd "proxy system set $ip" "proxy system set $ip") ${_CLR_RESET}"
        else
            echo -e "\r${_CLR_ERROR}✗ Test failed:${_CLR_RESET} $ip"
        fi
    done < "$proxy_file"

    echo -e "${_CLR_SUCCESS}${_CLR_BOLD}✓ Proxy testing completed.${_CLR_RESET}"
}

# Get and display current proxy settings
_proxy_get() {
    echo -e "${_CLR_INFO}${_CLR_BOLD}Current Proxy Settings:${_CLR_RESET}"

    # Display KDE system proxy settings
    local kde_type=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key ProxyType 2>/dev/null)
    local kde_http=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key httpProxy 2>/dev/null)
    local kde_https=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key httpsProxy 2>/dev/null)
    local kde_noproxy=$(kreadconfig6 --file kioslaverc --group "Proxy Settings" --key NoProxyFor 2>/dev/null)

    local mode_label="None"
    [[ "$kde_type" == "1" ]] && mode_label="Manual"
    [[ "$kde_type" == "2" ]] && mode_label="PAC"
    [[ "$kde_type" == "3" ]] && mode_label="Auto-detect"
    [[ "$kde_type" == "4" ]] && mode_label="System"

    echo -e "${_CLR_ACCENT}KDE System Proxy:${_CLR_RESET}"
    echo -e "  Mode:     ${_CLR_DIM}$mode_label (ProxyType=$kde_type)${_CLR_RESET}"
    echo -e "  HTTP:     ${_CLR_DIM}${kde_http:-Not Set}${_CLR_RESET}"
    echo -e "  HTTPS:    ${_CLR_DIM}${kde_https:-Not Set}${_CLR_RESET}"
    echo -e "  NoProxy:  ${_CLR_DIM}${kde_noproxy:-Not Set}${_CLR_RESET}"

    # Display environment proxy settings
    echo -e "${_CLR_ACCENT}Environment Proxy:${_CLR_RESET}"
    echo -e "  http_proxy:  ${_CLR_DIM}${http_proxy:-Not Set}${_CLR_RESET}"
    echo -e "  https_proxy: ${_CLR_DIM}${https_proxy:-Not Set}${_CLR_RESET}"
    echo -e "  HTTP_PROXY:  ${_CLR_DIM}${HTTP_PROXY:-Not Set}${_CLR_RESET}"
    echo -e "  HTTPS_PROXY: ${_CLR_DIM}${HTTPS_PROXY:-Not Set}${_CLR_RESET}"

    # Display redsocks status
    echo -e "${_CLR_ACCENT}Redsocks:${_CLR_RESET}"
    if systemctl is-active --quiet redsocks 2>/dev/null; then
        echo -e "  Status:  ${_CLR_SUCCESS}${_CLR_BOLD}Active${_CLR_RESET}"
    else
        echo -e "  Status:  ${_CLR_DIM}Inactive${_CLR_RESET}"
    fi
}

# Display help information
_proxy_help() {
    cat << 'EOF'
Proxy Management Tool

USAGE:
  proxy <command> [subcommand] [options]

SHELL PROXY COMMANDS:
  proxy shell enable            Enable shell proxy based on system settings
                                Updates NetworkManager and DNF configurations (Use --local to avoid)
  proxy shell disable           Disable shell proxy
                                Restores NetworkManager and DNF configurations (Use --local to avoid)
  proxy shell toggle            Toggle shell proxy (based on env vars)
                                Uses same system updates as enable/disable (Use --local to avoid)
  proxy shell configure         Auto-configure shell proxy based on system settings
                                Enables if system proxy mode is not 'none', disables otherwise
  proxy shell status            Show current shell proxy status

SYSTEM PROXY COMMANDS:
  proxy system set <IP>         Set system proxy (auto-prefixes 172.31)
                                Example: proxy system set 102.29
  proxy system enable           Set system proxy mode to manual
  proxy system disable          Set system proxy mode to none

REDSOCKS REDIRECTION COMMANDS:
  proxy redsocks enable [IP]    Enable transparent proxy redirection
                                IP: proxy IP (optional, defaults to system proxy)
  proxy redsocks disable        Disable transparent proxy redirection
  proxy redsocks toggle [IP]    Toggle transparent proxy redirection (enable/disable)
  proxy redsocks status         Show transparent proxy status

MASQUERADE COMMANDS:
  proxy masquerade enable [tun0] [wlp2s0]
  proxy masquerade disable
  proxy masquerade status

GENERAL COMMANDS:
  proxy get                     Display current proxy settings
  proxy test                    Test proxies listed in proxy.txt file
  proxy help                    Show this help message
EOF
}
