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
title="$1"
body="$2"
discord_webhook_url="$3"
max_chars=1900

if [[ -z "$body" || -z "$discord_webhook_url" ]]; then
    echo "Usage: $0 <title> <body> <discord_webhook_url>"
    exit 1
fi

# ===== Strip ANSI color codes from body =====
body="$(echo "$body" | sed -r 's/\x1B\[[0-9;]*[mK]//g')"

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

# ===== Send Discord Message =====
send_discord_message() {
    local chunk=""
    local is_first=true

    # Clean body: remove blank lines at start/end
    body="$(echo "$body" | awk 'NF' ORS="\n")"

    while IFS= read -r line; do
        if (( ${#chunk} + ${#line} + 1 >= max_chars - 10 )); then
            chunk="\`\`\`${chunk%$'\n'}\`\`\`"
            if $is_first && [[ -n "$title" ]]; then
                send_chunk "$title"$'\n'"$chunk"
                is_first=false
            else
                send_chunk "$chunk"
            fi
            chunk=""
        fi
        chunk+="$line"$'\n'
    done <<< "$body"

    # Final chunk
    if [[ -n "$chunk" ]]; then
        chunk="\`\`\`${chunk%$'\n'}\`\`\`"
        if $is_first && [[ -n "$title" ]]; then
            send_chunk "$title"$'\n'"$chunk"
        else
            send_chunk "$chunk"
        fi
    fi
}

send_discord_message