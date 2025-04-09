#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

temp_file="$TMP_DIR/cron_dump.txt"
baseline_file="$CRON_BASELINE_DIR/cron_dump.baseline"
SUMMARY_LOG="$SUMMARY_DIR/check_cron.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"
trap "rm -f '$temp_file'" EXIT

MODE="${1:-check}"

dump_cron() {
    {
        echo "### /etc/crontab"
        cat /etc/crontab 2>/dev/null || true

        echo -e "\n### /etc/cron.d/*"
        cat /etc/cron.d/* 2>/dev/null || true

        echo -e "\n### User crontabs"
        awk -F '$3 >= 1000 && $7 !~ /nologin|false/ {print $1}' /etc/passwd | while read -r user; do
            echo -e "\n# crontab for user: $user"
            crontab -l -u "$user" 2>/dev/null || echo "# No crontab for $user"
        done
        echo -e "\n### Cront script hashes (/etc/cron.*)"
        find /etc/cron.{hourly,daily,weekly,monthly} -type f 2>/dev/null | sort | while read -r file; do
            sha256sum "$file" 2>/dev/null || echo "FAILED_HASH $file"
        done
    } > "$temp_file"
}

compare_cron() {
    if [ -f "$baseline" ]; then
        diff_output=$(diff -u "$baseline" "$temp_file")
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
        cp "$temp_file" "$baseline"
        log_ok "Created a baseline file for cron job changes."
    fi
}

if [ "$MODE" = "check" ]; then
    dump_cron
    compare_cron
elif [ "$MODE" = "baseline" ]; then
    dump_cron
    cp "$temp_file" "$baseline_file"
    log_ok "Updated the baseline file for cron job changes."
fi