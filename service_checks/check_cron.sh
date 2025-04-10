#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

# Ensure CRON_BASELINE_DIR exists
mkdir -p "$CRON_BASELINE_DIR" || {
    log_fail "Failed to create CRON_BASELINE_DIR: $CRON_BASELINE_DIR"
    exit 1
}

temp_file="$TMP_DIR/cron_dump.txt"
baseline_file="$CRON_BASELINE_DIR/cron_dump.baseline"
SUMMARY_LOG="$SUMMARY_DIR/check_cron.summary"

# Create the summary log file if it doesn't exist and clear it
mkdir -p "$(dirname "$SUMMARY_LOG")" || {
    log_fail "Failed to create SUMMARY_LOG directory"
    exit 1
}
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"
trap "rm -f '$temp_file'" EXIT

MODE="${1:-check}"

dump_cron() {
    {
        echo "### /etc/crontab"
        if [ -f /etc/crontab ]; then
            while IFS= read -r line; do
                echo "[SOURCE:/etc/crontab] $line"
            done < /etc/crontab
        fi

        echo -e "\n### /etc/cron.d/*"
        for file in /etc/cron.d/*; do
            [ -f "$file" ] || continue
            while IFS= read -r line; do
                echo "[SOURCE:$file] $line"
            done < "$file"
        done

        echo -e "\n### User crontabs"
        # Get users first, then process them
        users=$(awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ {print $1}' /etc/passwd)
        while read -r user; do
            if crontab -l -u "$user" > /dev/null 2>&1; then
                while IFS= read -r line; do
                    echo "[SOURCE:user:$user] $line"
                done < <(crontab -l -u "$user" 2>/dev/null)
            else
                echo "[SOURCE:user:$user] # No crontab"
            fi
        done <<< "$users"

        echo -e "\n### Cront script hashes (/etc/cron.*)"
        # Get files first, then process them
        files=$(find /etc/cron.{hourly,daily,weekly,monthly} -type f 2>/dev/null | sort)
        while read -r file; do
            if [ -f "$file" ]; then
                echo "[SOURCE:$file] $(sha256sum "$file" 2>/dev/null)"
            else
                echo "[SOURCE:$file] FAILED_HASH"
            fi
        done <<< "$files"
    } > "$temp_file"
}

compare_cron() {
    if [ -f "$baseline_file" ]; then
        diff_output=$(diff -u "$baseline_file" "$temp_file")
        if [ -n "$diff_output" ]; then
            log_warn "Cron job changes detected:"
            echo "$diff_output"
            echo "Cron job changes detected:" >> "$SUMMARY_LOG"
            echo "$diff_output" >> "$SUMMARY_LOG"
        else
            log_ok "No cron job changes detected."
        fi
    else
        log_warn "No baseline file found for cron job changes. Creating one now..."
        dump_cron
        cp "$temp_file" "$baseline_file" || {
            log_fail "Failed to create baseline file: $baseline_file"
            exit 1
        }
        chattr +i "$baseline_file" || {
            log_warn "Failed to set immutable attribute on baseline file"
        }
        log_ok "Created a baseline file for cron job changes."
    fi
}

if [ "$MODE" = "check" ]; then
    dump_cron
    compare_cron
elif [ "$MODE" = "baseline" ]; then
    dump_cron
    if [ -f "$baseline_file" ] && diff -u "$baseline_file" "$temp_file" > /dev/null; then
        log_ok "No differences found. Baseline already up to date."
        exit 0
    else
        log_warn "Differences detected:"
        diff -u "$baseline_file" "$temp_file" 2>/dev/null

        read -p "Overwrite existing baseline with current ruleset? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cp "$temp_file" "$baseline_file" || {
                log_fail "Failed to update baseline file: $baseline_file"
                exit 1
            }
            log_ok "Baseline updated successfully."
            event_log "BASELINE-UPDATED" "User approved and updated the cron job baseline"

            echo "[$HOST] Baseline cron job changes were updated via baseline mode at $(timestamp)" > "$SUMMARY_LOG"
            exit 0
        else
            log_info "Baseline update canceled."
            event_log "BASELINE-CANCELED" "User canceled the cron job baseline update"

            echo "[$HOST] Baseline update was canceled via baseline mode at $(timestamp)" > "$SUMMARY_LOG"
            exit 7
        fi
    fi
fi