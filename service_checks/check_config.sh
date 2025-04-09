#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

HOST="$(hostname)"
MODE="${1:-check}"
SUMMARY_LOG="$SUMMARY_DIR/check_config.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root."
    exit 1
fi

# ===== Check if CONFIG_FILES is set =====
if [ -z "${CONFIG_FILES[*]}" ]; then
    log_warn "No CONFIG_FILES defined in config.sh"
    exit 0
fi

# ===== Ensure baseline directory exists =====
mkdir -p "$CONFIG_BASELINE_DIR"

# Initialize lists
MISSING_FILES=()
MODIFIED_FILES=()
RESTORED_FILES=()

# ===== Run Checks =====
for file in "${CONFIG_FILES[@]}"; do
    baseline_file="$CONFIG_BASELINE_DIR/$(echo "$file" | sed 's|/|_|g').baseline"

    if [ "$MODE" = "baseline" ]; then
        if [ ! -f "$baseline_file" ]; then
            log_warn "No baseline exists for $file. Creating one now..."
            cp "$file" "$baseline_file"
            chattr +i "$baseline_file"
            log_ok "Baseline created for $file"
            continue
        fi

        if diff -u "$baseline_file" "$file" > /dev/null; then
            log_ok "No differences found. Baseline already up to date." | tee -a "$SUMMARY_LOG"
        else
            log_warn "Differences detected in $file:"
            diff -u "$baseline_file" "$file"
            read -p "Overwrite existing baseline with current ruleset? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                cp "$file" "$baseline_file"
                log_ok "Baseline updated successfully."
                event_log "BASELINE-UPDATED" "User approved and updated the $file baseline"

                echo "[$HOST] Baseline for $file was updated via baseline mode at $(timestamp)" >> "$SUMMARY_LOG"
            else
                log_info "Baseline update canceled."
                event_log "BASELINE-CANCELED" "User canceled the $file baseline update"

                echo "[$HOST] Baseline update was canceled via baseline mode at $(timestamp)" >> "$SUMMARY_LOG"
            fi
        fi
        continue
    else
        if [ ! -f "$baseline_file" ]; then
            log_warn "No baseline exists for $file. Creating one now..."
            cp "$file" "$baseline_file"
            chattr +i "$baseline_file"
            log_ok "Baseline created for $file"
            continue
        fi

        if [ ! -e "$file" ]; then
            log_warn "$file is missing"
            MISSING_FILES+=("$file")

            if [ "$AUTO_RESTORE_CONFIG_FILES" = true ]; then
                cp "$baseline_file" "$file"
                log_ok "$file restored from baseline."
                RESTORED_FILES+=("$file")
                event_log "CONFIG-RESTORE" "$file was missing and restored from baseline on $HOST"
            else
                event_log "CONFIG-MISSING" "$file is missing on $HOST"
            fi
            continue
        fi
    fi


    if ! diff -q "$file" "$baseline_file" >/dev/null; then
        log_warn "$file differs from baseline."
        MODIFIED_FILES+=("$file")
        # Only show diff if it's relatively short
        if [ "$(diff -u "$file" "$baseline_file" | wc -l)" -lt 10 ]; then
            diff -u "$file" "$baseline_file"
        else
            log_warn "Diff too large to display. Use 'diff -u \"$file\" \"$baseline_file\"' to view changes."
        fi

        if [ "$AUTO_RESTORE_CONFIG_FILES" = true ]; then
            cp "$baseline_file" "$file"
            log_ok "$file restored from baseline."
            RESTORED_FILES+=("$file")
            event_log "CONFIG-RESTORE" "$file restored from baseline on $HOST"
        else
            event_log "CONFIG-MODIFIED" "$file modified on $HOST"
        fi
    else
        log_ok "$file matches baseline."
    fi

done

# ===== Generate summary log =====
{
    if [[ ${#MISSING_FILES[@]} -gt 0 || ${#MODIFIED_FILES[@]} -gt 0 ]]; then
        echo "[$HOST] Config check failed at $(timestamp)"
        echo
        [[ ${#MISSING_FILES[@]} -gt 0 ]] && echo "Missing Files:" && printf '• %s\n' "${MISSING_FILES[@]}" && echo
        [[ ${#MODIFIED_FILES[@]} -gt 0 ]] && echo "Modified Files:" && printf '• %s\n' "${MODIFIED_FILES[@]}" && echo
        [[ ${#RESTORED_FILES[@]} -gt 0 ]] && echo "Restored Files:" && printf '• %s\n' "${RESTORED_FILES[@]}" && echo
    fi
} >> "$SUMMARY_LOG"

# ===== Report Results =====
if [[ ${#MISSING_FILES[@]} -gt 0 || ${#MODIFIED_FILES[@]} -gt 0 ]]; then
    log_warn "Config file check completed with issues."
    exit 10
else
    if [ "$MODE" = "check" ]; then
        log_ok "All config files validated successfully."
        exit 0
    fi
fi