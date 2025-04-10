#!/bin/bash

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib/env.sh"

HOST="$(hostname)"
MODE="${1:-check}"
SUMMARY_LOG="$SUMMARY_DIR/check_services.summary"
# Create the summary log file if it doesn't exist
# and clear it.
touch "$SUMMARY_LOG"
> "$SUMMARY_LOG"

# ===== Ensure root =====
if [ "$EUID" -ne 0 ]; then
	log_fail "This script must be run as root."
	exit 1
fi

# ===== Exit if mode is baseline =====
if [ "$MODE" = "baseline" ]; then
    log_info "Services integrity check has no baseline mode."
    exit 0
fi

# ===== Ensure SERVICES list is defined =====
if [[ ${#SERVICES[@]} -eq 0 ]]; then
	log_warn "No SERVICES defined in .env - skipping service checks."
	exit 0
fi

# Initialize lists
FAILED_SERVICES=()
INACTIVE_SERVICES=()
RESTARTED_SERVICES=()
RESTART_FAILS=()

# ===== Check each declared service =====
for svc in "${SERVICES[@]}"; do
    state=$(systemctl is-active "$svc" 2>/dev/null)

    case "$state" in
        failed)
            log_fail "$svc is in a failed state."
            event_log "SERVICE-FAIL" "$svc is in a failed state on $HOST"
            FAILED_SERVICES+=("$svc")
            ;;
        inactive)
            log_warn "$svc is inactive."
            event_log "SERVICE-INACTIVE" "$svc is inactive on $HOST"
            INACTIVE_SERVICES+=("$svc")
            ;;
        *)
            log_ok "$svc is active."
            ;;
    esac
done

# ===== Auto-restart logic =====
if [ "$AUTO_RESTART" = true ]; then
	for svc in "${FAILED_SERVICES[@]}" "${INACTIVE_SERVICES[@]}"; do
		log_info "Attempting to restart $svc..."
		systemctl enable --now "$svc"

		if systemctl is-active --quiet "$svc"; then
			log_ok "$svc restarted successfully."
			event_log "SERVICE-RESTARTED" "$svc was automatically restarted on $HOST"
			RESTARTED_SERVICES+=("$svc")
		else
			log_fail "Failed to restart $svc."
			event_log "SERVICE-RESTART-FAIL" "$svc restart failed on $HOST"
			RESTART_FAILS+=("$svc")
		fi
	done
else
    log_warn "Automatic service restarts are disabled. Check config.sh to re-enable. Skipping..."
fi

# ===== Determine if something went wrong and log it =====
if [[ ${#FAILED_SERVICES[@]} -eq 0 && ${#INACTIVE_SERVICES[@]} -eq 0 && ${#RESTART_FAILS[@]} -eq 0 ]]; then
	log_ok "All monitored services are running."
	exit 0
fi

# ===== Generate summary log only if there are issues =====
{
    echo "[$HOST] Service check failed at $(timestamp)"
    echo
    [[ ${#FAILED_SERVICES[@]} -gt 0 ]] && echo "Failed Services:" && printf '• %s\n' "${FAILED_SERVICES[@]}" && echo
    [[ ${#INACTIVE_SERVICES[@]} -gt 0 ]] && echo "Inactive Services:" && printf '• %s\n' "${INACTIVE_SERVICES[@]}" && echo
    [[ ${#RESTARTED_SERVICES[@]} -gt 0 ]] && echo "Restarted Successfully:" && printf '• %s\n' "${RESTARTED_SERVICES[@]}" && echo
    [[ ${#RESTART_FAILS[@]} -gt 0 ]] && echo "Restart Failed:" && printf '• %s\n' "${RESTART_FAILS[@]}" && echo
} >> "$SUMMARY_LOG"