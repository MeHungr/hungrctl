#!/bin/bash

host="$(hostname)"
mode="${1:-check}"
baseline_file="$BASELINE_DIR/nftables_rules.baseline"
temp_file="/tmp/current_nftables_rules.$$"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

# ===== Check for nft =====
if ! command -v nft &>/dev/null; then
    log_warn "nft command not found. Skipping firewall check."
    exit 2
fi

# ===== Ensure baseline directory exists =====
if [ ! -d "$BASELINE_DIR" ]; then
    log_warn "Baseline directory $BASELINE_DIR does not exist. Creating it now..."
    mkdir -p "$BASELINE_DIR" || {
        log_fail "Could not create baseline directory at $BASELINE_DIR"
        exit 4
    }
fi

# ===== Ensure baseline file exists =====
if [ ! -f "$baseline_file" ]; then
    log_warn "No baseline file found at $baseline_file. Creating one now..."
    nft list ruleset > "$baseline_file"
    if [ $? -eq 0 ]; then
        log_ok "Created a baseline file for nftables rules."
    else
        log_fail "Could not create baseline file at $baseline_file."
        exit 5
    fi
fi

# ===== Function: Get current ruleset =====
get_ruleset() {
    nft list ruleset > "$temp_file" 2>/dev/null
    trap "rm -f \"$temp_file\"" EXIT
    if [ $? -ne 0 ]; then
        log_fail "Could not retrieve nftables ruleset. Is nft running?"
        exit 3
    fi
}

# ===== Function: Compare against baseline =====
compare_ruleset() {
    if ! diff -u "$baseline_file" "$temp_file" > /dev/null; then
        log_fail "The nftables ruleset differs from baseline."
        diff -u "$baseline_file" "$temp_file"

        log_info "Restoring baseline ruleset..."
        nft flush ruleset
        nft -f "$baseline_file"

        if [ $? -eq 0 ]; then
            nft list ruleset > /etc/nftables.conf
            systemctl restart nftables
            systemctl enable nftables
            log_ok "Baseline firewall ruleset restored."
            echo "[FIREWALL-RESTORE] [$host] $(timestamp): Baseline restored due to mismatch"

            if [ "$DISCORD" = true ]; then
                send_discord_alert "[$host] Baseline firewall ruleset was restored due to a mismatch at $(timestamp)" \
                                   "FIREWALL RESTORE" \
                                   "$FIREWALL_WEBHOOK_URL"
            fi
            exit 10
        else
            log_fail "Failed to restore baseline ruleset."
            echo "[FIREWALL-RESTORE-FAIL] [$host] $(timestamp): Restore attempt failed"

            if [ "$DISCORD" = true ]; then
                send_discord_alert "[$host] Firewall ruleset failed to restore after mismatch at $(timestamp)" \
                                   "FIREWALL RESTORE FAILED" \
                                   "$FIREWALL_WEBHOOK_URL"
            fi
            exit 11
        fi
    else
        log_ok "Firewall ruleset matches baseline."
        exit 0
    fi
}

# ===== Baseline Mode =====
if [[ "$mode" == "baseline" ]]; then
    log_info "Comparing current ruleset to baseline before overwriting..."
    nft list ruleset > "$temp_file"

    if diff -u "$baseline_file" "$temp_file" > /dev/null; then
        log_ok "No differences found. Baseline already up to date."
        rm -f "$temp_file"
        exit 0
    else
        log_warn "Differences detected:"
        diff -u "$baseline_file" "$temp_file"

        read -p "Overwrite existing baseline with current ruleset? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            mv "$temp_file" "$baseline_file"
            log_ok "Baseline updated successfully."

            if [ "$DISCORD" = true ]; then
                send_discord_alert "[$host] Baseline firewall ruleset was updated via baseline mode at $(timestamp)" \
                                   "FIREWALL BASELINE UPDATED" \
                                   "$FIREWALL_WEBHOOK_URL"
            fi
            exit 0
        else
            log_info "Baseline update canceled."

            if [ "$DISCORD" = true ]; then
                send_discord_alert "[$host] Baseline update was canceled via baseline mode at $(timestamp)" \
                                   "FIREWALL BASELINE CANCELED" \
                                   "$FIREWALL_WEBHOOK_URL"
            fi
            rm -f "$temp_file"
            exit 7
        fi
    fi
fi

# ===== Default Mode: Check =====
if [[ "$mode" == "check" ]]; then
    get_ruleset
    compare_ruleset
fi
