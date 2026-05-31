#!/bin/bash

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Root, please"
  exit 1
fi

# Set time 
TZ=$(curl -fsSL https://ipinfo.io/timezone)

if [ -n "$TZ" ]; then
    timedatectl set-timezone "$TZ"
fi

# homelab-update.service
cat > /etc/systemd/system/homelab-update.service <<'EOF'
[Unit]
Description=Homelab Update Script
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '\
DEBIAN_FRONTEND=noninteractive apt update && \
DEBIAN_FRONTEND=noninteractive apt -y upgrade && \
apt -y autoremove && \
[ -f /var/run/reboot-required ] && reboot || true'
EOF

# homelab-update.timer
cat > /etc/systemd/system/homelab-update.timer <<'EOF'
[Unit]
Description=Homelab Update Timer

[Timer]
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload
systemctl daemon-reload
systemctl enable --now homelab-update.timer

# Check
systemctl list-timers
