#!/bin/bash
set -euo pipefail

SSH_PORT=${1:?SSH port is required}
IGNORE_IPS=${2:?Ignored IP addresses are required}
BANTIME=${3:?Ban time is required}
FINDTIME=${4:?Find time is required}
MAXRETRY=${5:?Maximum attempts are required}
CONFIG=/etc/fail2ban/jail.local

apt install -y fail2ban
systemctl enable fail2ban

if [[ -f $CONFIG ]]; then
    cp "$CONFIG" "$CONFIG.bak.$(date +%F_%H-%M-%S)"
fi

cat > "$CONFIG" <<EOF
[DEFAULT]
ignoreip = $IGNORE_IPS
bantime = $BANTIME
findtime = $FINDTIME
maxretry = $MAXRETRY

[sshd]
enabled = true
port = $SSH_PORT
backend = systemd
EOF

fail2ban-client -t
systemctl restart fail2ban
for _ in {1..30}; do
    fail2ban-client status sshd >/dev/null 2>&1 && break
    sleep 1
done
fail2ban-client status sshd
