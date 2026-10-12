#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
MODEL=${1:-}
[[ $MODEL =~ ^[a-zA-Z0-9][a-zA-Z0-9._:-]*$ && $MODEL != *cloud* ]] || { echo 'Supply a local Ollama model name (no cloud models).' >&2; exit 1; }
echo 'Downloading and testing the selected local model. Large models require substantial disk space.'
OLLAMA_HOST=127.0.0.1:11434 ollama pull "$MODEL"
OLLAMA_HOST=127.0.0.1:11434 ollama run "$MODEL" 'Reply with the word ready.'
OLLAMA_HOST=127.0.0.1:11434 ollama ps
echo 'Check GPU usage above and review both GPUs with vt-diagnostics.'
read -rp 'Have you reviewed GPU usage and the public help text, and want to enable private answers? Type ENABLE: ' READY
[[ $READY == ENABLE ]] || exit 0
python3 - "$MODEL" <<'PY'
import json, os, sys, tempfile
from pathlib import Path
p = Path('/etc/vikingtools-ai/settings.json')
with tempfile.NamedTemporaryFile(mode='w', dir=p.parent, delete=False) as f:
    json.dump({'enabled': True, 'model': sys.argv[1]}, f)
    name = f.name
os.chown(name, 0, p.stat().st_gid)
os.chmod(name, 0o640)
os.replace(name, p)
PY
restorecon /etc/vikingtools-ai/settings.json
systemctl restart vikingtools-support
echo 'Private assistant enabled. Public website connection is a separate deployment.'
