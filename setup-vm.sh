#!/bin/bash
set -euo pipefail
umask 077

VPN_USER=amnezia
SSH_PORT=3568
IGNORE_IPS="127.0.0.1/8 ::1 92.38.32.98/32 158.160.0.0/16 94.249.187.243/32"
BANTIME=24h
FINDTIME=1h
MAXRETRY=3

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KEY="$SCRIPT_DIR/amnezia.key"
SSH_CONFIG=/etc/ssh/sshd_config.d/00-amnezia.conf

say() { printf '\033[1;36m%s\033[0m\n' "$*"; }
info() { printf '\n'; say "$*"; }
fail() { printf '\n\033[1;31m%s\033[0m\n' "$*" >&2; exit 1; }
ask() { read -r -p $'\n\033[1;33m'"$1"$'\033[0m' answer; }

[[ $EUID -eq 0 ]] || fail 'Run as root'
[[ $SSH_PORT =~ ^[0-9]+$ ]] && (( 10#$SSH_PORT >= 1 && 10#$SSH_PORT <= 65535 )) || fail 'Invalid SSH port'
[[ -f "$SCRIPT_DIR/install_fail2ban.sh" ]] || fail 'install_fail2ban.sh not found'

systemctl stop apt-daily.timer apt-daily-upgrade.timer

if id "$VPN_USER" >/dev/null 2>&1 || [[ -e $KEY ]]; then
    [[ -f $KEY && -f "/home/$VPN_USER/.ssh/authorized_keys" ]] ||
        fail 'Existing user or key does not match a previous setup.'
    public_key=$(ssh-keygen -y -P '' -f "$KEY")
    read -r key_type key_data _ <<< "$public_key"
    awk -v type="$key_type" -v data="$key_data" '$1 == type && $2 == data { found=1 } END { exit !found }' \
        "/home/$VPN_USER/.ssh/authorized_keys" || fail 'The key does not match the existing user.'
    sudo -u "$VPN_USER" sudo -n true || fail 'Passwordless sudo is unavailable.'
    info 'Continuing previous setup.'
else
    apt update
    apt full-upgrade -y
    apt install -y sudo openssh-server
    adduser --disabled-password --gecos '' "$VPN_USER"
    usermod -aG sudo "$VPN_USER"
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$VPN_USER" > "/etc/sudoers.d/$VPN_USER"
    chmod 440 "/etc/sudoers.d/$VPN_USER"
    visudo -c

    ssh-keygen -q -t ed25519 -C "$VPN_USER@$(hostname)" -f "$KEY" -N ''
    install -d -o "$VPN_USER" -g "$VPN_USER" -m 700 "/home/$VPN_USER/.ssh"
    install -o "$VPN_USER" -g "$VPN_USER" -m 600 "$KEY.pub" "/home/$VPN_USER/.ssh/authorized_keys"
fi

mkdir -p /run/sshd
current_port=$(sshd -T | awk '$1 == "port" { port = $2 } END { print port }')
ssh -n -i "$KEY" -p "$current_port" -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$VPN_USER@127.0.0.1" sudo -n true ||
    fail 'Key login or passwordless sudo check failed.'
info 'Key login and passwordless sudo verified.'

info '==================== PRIVATE KEY ===================='
echo
cat "$KEY"
echo
say '====================================================='
say 'Copy the key (BEGIN and END lines included) into the Amnezia client and a password manager.'
ask 'Type y after saving the key: '
[[ $answer == y ]] || fail 'Stopped before changing SSH settings.'

if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
    ufw allow "$SSH_PORT/tcp"
fi

ssh_config_ok() {
    local cfg
    cfg=$(sshd -T) || return 1
    [[ $(grep '^port ' <<< "$cfg") == "port $SSH_PORT" ]] &&
        grep -qx 'passwordauthentication no' <<< "$cfg" &&
        grep -qx 'kbdinteractiveauthentication no' <<< "$cfg"
}

if [[ -e $SSH_CONFIG ]]; then
    ssh_config_ok || fail 'Existing SSH configuration does not match the setup.'
    info 'SSH configuration already applied.'
else
backup_dir=$(mktemp -d)
config_files=()
for file in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
    [[ -f $file ]] || continue
    if grep -Eqi '^[[:space:]]*Port[[:space:]]+' "$file"; then
        config_files+=("$file")
        cp -p "$file" "$backup_dir/${#config_files[@]}"
        sed -i -E '/^[[:space:]]*[Pp][Oo][Rr][Tt][[:space:]]+/d' "$file"
    fi
done
cat > "$SSH_CONFIG" <<EOF
Port $SSH_PORT
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
EOF
restore_ssh() {
    rm -f "$SSH_CONFIG"
    for i in "${!config_files[@]}"; do
        cp -p "$backup_dir/$((i + 1))" "${config_files[$i]}"
    done
    rm -rf "$backup_dir"
}
if ! sshd -t || ! ssh_config_ok; then
    restore_ssh
    fail 'SSH configuration check failed; changes removed.'
fi
socket_active=false
systemctl is-active --quiet ssh.socket && socket_active=true
if ! systemctl daemon-reload || \
   { [[ $socket_active == true ]] && ! systemctl restart ssh.socket; } || \
   ! systemctl restart ssh.service; then
    restore_ssh
    systemctl daemon-reload
    if [[ $socket_active == true ]]; then systemctl restart ssh.socket; fi
    systemctl restart ssh.service
    fail 'Failed to apply SSH configuration; previous configuration restored.'
fi
rm -rf "$backup_dir"
fi

bash "$SCRIPT_DIR/install_fail2ban.sh" "$SSH_PORT" "$IGNORE_IPS" "$BANTIME" "$FINDTIME" "$MAXRETRY"

info "Connect in another terminal as $VPN_USER on port $SSH_PORT using the copied key.
Keep this session open until the new connection works."
ask 'Type yes after verifying the new connection to remove the server copy of the key: '
if [[ $answer == yes ]]; then
    rm -f "$KEY" "$KEY.pub"
    info 'Setup completed; server copy of the key removed.'
else
    info "Setup completed; remove $KEY and $KEY.pub after verifying the connection."
fi