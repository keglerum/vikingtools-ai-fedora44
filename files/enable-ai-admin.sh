#!/usr/bin/env bash
# Explicit admin-operated switch for unattended privileged commands in the admin session.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
ADMIN=$(cat /var/lib/vikingtools-setup/admin)
[[ $ADMIN =~ ^[a-z_][a-z0-9_-]*$ ]]
if [[ ${1:-} == --disable ]]; then
  rm -f /etc/sudoers.d/vikingtools-ai-admin
  echo 'Passwordless AI/admin sudo disabled.'
  exit 0
fi
FILE=$(mktemp /etc/sudoers.d/.vt-admin.XXXXXX)
trap 'rm -f "$FILE"' EXIT
printf '%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$ADMIN" > "$FILE"
chmod 440 "$FILE"
visudo -cf "$FILE"
mv "$FILE" /etc/sudoers.d/vikingtools-ai-admin
restorecon /etc/sudoers.d/vikingtools-ai-admin
echo "Full sudo control enabled for $ADMIN and programs running as that account."
echo 'Select Full access in your trusted ChatGPT/Codex admin project if desired.'
echo 'Customers must never have access to that account or that project.'
