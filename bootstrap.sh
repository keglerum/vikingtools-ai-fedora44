#!/usr/bin/env bash
# Fresh-install entry point. Requires only Fedora's built-in bash, sudo and DNF.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo bash bootstrap.sh' >&2; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]] || { echo 'Requires Fedora 44 x86_64 desktop.' >&2; exit 1; }
[[ -z ${SSH_CONNECTION:-} ]] || { echo 'Run initial setup at the new computer.' >&2; exit 1; }
umask 077
echo 'Enabling normal network time synchronization before downloading.'
timedatectl set-ntp true || true
for _attempt in 1 2 3 4 5; do
  [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null || true) == yes ]] && break
  sleep 1
done
date --iso-8601=seconds
[[ $(date +%Y) -ge 2026 ]] || { echo 'Correct the system date before continuing.' >&2; exit 1; }
dnf -y install curl ca-certificates tar gzip
WORK=$(mktemp -d /var/tmp/vikingtools-bootstrap.XXXXXX)
trap 'rm -rf -- "$WORK"' EXIT
curl --retry 3 --retry-delay 2 --connect-timeout 20 --proto '=https' --tlsv1.2 -fL \
  https://github.com/keglerum/vikingtools-ai-fedora44/archive/refs/heads/main.tar.gz \
  -o "$WORK/source.tar.gz"
tar -xzf "$WORK/source.tar.gz" -C "$WORK"
SOURCE="$WORK/vikingtools-ai-fedora44-main"
[[ -f $SOURCE/setup.sh && -f $SOURCE/SHA256SUMS ]]
(cd "$SOURCE" && sha256sum -c SHA256SUMS)
# Keep a local copy for ChatGPT and any later retry after a partial installation.
install -d -m 700 /var/lib/vikingtools-setup/source
cp -a "$SOURCE/." /var/lib/vikingtools-setup/source/
bash /var/lib/vikingtools-setup/source/setup.sh "$@"
