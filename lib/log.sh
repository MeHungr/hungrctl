#!/bin/bash
# log.sh — Standardized log formatting for blue team scripts

# ANSI color codes
green="\033[0;32m"
yellow="\033[1;33m"
red="\033[0;31m"
blue="\033[1;34m"
reset="\033[0m"

# Timestamp helper
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Logging functions
log_info() {
    echo -e "${blue}[$(timestamp)] [INFO]${reset} $*"
}

log_ok() {
    echo -e "${green}[$(timestamp)] [OK]${reset} $*"
}

log_warn() {
    echo -e "${yellow}[$(timestamp)] [WARN]${reset} $*"
}

log_fail() {
    echo -e "${red}[$(timestamp)] [FAIL]${reset} $*"
}

log_section() {
    echo -e "\n${blue}========== $* ==========${reset}\n"
}

# Format a log file or string for Discord
log_discord() {
    local input="$1"
    local title="${2:-}"
    local content

    # Strip ANSI color codes
    content="$(echo "$input" | sed -r 's/\x1B\[[0-9;]*[mK]//g')"

    # Wrap in code block
    if [[ -n "$title" ]]; then
        echo -e "**$title**\n\`\`\`\n$content\n\`\`\`"
    else
        echo -e "\`\`\`\n$content\n\`\`\`"
    fi
}

# Combines the functionality of log_discord and discord_send.sh
send_discord_alert() {
    local message="$1"
    local title="$2"
    local webhook="$3"

    if [[ -z "$webhook" ]]; then
        log_warn "No Discord webhook provided for alert: \"$title\""
        return 1
    fi

    local formatted
    formatted=$(log_discord "$message" "$title")

    local script_dir
    script_dir="$(dirname "${BASH_SOURCE[0]}")"
    local discord_script="$script_dir/discord_send.sh"

    if [[ ! -x "$discord_script" ]]; then
        log_fail "Could not find discord_send.sh at $discord_script"
        return 2
    fi

    "$discord_script" "$formatted" "$webhook"
}
