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
    local chunk=""
    local in_code_block=false
    local reading_code=false

    # Separate title and code block using line parsing
    while IFS= read -r line; do
        if [[ "$line" =~ ^\*\*.*\*\*$ && "$title" == "" ]]; then
            title="$line"
        elif [[ "$line" == '```' && $reading_code == false ]]; then
            reading_code=true
        elif [[ "$line" == '```' && $reading_code == true ]]; then
            break
        elif $reading_code; then
            body+="$line"$'\n'
        fi
    done <<< "$content"

    if [[ -z "$body" ]]; then
        # No code block found — send as-is
        send_chunk "$content"
        return
    fi

    # Split body into line-safe chunks
    chunk=""
    while IFS= read -r line; do
        # If adding the line would exceed max_chars, send current chunk
        if (( ${#chunk} + ${#line} + 1 >= max_chars - 10 )); then
            chunk="\`\`\`\n$chunk\`\`\`"
            if [[ -n "$title" ]]; then
                send_chunk "$title"$'\n'"$chunk"
                title=""
            else
                send_chunk "$chunk"
            fi
            chunk=""
        fi
        chunk+="$line"$'\n'
    done <<< "$body"

    # Send final chunk
    if [[ -n "$chunk" ]]; then
        chunk="\`\`\`\n$chunk\`\`\`"
        if [[ -n "$title" ]]; then
            send_chunk "$title"$'\n'"$chunk"
        else
            send_chunk "$chunk"
        fi
    fi
}


send_discord_message "$message"