#!/bin/bash

# ===== Dependency Check =====
ensure_jq_installed() {
    if command -v jq &>/dev/null; then return 0; fi

    echo "[info] 'jq' not found. Attempting to install..."

    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y jq && return 0
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y jq && return 0
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy jq --noconfirm && return 0
    elif command -v yum &>/dev/null; then
        sudo yum install -y jq && return 0
    fi

    echo "[error] Could not install jq. Please install it manually."
    exit 1
}

ensure_jq_installed

# ===== Input =====
message="$1"
discord_webhook_url="$2"
max_chars=1900

if [[ -z "$message" || -z "$discord_webhook_url" ]]; then
    echo "Usage: $0 <message> <discord_webhook_url>"
    exit 1
fi

# ===== Strip ANSI color codes =====
message="$(echo "$message" | sed -r 's/\x1B\[[0-9;]*[mK]//g')"

# ===== Send one chunk =====
send_chunk() {
    local chunk="$1"
    curl -s -X POST "$discord_webhook_url" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg content "$chunk" '{content: $content}')" >/dev/null

    if [[ $? -ne 0 ]]; then
        echo "[error] Failed to send message chunk to Discord."
        exit 2
    fi
}

send_discord_message() {
    local content="$1"
    local title=""
    local body=""
    local chunk

    # Extract title and body
    if [[ "$content" =~ ^(\*\*.*\*\*)\s*\n*```(.*)```$ ]]; then
        title="${BASH_REMATCH[1]}"
        body="${BASH_REMATCH[2]}"
    else
        send_chunk "$content"
        return
    fi

    # Split code block into chunks
    mapfile -t chunks < <(echo "$body" | fold -s -w "$max_chars")


    for i in "${!chunks[@]}"; do
        chunk="\`\`\`${chunks[$i]}\`\`\`"
        if [[ $i -eq 0 ]]; then
            send_chunk "$title$chunk"
        else
            send_chunk "$chunk"
        fi
    done
}

send_discord_message "$message"