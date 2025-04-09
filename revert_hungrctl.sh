#!/bin/bash

# This script reverts the hungrctl system lockdown and service installation for testing.
# WARNING: Use only in trusted environments.

# ===== Configuration =====
service_file="/etc/systemd/system/hungrctl.service"
timer_file="/etc/systemd/system/hungrctl.timer"

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/env.sh"

# ===== This script must be run as root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root"
    exit 1
fi

echo "[*] Reverting hungrctl setup..."

# ===== Step 1: Disable and remove systemd service and timer =====
echo "[*] Disabling systemd timer and service..."
systemctl disable --now hungrctl.timer
systemctl disable --now hungrctl.service

# ===== Step 2: Remove immutable attributes =====
echo "[*] Removing chattr +i from service and timer files..."
chattr -i "$service_file" 2>/dev/null || true
chattr -i "$timer_file" 2>/dev/null || true

echo "[*] Removing chattr +i from script files..."
find "$ROOT_DIR/service_checks" -type f -exec chattr -i {} \; 2>/dev/null || true
chattr -i "$ROOT_DIR/service_checks" 2>/dev/null || true
chattr -i "$ROOT_DIR/hungrctl" 2>/dev/null || true

# ===== Step 3: Remove systemd unit files =====
rm -f "$service_file"
rm -f "$timer_file"
log_ok "Removed systemd unit files."

# ===== Step 4: Reset permissions =====
echo "[*] Resetting permissions on $ROOT_DIR..."
chmod -R 755 "$ROOT_DIR"
chmod 644 "$ROOT_DIR/config.sh"
chmod 777 "$ROOT_DIR/output"  # make writable for everyone for testing

# Optional: reset ownership
chown -R "$(logname):$(logname)" "$ROOT_DIR" 2>/dev/null || true

log_ok "[✔] hungrctl environment fully reverted for testing."
