#!/usr/bin/env bash
# Readiness checks and normal Fedora network-time synchronization; no driver changes.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]] || { echo 'Requires Fedora 44 x86_64 desktop.' >&2; exit 1; }
echo 'Checking the system clock before HTTPS downloads.'
if command -v timedatectl >/dev/null; then
  timedatectl set-ntp true || echo 'Automatic time synchronization could not be enabled.'
  for _attempt in 1 2 3 4 5; do
    [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null || true) == yes ]] && break
    sleep 1
  done
  timedatectl status || true
fi
[[ $(date +%Y) -ge 2026 ]] || { echo 'Clock is earlier than 2026. Correct Date & Time before continuing.' >&2; exit 1; }
echo 'HTTPS certificates will be verified. Certificate errors are never bypassed.'
AVAILABLE_KB=$(df -Pk /var/lib | awk 'NR==2 {print $4}')
[[ $AVAILABLE_KB =~ ^[0-9]+$ && $AVAILABLE_KB -ge 15728640 ]] || { echo 'At least 15 GiB free space is needed for setup downloads and packages. Models need additional space.' >&2; exit 1; }
