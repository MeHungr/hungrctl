#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

HOST="$(hostname)"
MODE="${1:-check}"
TEMP_LOG="$(mktemp "$TMP_DIR/coreutils_check.XXXXXX")"
SUMMARY_LOG="$SUMMARY_DIR/check_coreutils.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"
trap 'rm -f "$TEMP_LOG"' EXIT

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

# ===== Exit if mode is baseline =====
if [ "$MODE" = "baseline" ]; then
    log_info "Coreutils integrity check has no baseline mode."
    exit 0
fi

# ===== Detect distro and check coreutils integrity =====
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
        debsums -s coreutils >> "$TEMP_LOG" 2>&1
        ;;
    rhel|centos|fedora)
        log_info "Checking coreutils integrity with rpm -V..."
        rpm -V coreutils >> "$TEMP_LOG" 2>&1
        ;;
    arch|manjaro)
        if command -v paccheck &>/dev/null; then
            log_info "Checking coreutils integrity with paccheck..."
            paccheck --md5sum coreutils | grep -v ": OK$" >> "$TEMP_LOG" 2>&1
        else
            log_info "Falling back to pacman -Qkk..."
            pacman -Qkk coreutils | grep -E "missing|mismatch|MODIFIED" >> "$TEMP_LOG" 2>&1
        fi
        ;;
    *)
        log_warn "Unsupported distro: $DISTRO"
        ;;
esac

# ===== Evaluate results =====
if [ -s "$TEMP_LOG" ]; then
    log_warn "Coreutils integrity check failed. Potential modification detected."
    event_log "COREUTILS-MODIFIED" "coreutils files differ from expected state on $HOST"

    echo "[$HOST] Coreutils integrity check failed at $(timestamp)" > "$SUMMARY_LOG"
    echo "Failed files:" >> "$SUMMARY_LOG"
    echo "----------------------------------------" >> "$SUMMARY_LOG"
    cat "$TEMP_LOG" >> "$SUMMARY_LOG"
    echo "----------------------------------------" >> "$SUMMARY_LOG"
    # ===== If coreutils is modified, we need to reinstall it. =====
    if [ "$AUTO_REINSTALL_COREUTILS" = true ]; then
        log_info "Attempting to reinstall coreutils..."
        case "$DISTRO" in
            ubuntu|debian)
                apt-get install --reinstall -y coreutils >/dev/null 2>&1 \
                && { log_ok "coreutils reinstalled successfully."; } | tee -a "$SUMMARY_LOG" \
                || { log_fail "coreutils reinstall failed."; } | tee -a "$SUMMARY_LOG"
                ;;
            rhel|centos|fedora)
                dnf reinstall -y coreutils >/dev/null 2>&1 \
                && { log_ok "coreutils reinstalled successfully."; } | tee -a "$SUMMARY_LOG" \
                || { log_fail "coreutils reinstall failed."; } | tee -a "$SUMMARY_LOG"
                ;;
            arch|manjaro)
                pacman -S --noconfirm coreutils >/dev/null 2>&1 \
                && { log_ok "coreutils reinstalled successfully."; } | tee -a "$SUMMARY_LOG" \
                || { log_fail "coreutils reinstall failed."; } | tee -a "$SUMMARY_LOG"
                ;;
            *)
                log_fail "Unsupported distro: $DISTRO" >> "$SUMMARY_LOG"
        esac
    else
        log_warn "Automatic reinstall of coreutils is disabled. Check config.sh to re-enable. Skipping..." >> "$SUMMARY_LOG"
    fi
    exit 10
else
    log_ok "Coreutils integrity check passed."
    exit 0
fi
