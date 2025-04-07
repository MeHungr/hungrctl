#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

HOST="$(hostname)"
MODE="${1:-check}"
TEMP_LOG="$(mktemp "$TMP_DIR/coreutils_check.XXXXXX")"
SUMMARY_LOG="$LOG_DIR/check_coreutils.summary"
trap 'rm -f "$TEMP_LOG"' EXIT

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

case "$DISTRO" in
    ubuntu|debian)
        if ! command -v debsums &>/dev/null; then
            log_info "debsums not found. Installing..."
            apt-get update -y >/dev/null 2>&1
            if apt-get install -y debsums >/dev/null 2>&1; then
                log_info "Installed debsums successfully."
            else
                log_fail "Failed to install debsums. Skipping coreutils check."
                exit 2
            fi
        fi
        log_info "Checking coreutils integrity with debsums..."
        debsums coreutils >> "$TEMP_LOG" 2>&1
        ;;
    rhel|centos|fedora)
        log_info "Checking coreutils integrity with rpm -V..."
        rpm -V coreutils >> "$TEMP_LOG" 2>&1
        ;;
    arch|manjaro)
        if command -v paccheck &>/dev/null; then
            log_info "Checking coreutils integrity with paccheck..."
            paccheck --md5sum coreutils >> "$TEMP_LOG" 2>&1
        else
            log_info "Falling back to pacman -Qkk..."
            pacman -Qkk coreutils >> "$TEMP_LOG" 2>&1
        fi
        ;;
    *)
        log_warn "Unsupported distro: $DISTRO" >> "$TEMP_LOG" 2>&1
        ;;
esac

# ===== Evaluate results =====
if grep -q "FAILED\|5\|missing\|differ" "$TEMP_LOG"; then
    log_fail "Coreutils integrity check failed. Potential modification detected."
    event_log "COREUTILS-MODIFIED" "coreutils files differ from expected state on $HOST"

    if [ "$DISCORD" = true ]; then
        send_discord_alert "[$HOST] Coreutils integrity check failed at $(timestamp)" \
                           "COREUTILS-MODIFIED" \
                           "$COREUTILS_WEBHOOK_URL"
    fi
    exit 10
else
    log_ok "Coreutils integrity check passed."
    exit 0
fi