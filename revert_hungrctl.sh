#!/bin/bash

# This script reverts the hungrctl system lockdown and service installation for testing.
# WARNING: Use only in trusted environments.

# ===== Configuration =====
service_file="/etc/systemd/system/hungrctl.service"
timer_file="/etc/systemd/system/hungrctl.timer"
watchdog_service="/etc/systemd/system/hungrctl-watchdog.service"
watchdog_timer="/etc/systemd/system/hungrctl-watchdog.timer"

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/env.sh"

# ===== This script must be run as root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root"
    exit 1
fi

# ===== Function to safely remove immutable attributes =====
safe_remove_immutable() {
    local target="$1"
    if [ -e "$target" ]; then
        if [ -f "$target" ]; then
            chattr -i "$target" 2>/dev/null || log_warn "Failed to remove immutable attribute from $target"
        elif [ -d "$target" ]; then
            find "$target" -type f -exec chattr -i {} \; 2>/dev/null || log_warn "Failed to remove immutable attributes from files in $target"
            chattr -i "$target" 2>/dev/null || log_warn "Failed to remove immutable attribute from directory $target"
        fi
    fi
}

echo "[*] Starting hungrctl system revert..."

# ===== Step 1: Disable and remove systemd services and timers =====
echo "[*] Disabling systemd services and timers..."
for unit in hungrctl.timer hungrctl.service hungrctl-watchdog.timer hungrctl-watchdog.service; do
    if systemctl is-active --quiet "$unit"; then
        systemctl stop "$unit" || log_warn "Failed to stop $unit"
    fi
    if systemctl is-enabled --quiet "$unit"; then
        systemctl disable "$unit" || log_warn "Failed to disable $unit"
    fi
done

# ===== Step 2: Remove immutable attributes from ALL files =====
echo "[*] Removing immutable attributes from system files..."
for file in "$service_file" "$timer_file" "$watchdog_service" "$watchdog_timer"; do
    safe_remove_immutable "$file"
done

echo "[*] Removing immutable attributes from script files..."
safe_remove_immutable "$ROOT_DIR/service_checks"
safe_remove_immutable "$ROOT_DIR/lib"
safe_remove_immutable "$ROOT_DIR/hungrctl"
safe_remove_immutable "$ROOT_DIR/watchdog"
safe_remove_immutable "$ROOT_DIR/init_hungrctl.sh"
safe_remove_immutable "$ROOT_DIR/config.sh"
safe_remove_immutable "$OUTPUT_DIR"

# ===== Step 3: Remove systemd unit files =====
echo "[*] Removing systemd unit files..."
for file in "$service_file" "$timer_file" "$watchdog_service" "$watchdog_timer"; do
    if [ -f "$file" ]; then
        rm -f "$file" || log_warn "Failed to remove $file"
    fi
done

# ===== Step 4: Reset permissions and ownership =====
echo "[*] Resetting permissions and ownership..."
if [ -d "$ROOT_DIR" ]; then
    # Reset directory permissions
    chmod -R 755 "$ROOT_DIR" || log_warn "Failed to reset directory permissions"
    
    # Set specific file permissions
    chmod 644 "$ROOT_DIR/config.sh" 2>/dev/null || true
    chmod 777 "$ROOT_DIR/output" 2>/dev/null || true
    
    # Reset ownership to current user
    current_user=$(logname)
    if [ -n "$current_user" ]; then
        chown -R "$current_user:$current_user" "$ROOT_DIR" 2>/dev/null || log_warn "Failed to reset ownership"
    fi
else
    log_warn "ROOT_DIR ($ROOT_DIR) does not exist"
fi

# ===== Step 5: Reload systemd =====
echo "[*] Reloading systemd..."
systemctl daemon-reload || log_warn "Failed to reload systemd"

log_ok "[✔] hungrctl environment fully reverted for testing."
