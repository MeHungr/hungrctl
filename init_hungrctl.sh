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

# ===== Function to safely set immutable attributes =====
safe_set_immutable() {
    local target="$1"
    if [ -e "$target" ]; then
        if [ -f "$target" ]; then
            chattr +i "$target" 2>/dev/null || log_warn "Failed to set immutable attribute on $target"
        elif [ -d "$target" ]; then
            find "$target" -type f -exec chattr +i {} \; 2>/dev/null || log_warn "Failed to set immutable attributes on files in $target"
            chattr +i "$target" 2>/dev/null || log_warn "Failed to set immutable attribute on directory $target"
        fi
    fi
}

# ===== Step 0: Set initial permissions =====
echo "[*] Setting initial permissions..."

# Set permissions for main scripts
for script in "$ROOT_DIR/hungrctl" "$ROOT_DIR/watchdog"; do
    if [ -f "$script" ]; then
        chmod 700 "$script" || log_fail "Failed to set permissions on $script"
        chown root:root "$script" || log_fail "Failed to set ownership on $script"
    else
        log_fail "Required script $script not found"
        exit 1
    fi
done

# ===== Step 0.5: Symlink hungrctl globally =====
echo "[*] Creating symlink for hungrctl..."
if [ -f "$ROOT_DIR/hungrctl" ]; then
    ln -sf "$ROOT_DIR/hungrctl" /usr/local/bin/hungrctl
    log_ok "Symlink created at /usr/local/bin/hungrctl"
else
    log_warn "hungrctl not found — skipping symlink"
fi

# Set permissions for service checks and lib
chmod -R 700 "$ROOT_DIR/service_checks" || log_fail "Failed to set permissions on service_checks"
chmod -R 700 "$ROOT_DIR/lib" || log_fail "Failed to set permissions on lib directory"
chown -R root:root "$ROOT_DIR/service_checks" || log_fail "Failed to set ownership on service_checks"
chown -R root:root "$ROOT_DIR/lib" || log_fail "Failed to set ownership on lib directory"

# Set permissions for config and output
chmod 600 "$ROOT_DIR/config.sh" 2>/dev/null || log_warn "Failed to set config.sh permissions"
chmod -R 644 "$OUTPUT_DIR" 2>/dev/null || log_warn "Failed to set output directory permissions"
chmod -R 644 "$LOG_DIR" "$SUMMARY_DIR" 2>/dev/null || log_warn "Failed to set log/summary directory permissions"
chown -R root:root "$ROOT_DIR/config.sh" 2>/dev/null || true
chown -R root:root "$OUTPUT_DIR" 2>/dev/null || true

log_info "[*] Starting hungrctl system initialization..."

# ===== Step 1: Remove existing service and timer =====
echo "[*] Cleaning up existing services..."
for service in "$service_dest" "$timer_dest" "$watchdog_dest" "$watchdog_timer_dest"; do
    if [ -f "$service" ]; then
        chattr -i "$service" 2>/dev/null
        rm -f "$service" || log_warn "Failed to remove existing $service"
    fi
done

# ===== Step 2: Deploy systemd service =====
echo "[*] Deploying hungrctl systemd service..."

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
Restart=no
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

chmod 600 "$service_dest" || log_fail "Failed to set permissions on $service_dest"
chown root:root "$service_dest" || log_fail "Failed to set ownership on $service_dest"
safe_set_immutable "$service_dest"
log_ok "Deployed and locked $service_dest"

# ===== Step 3: Deploy systemd timer =====
echo "[*] Deploying hungrctl systemd timer..."

cat <<EOF > "$timer_dest"
[Unit]
Description=Run HungrCTL every minute

[Timer]
OnBootSec=0sec
OnUnitActiveSec=1min
AccuracySec=1sec
RandomizedDelaySec=3

[Install]
WantedBy=timers.target
EOF

chmod 600 "$timer_dest" || log_fail "Failed to set permissions on $timer_dest"
chown root:root "$timer_dest" || log_fail "Failed to set ownership on $timer_dest"
safe_set_immutable "$timer_dest"
log_ok "Deployed and locked $timer_dest"

# ===== Step 4: Create watchdog service =====
echo "[*] Creating watchdog service..."

cat <<EOF > "$watchdog_dest"
[Unit]
Description=Watchdog for HungrCTL service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=$ROOT_DIR/watchdog
User=root
Restart=no
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

chmod 600 "$watchdog_dest" || log_fail "Failed to set permissions on $watchdog_dest"
chown root:root "$watchdog_dest" || log_fail "Failed to set ownership on $watchdog_dest"
safe_set_immutable "$watchdog_dest"
log_ok "Deployed and locked $watchdog_dest"

# ===== Step 5: Create watchdog timer =====
echo "[*] Creating watchdog timer..."

cat <<EOF > "$watchdog_timer_dest"
[Unit]
Description=Run HungrCTL watchdog every 1 minute

[Timer]
OnBootSec=30sec
OnUnitActiveSec=1min
AccuracySec=1sec
RandomizedDelaySec=3

[Install]
WantedBy=timers.target
EOF

chmod 600 "$watchdog_timer_dest" || log_fail "Failed to set permissions on $watchdog_timer_dest"
chown root:root "$watchdog_timer_dest" || log_fail "Failed to set ownership on $watchdog_timer_dest"
safe_set_immutable "$watchdog_timer_dest"
log_ok "Deployed and locked $watchdog_timer_dest"

# ===== Step 6: Lock down hungrctl directory =====
echo "[*] Locking down hungrctl directory..."

# Protect everything by default
chmod -R 700 "$ROOT_DIR" || log_fail "Failed to set directory permissions"
chown -R root:root "$ROOT_DIR" || log_fail "Failed to set directory ownership"

# Allow config & output to remain visible
chmod 600 "$ROOT_DIR/config.sh" 2>/dev/null || log_warn "Failed to set config.sh permissions"
chmod -R 600 "$OUTPUT_DIR" 2>/dev/null || log_warn "Failed to set output directory permissions"
chmod -R 666 "$LOG_DIR" "$SUMMARY_DIR" 2>/dev/null || log_warn "Failed to set log/summary directory permissions"

# Lock check scripts & main script
safe_set_immutable "$ROOT_DIR/service_checks"
safe_set_immutable "$ROOT_DIR/lib"
safe_set_immutable "$ROOT_DIR/hungrctl"
safe_set_immutable "$ROOT_DIR/watchdog"
safe_set_immutable "$ROOT_DIR/init_hungrctl.sh"
safe_set_immutable "$service_dest"
safe_set_immutable "$timer_dest"
safe_set_immutable "$watchdog_dest"
safe_set_immutable "$watchdog_timer_dest"

# ===== Step 7: Reload systemd and enable timers =====
echo "[*] Reloading systemd and enabling services..."

systemctl daemon-reload || log_fail "Failed to reload systemd"

for timer in "$timer_dest" "$watchdog_timer_dest"; do
    if [ -f "$timer" ]; then
        systemctl enable --now "$(basename "$timer")" || log_fail "Failed to enable $(basename "$timer")"
    fi
done

# ===== Step 8: Add fallback cron jobs =====
echo "[*] Installing cron fallback jobs..."

hungrctl_cron="/etc/cron.d/run_cron"
watchdog_cron="/etc/cron.d/fallback_cron"

cat <<EOF > "$hungrctl_cron"
*/3 * * * * root systemctl is-enabled hungrctl.timer &>/dev/null || systemctl enable --now hungrctl.timer >> /var/log/run_cron.log 2>&1
EOF

cat <<EOF > "$watchdog_cron"
*/5 * * * * root systemctl is-enabled hungrctl-watchdog.timer &>/dev/null || systemctl enable --now hungrctl-watchdog.timer >> /var/log/fallback_cron.log 2>&1
EOF

chmod 644 "$hungrctl_cron" "$watchdog_cron"
chown root:root "$hungrctl_cron" "$watchdog_cron"

# Optional: Make them immutable
safe_set_immutable "$hungrctl_cron"
safe_set_immutable "$watchdog_cron"

log_ok "Cron fallbacks installed at:"
log_info "  $hungrctl_cron"
log_info "  $watchdog_cron"

# ===== Step 9: Lock down this script =====
safe_set_immutable "$ROOT_DIR/init_hungrctl.sh"
chmod 700 "$ROOT_DIR/init_hungrctl.sh"
chown root:root "$ROOT_DIR/init_hungrctl.sh"


log_info "[V] hungrctl fully initialized and secured."