#!/bin/bash

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Root, please"
  exit 1
fi

# Install package
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
apt install -y unattended-upgrades apt-listchanges

# Reconfigure
dpkg-reconfigure -plow unattended-upgrades

# Create folder because I don't want to transform system directory into a mess
LOCAL_BACKUP_FOLDER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backup"
mkdir -pv "$LOCAL_BACKUP_FOLDER"

# Backup
LOCAL_BACKUP_FILE="$LOCAL_BACKUP_FOLDER/50unattended-upgrades"
cp -a /etc/apt/apt.conf.d/50unattended-upgrades "$LOCAL_BACKUP_FILE"

# 50unattended-upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
        // origin * means every repo
        "origin=*";
};

// autoremove
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// reboot when everyone is logged out
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "now";
EOF

# 20auto-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# apt-daily-upgrade.timer.d
mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d/

cat << 'EOF' > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf
[Timer]
OnCalendar=
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=0
EOF

# Restart & Reload
systemctl daemon-reload
systemctl restart apt-daily-upgrade.timer

systemctl enable apt-daily.timer --now
systemctl enable apt-daily-upgrade.timer --now

# Tryout
unattended-upgrades --dry-run --debug

# See Timer
systemctl list-timers apt-daily-upgrade.timer
