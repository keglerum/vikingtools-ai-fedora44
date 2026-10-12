#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 && $# == 1 ]] || { echo 'Usage: sudo vt-import-help reviewed-public-help.txt' >&2; exit 1; }
[[ -f $1 && ! -L $1 && $1 == *.txt ]] || { echo 'Supply a reviewed regular .txt file.' >&2; exit 1; }
[[ $(stat -c %s -- "$1") -le 100000 ]] || { echo 'Help file exceeds 100 KB.' >&2; exit 1; }
NAME=$(basename -- "$1")
[[ $NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*\.txt$ ]]
python3 - "$1" <<'PY'
import pathlib, sys
pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
PY
install -m 640 -o root -g vt-help -- "$1" "/var/lib/vikingtools-ai/knowledge/$NAME"
restorecon "/var/lib/vikingtools-ai/knowledge/$NAME"
echo 'Approved knowledge installed. New answers use it immediately.'
