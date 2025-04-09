#!/bin/bash

# This script is used to initialize the hungrctl service.
# It will install the necessary dependencies and configure the service.

# ===== Configuration =====
service_dest="/etc/systemd/system/hungrctl.service"
timer_dest="/etc/systemd/system/hungrctl.timer"
watchdog_dest="/etc/systemd/system/hungrctl-watchdog.service"
watchdog_timer_dest="/etc/systemd/system/hungrctl-watchdog.timer"

# ===== Source environment and logging =====
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib/env.sh"

# ===== This script must be run as root =====
if [ "$EUID" -ne 0 ]; then
    log_fail "This script must be run as root"
    exit 1
fi

# ===== Ensure scripts are executable =====
chmod +x "$ROOT_DIR/hungrctl"
chmod +x "$ROOT_DIR/watchdog"
chmod -R +x "$ROOT_DIR/service_checks"
chmod -R +x "$ROOT_DIR/lib"

log_info "[*] Starting hungrctl system initialization..."

# ===== Step 0: Remove existing service and timer =====
for service in "$service_dest" "$timer_dest" "$watchdog_dest" "$watchdog_timer_dest"; do
    chattr -i "$service" 2>/dev/null
    rm -f "$service"
done

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
log_ok "Deployed and locked $service_dest"

# ===== Step 2: Deploy systemd timer =====
echo "[*] Deploying hungrctl systemd timer..."

cat <<EOF > "$timer_dest"
[Unit]
Description=Run HungrCTL every minute

[Timer]
OnBootSec=0sec
OnUnitActiveSec=1min
AccuracySec=1sec

[Install]
WantedBy=timers.target
EOF
chmod 600 "$timer_dest"
chown root:root "$timer_dest"
chattr +i "$timer_dest"
log_ok "Deployed and locked $timer_dest"

# ===== Step 3: Create watchdog service =====
echo "[*] Creating watchdog service..."

cat <<EOF > "$watchdog_dest"
[Unit]
Description=Watchdog for HungrCTL service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$ROOT_DIR/watchdog
User=root
EOF
chmod 600 "$watchdog_dest"
chown root:root "$watchdog_dest"
chattr +i "$watchdog_dest"
log_ok "Deployed and locked $watchdog_dest"

# ===== Step 4: Create watchdog timer =====
echo "[*] Creating watchdog timer..."

cat <<EOF > "$watchdog_timer_dest"
[Unit]
Description=Run HungrCTL watchdog every 1 minute

[Timer]
OnBootSec=30sec
OnUnitActiveSec=1min
AccuracySec=1sec

[Install]
WantedBy=timers.target
EOF
chmod 600 "$watchdog_timer_dest"
chown root:root "$watchdog_timer_dest"
chattr +i "$watchdog_timer_dest"
log_ok "Deployed and locked $watchdog_timer_dest"

# ===== Step 5: Lock down hungrctl directory =====
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
chattr +i "$ROOT_DIR/init_hungrctl.sh"
chattr +i "$ROOT_DIR/watchdog"

# ===== Step 6: Reload systemd and enable timers =====
echo "[*] Reloading systemd and enabling $timer_dest..."

systemctl daemon-reload
systemctl enable --now "$timer_dest"
systemctl enable --now "$watchdog_timer_dest"
log_ok "Enabled and started $timer_dest and $watchdog_timer_dest"

log_info "[o7] hungrctl fully initialized and secured."