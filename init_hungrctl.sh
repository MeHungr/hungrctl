#!/bin/bash

# This script is used to initialize the hungrctl service.
# It will install the necessary dependencies and configure the service.

# ===== Configuration =====
service_dest="/etc/systemd/system/hungrctl.service"
timer_dest="/etc/systemd/system/hungrctl.timer"

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/env.sh"

# ===== This script must be run as root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root"
    exit 1
fi

# ===== Step 1: Deploy systemd service =====
echo "[*] Deploying hungrctl systemd service and timer..."

cat <<EOF > "$service_dest"
[Unit]
Description=HungrCTL - Service Uptime and Integrity Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=$ROOT_DIR/hungrctl -n
StandardOutput=journal
StandardError=journal
User=root
EOF
chmod 600 "$service_dest"
chown root:root "$service_dest"
chattr +i "$service_dest"
log_ok "Deployed and locked $service_file"

# ===== Step 2: Deploy systemd timer =====
echo "[*] Deploying hungrctl systemd timer..."

cat <<EOF > "$timer_dest"
[Unit]
Description=Run HungrCTL every minute

[Timer]
OnBootSec=0sec
OnUnitActiveSec=1min
AccuracySec=1sec
Persistent=true

[Install]
WantedBy=timers.target
EOF
chmod 600 "$timer_dest"
chown root:root "$timer_dest"
chattr +i "$timer_dest"
log_ok "Deployed and locked $timer_file"

# ===== Step 3: Lock down hungrctl directory =====
echo "[*] Locking down hungrctl directory..."

# Protect everything by default
chmod -R 700 "$ROOT_DIR"
chown -R root:root "$ROOT_DIR"

# Allow config & output to remain visible
chmod 600 "$ROOT_DIR/config.sh"
chmod 755 "$ROOT_DIR/output"

# Lock check scripts & main script
find "$ROOT_DIR/service_checks" -type f -exec chattr +i {} \;
chattr +i "$ROOT_DIR/hungrctl"
chattr +i "$ROOT_DIR/service_checks"

# ===== Step 4: Reload systemd and enable timer =====
echo "[*] Reloading systemd and enabling $timer_dest..."

systemctl daemon-reexec
systemctl enable --now "$timer_dest"
log_ok "Enabled and started $timer_dest"