#!/usr/bin/env bash
set -uo pipefail
printf 'Hardware\n'
lspci -nn | rg -i 'VGA|3D|Display'
free -h
df -h /var/lib
mokutil --sb-state
command -v nvidia-smi >/dev/null && nvidia-smi
printf '\nServices\n'
systemctl --no-pager --full status tailscaled vikingtools-ssh vncserver@:1 ollama vikingtools-help-network vikingtools-support || true
printf '\nListeners (SSH must use 100.x; VNC and AI must use loopback)\n'
ss -ltnp | rg ':(22|5901|8088|11434)\b'
printf '\nPrivate health\n'
curl -fsS http://127.0.0.1:8088/health
printf '\nLoaded models\n'
OLLAMA_HOST=127.0.0.1:11434 ollama ps
printf '\nCustomer process firewall\n'
nft list table inet vt_help
