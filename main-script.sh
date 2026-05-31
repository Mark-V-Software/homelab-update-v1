#!/bin/bash

# 1. Strict Root Check
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root!"
  exit 1
fi

# 2. Total purge of any old debconf selections for this package
apt-get remove --purge -y unattended-upgrades apt-listchanges || true
debconf-communicate <<EOF
PURGE unattended-upgrades
EOF

# 3. Pre-create directories
mkdir -p /etc/apt/apt.conf.d
mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d/

# 4. Force frontend to noninteractive in all possible system configs
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export NEEDRESTART_MODE=a

# 5. Set debconf selections directly into the database with high priority
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
echo "unattended-upgrades unattended-upgrades/enable_auto_updates seen true" | debconf-set-selections

# 6. Install packages with absolute overwrite flags
apt-get update
apt-get install -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confmiss" unattended-upgrades apt-listchanges

# 7. Configure 20auto-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 8. Configure 50unattended-upgrades
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

# 9. Set systemd timer to midnight (00:00) with 0 delay
cat > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=0
EOF

# 10. Reload systemd and enable timers
systemctl daemon-reload
systemctl restart apt-daily-upgrade.timer
systemctl enable apt-daily.timer --now
systemctl enable apt-daily-upgrade.timer --now

# 11. Verification and Dry-run
unattended-upgrades --dry-run --debug
systemctl list-timers apt-daily-upgrade.timer
