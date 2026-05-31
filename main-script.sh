#!/bin/bash

# 1. Strict Root Check
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root!"
  exit 1
fi

# 2. Pre-create directories to prevent debconf prompts
mkdir -p /etc/apt/apt.conf.d
mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d/

# 3. Pre-configure 20auto-upgrades (This kills the blue interactive window)
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 4. Configure 50unattended-upgrades
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

# 5. Force total non-interactive mode for APT/DPKG
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 6. Seed debconf database just in case
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections

# 7. Update and Install packages silently
apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" unattended-upgrades apt-listchanges

# 8. Set systemd timer to midnight (00:00) with 0 delay
cat > /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf << 'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=0
EOF

# 9. Reload systemd and enable timers
systemctl daemon-reload
systemctl restart apt-daily-upgrade.timer
systemctl enable apt-daily.timer --now
systemctl enable apt-daily-upgrade.timer --now

# 10. Verification and Dry-run
unattended-upgrades --dry-run --debug
systemctl list-timers apt-daily-upgrade.timer
