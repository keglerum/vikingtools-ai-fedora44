#!/usr/bin/env bash
# Start the complete downloaded/USB bundle without Git or any preinstalled AI apps.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run: sudo bash START-HERE.sh' >&2; exit 1; }
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
(cd "$BASE" && sha256sum -c SHA256SUMS)
umask 077
TARGET=/var/lib/vikingtools-setup/source
install -d -m 700 "$TARGET"
if [[ $BASE != "$TARGET" ]]; then cp -a "$BASE/." "$TARGET/"; fi
bash "$TARGET/setup.sh" "$@"
