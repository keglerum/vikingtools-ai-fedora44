#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo vt-add-admin-key [PUBLIC_KEY_FILE.pub]' >&2; exit 1; }
ADMIN=$(cat /var/lib/vikingtools-setup/admin)
[[ $ADMIN =~ ^[a-z_][a-z0-9_-]*$ ]]
ADMIN_HOME=$(getent passwd "$ADMIN" | cut -d: -f6)
[[ $ADMIN_HOME == /home/* && -d $ADMIN_HOME && ! -L $ADMIN_HOME ]]
if [[ $# == 0 ]]; then
  read -rp "Paste your other computer's SSH PUBLIC key (one line): " PUBKEY
elif [[ $# == 1 && -f $1 ]]; then
  [[ $(wc -l < "$1") -le 1 ]] || { echo 'Supply one public key.' >&2; exit 1; }
  PUBKEY=$(cat -- "$1")
else echo 'Usage: sudo vt-add-admin-key [PUBLIC_KEY_FILE.pub]' >&2; exit 1; fi
[[ $PUBKEY == ssh-ed25519\ * || $PUBKEY == ssh-rsa\ * || $PUBKEY == ecdsa-sha2-* ]] || { echo 'Unsupported public key format.' >&2; exit 1; }
TEMP_KEY=$(mktemp)
trap 'rm -f -- "$TEMP_KEY"' EXIT
printf '%s\n' "$PUBKEY" > "$TEMP_KEY"
ssh-keygen -lf "$TEMP_KEY"
install -d -m 700 -o "$ADMIN" -g "$(id -gn "$ADMIN")" "$ADMIN_HOME/.ssh"
AUTH_KEYS="$ADMIN_HOME/.ssh/authorized_keys"
[[ ! -L $AUTH_KEYS ]]
touch "$AUTH_KEYS"
rg -qxF -- "$PUBKEY" "$AUTH_KEYS" || printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
chown "$ADMIN:$(id -gn "$ADMIN")" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
restorecon -RF "$ADMIN_HOME/.ssh"
echo 'Admin key installed. SSH over Tailscale can now use the matching private key on your other computer.'
