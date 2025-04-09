#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

HOST="$(hostname)"
MODE="${1:-check}"
BASELINE_FILE="$FIREWALL_BASELINE_DIR/nftables_rules.baseline"
TEMP_FILE="$(mktemp "$TMP_DIR/current_nftables_rules.XXXXXX")"
SUMMARY_LOG="$SUMMARY_DIR/check_firewall.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"
trap 'rm -f "$TEMP_FILE"' EXIT

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

# ===== Ensure baseline file exists =====
if [ ! -f "$BASELINE_FILE" ]; then
    log_warn "No baseline file found at $BASELINE_FILE. Creating one now..."
    nft list ruleset > "$BASELINE_FILE"
    chattr +i "$BASELINE_FILE"
    if [ $? -eq 0 ]; then
        log_ok "Created a baseline file for nftables rules."
    else
        log_fail "Could not create baseline file at $BASELINE_FILE."
        exit 5
    fi
fi

# ===== Function: Get current ruleset =====
get_ruleset() {
    nft list ruleset > "$TEMP_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        log_fail "Could not retrieve nftables ruleset. Is nft running?"
        exit 3
    fi
}

# ===== Function: Compare against baseline =====
compare_ruleset() {
    if ! diff -u "$BASELINE_FILE" "$TEMP_FILE" > /dev/null; then
        log_warn "The nftables ruleset differs from baseline."
        diff -u "$BASELINE_FILE" "$TEMP_FILE"

        if [ "$AUTO_RESTORE_FIREWALL" = true ]; then
            log_info "Restoring baseline ruleset..."
            nft flush ruleset
            nft -f "$BASELINE_FILE"

            if [ $? -eq 0 ]; then
                nft list ruleset > /etc/nftables.conf
                systemctl restart nftables
                systemctl enable nftables
                log_ok "Baseline firewall ruleset restored."

                event_log "RESTORE" "Baseline firewall ruleset restored due to mismatch"

                echo "[$HOST] Baseline firewall ruleset was restored due to a mismatch at $(timestamp)" > "$SUMMARY_LOG"
                exit 10
            else
                log_fail "Failed to restore baseline ruleset."
                event_log "RESTORE-FAIL" "Attempted to restore firewall ruleset but failed"

                echo "[$HOST] Firewall ruleset failed to restore after mismatch at $(timestamp)" > "$SUMMARY_LOG"
                exit 11
            fi
        else
            log_warn "Automatic firewall restoration is disabled. Check config.sh to re-enable."
            event_log "FIREWALL-MODIFIED" "Firewall ruleset modified on $HOST"
            echo "[$HOST] Firewall ruleset differs from baseline at $(timestamp)" > "$SUMMARY_LOG"
            exit 10
        fi
    else
        log_ok "Firewall ruleset matches baseline."
        exit 0
    fi
}

# ===== Baseline Mode =====
if [[ "$MODE" == "baseline" ]]; then
    log_info "Comparing current ruleset to baseline before overwriting..."
    nft list ruleset > "$TEMP_FILE"

    if diff -u "$BASELINE_FILE" "$TEMP_FILE" > /dev/null; then
        log_ok "No differences found. Baseline already up to date."
        rm -f "$TEMP_FILE"
        exit 0
    else
        log_warn "Differences detected:"
        diff -u "$BASELINE_FILE" "$TEMP_FILE"

        read -p "Overwrite existing baseline with current ruleset? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            cp "$TEMP_FILE" "$BASELINE_FILE"
            log_ok "Baseline updated successfully."
            event_log "BASELINE-UPDATED" "User approved and updated the firewall baseline"

            echo "[$HOST] Baseline firewall ruleset was updated via baseline mode at $(timestamp)" > "$SUMMARY_LOG"
            exit 0
        else
            log_info "Baseline update canceled."
            event_log "BASELINE-CANCELED" "User canceled the firewall baseline update"

            echo "[$HOST] Baseline update was canceled via baseline mode at $(timestamp)" > "$SUMMARY_LOG"
            rm -f "$TEMP_FILE"
            exit 7
        fi
    fi
fi

# ===== Default Mode: Check =====
if [[ "$MODE" == "check" ]]; then
    get_ruleset
    compare_ruleset
fi

