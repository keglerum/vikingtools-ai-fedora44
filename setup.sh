#!/usr/bin/env bash
# Run only on the NEW dedicated Fedora 44 computer, from its local terminal.
set -Eeuo pipefail
umask 077
trap 'echo "Setup stopped at line $LINENO. Fix the reported error, then rerun. No automatic reboot." >&2' ERR
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]] || { echo 'Requires Fedora 44 x86_64.' >&2; exit 1; }
[[ -z ${SSH_CONNECTION:-} ]] || { echo 'Initial setup must run at the local computer, to avoid remote lockout.' >&2; exit 1; }
BASE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ADMIN=${SUDO_USER:-}
if [[ -z $ADMIN || $ADMIN == root ]]; then read -rp 'Existing Fedora admin username: ' ADMIN; fi
[[ $ADMIN =~ ^[a-z_][a-z0-9_-]*$ ]] && id "$ADMIN" >/dev/null
[[ " $(id -nG "$ADMIN") " == *" wheel "* ]] || { echo 'Choose the existing Fedora wheel/admin account.' >&2; exit 1; }
OTHER_ADMINS=$(getent group wheel | cut -d: -f4 | tr ',' '\n' | sed "/^$ADMIN$/d; /^$/d")
[[ -z $OTHER_ADMINS ]] || { echo "Other wheel members exist: $OTHER_ADMINS. Review them first." >&2; exit 1; }
ADMIN_HOME=$(getent passwd "$ADMIN" | cut -d: -f6)
[[ $ADMIN_HOME == /home/* && -d $ADMIN_HOME && ! -L $ADMIN_HOME ]]
# A public key is optional during first installation; password login stays disabled.
KEY=${1:-}
if [[ -n $KEY && ! -f $KEY ]]; then echo 'Public key file not found.' >&2; exit 1; fi
INSTALL_MARKER=/var/lib/vikingtools-setup
mkdir -p "$INSTALL_MARKER"
if [[ -f $INSTALL_MARKER/admin ]]; then [[ $(cat "$INSTALL_MARKER/admin") == "$ADMIN" ]]; fi
printf '%s\n' "$ADMIN" > "$INSTALL_MARKER/admin"
BACKUP="$INSTALL_MARKER/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP"
for p in /etc/ssh/sshd_config /etc/tigervnc /etc/systemd/system/ollama.service.d /etc/vikingtools-ai; do
  [[ ! -e $p ]] || cp -a --parents "$p" "$BACKUP/"
done

echo 'Installing admin tools, private remote desktop, and monitoring.'
dnf -y upgrade --refresh
dnf -y install curl ca-certificates git git-lfs openssh-server openssh-clients firewalld nftables \
  python3 python3-pip nodejs npm ripgrep jq tmux rsync unzip tar zstd htop \
  pciutils usbutils lsof strace sysstat smartmontools lm_sensors mokutil \
  podman buildah gcc gcc-c++ make shellcheck policycoreutils-python-utils \
  tigervnc-server tigervnc xfce4-session xfce4-panel xfce4-settings xfwm4 xfdesktop \
  thunar xfce4-terminal firefox xorg-x11-xauth mesa-dri-drivers mesa-vulkan-drivers vulkan-tools
systemctl enable --now firewalld
# Keep Fedora's enforcing SELinux policy. Do not weaken it for remote access.
[[ $(getenforce) == Enforcing ]] || { echo 'SELinux must be Enforcing. Restore it before continuing.' >&2; exit 1; }

if ! rpm -q tailscale >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -fsSL https://pkgs.tailscale.com/stable/fedora/tailscale.repo -o /etc/yum.repos.d/tailscale.repo
  dnf -y install tailscale
fi
systemctl enable --now tailscaled
# Use OpenSSH keys over Tailscale, not the separate Tailscale SSH authentication service.
tailscale set --ssh=false
if ! tailscale ip -4 >/dev/null 2>&1; then
  echo 'Sign into YOUR admin Tailscale account using the URL shown next.'
  tailscale up --ssh=false
fi
TS_IP=$(tailscale ip -4)
[[ $TS_IP =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]]

install -d -m 700 -o "$ADMIN" -g "$(id -gn "$ADMIN")" "$ADMIN_HOME/.ssh"
AUTH_KEYS="$ADMIN_HOME/.ssh/authorized_keys"
[[ ! -L $AUTH_KEYS ]]
touch "$AUTH_KEYS"
if [[ -n $KEY ]]; then
  ssh-keygen -lf "$KEY" >/dev/null
  [[ $(wc -l < "$KEY") -le 1 ]] || { echo 'Supply one public key.' >&2; exit 1; }
  PUBKEY=$(cat -- "$KEY")
  [[ $PUBKEY == ssh-ed25519\ * || $PUBKEY == ssh-rsa\ * || $PUBKEY == ecdsa-sha2-* ]]
  rg -qxF -- "$PUBKEY" "$AUTH_KEYS" || printf '%s\n' "$PUBKEY" >> "$AUTH_KEYS"
else
  echo 'SSH key deferred. Remote login stays unavailable until an admin key is added.'
fi
chown "$ADMIN:$(id -gn "$ADMIN")" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
restorecon -RF "$ADMIN_HOME/.ssh"
# Dedicated configuration avoids earlier Include/Match directives overriding security.
cat > /etc/ssh/vikingtools_sshd_config <<SSH
Port 22
ListenAddress $TS_IP
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers $ADMIN
UsePAM yes
X11Forwarding no
AllowTcpForwarding local
GatewayPorts no
PermitTunnel no
LogLevel VERBOSE
Subsystem sftp internal-sftp
SSH
ssh-keygen -A
sshd -t -f /etc/ssh/vikingtools_sshd_config
cat > /etc/systemd/system/vikingtools-ssh.service <<'UNIT'
[Unit]
Description=Admin SSH bound only to the Tailscale address
After=network-online.target tailscaled.service
Wants=network-online.target
Requires=tailscaled.service
[Service]
ExecStartPre=/usr/sbin/sshd -t -f /etc/ssh/vikingtools_sshd_config
ExecStart=/usr/sbin/sshd -D -f /etc/ssh/vikingtools_sshd_config
Restart=on-failure
RestartSec=15
[Install]
WantedBy=multi-user.target
UNIT
systemctl disable --now sshd.service
if systemctl list-unit-files sshd.socket --no-legend | rg -q '^sshd.socket'; then systemctl disable --now sshd.socket; fi
if ! firewall-cmd --permanent --get-zones | tr ' ' '\n' | rg -qx vt-admin; then firewall-cmd --permanent --new-zone=vt-admin; fi
firewall-cmd --permanent --zone=vt-admin --set-target=DROP
firewall-cmd --permanent --zone=vt-admin --add-interface=tailscale0
firewall-cmd --permanent --zone=vt-admin --add-port=22/tcp
for zone in $(firewall-cmd --permanent --get-zones); do
  [[ $zone == vt-admin ]] && continue
  for svc in ssh vnc-server cockpit; do
    if firewall-cmd --permanent --zone="$zone" --query-service="$svc" >/dev/null; then firewall-cmd --permanent --zone="$zone" --remove-service="$svc"; fi
  done
done
firewall-cmd --reload
systemctl daemon-reload
systemctl enable --now vikingtools-ssh

# VNC uses its own Xfce virtual desktop; it does not share the physical GNOME screen.
install -d -m 700 -o "$ADMIN" -g "$(id -gn "$ADMIN")" "$ADMIN_HOME/.config/tigervnc"
cat > "$ADMIN_HOME/.config/tigervnc/config" <<'VNC'
session=xfce
geometry=1920x1080
localhost
securitytypes=VncAuth
VNC
chown "$ADMIN:$(id -gn "$ADMIN")" "$ADMIN_HOME/.config/tigervnc/config"
mkdir -p /etc/tigervnc
if [[ -f /etc/tigervnc/vncserver.users ]] && rg -q '^:1=' /etc/tigervnc/vncserver.users; then
  rg -qxF ":1=$ADMIN" /etc/tigervnc/vncserver.users || { echo 'VNC display :1 belongs to another user.' >&2; exit 1; }
else printf ':1=%s\n' "$ADMIN" >> /etc/tigervnc/vncserver.users; fi
printf 'localhost\nsecuritytypes=VncAuth\n' > /etc/tigervnc/vncserver-config-mandatory
if [[ ! -f $ADMIN_HOME/.config/tigervnc/passwd ]]; then
  echo 'Set a VNC password (the encrypted SSH tunnel is the main access protection).'
  runuser -l "$ADMIN" -c vncpasswd
fi
restorecon -RF "$ADMIN_HOME/.config/tigervnc" /etc/tigervnc
systemctl enable vncserver@:1.service
# Start via SSH after signing out of the physical desktop; concurrent sessions can fail.

# Current official Fedora app installer. TLS download; DNF manages dependencies/updates.
if ! rpm -q chatgpt >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -fL https://persistent.oaistatic.com/codex-app-prod/linux/rpm/latest/chatgpt.x86_64.rpm -o "$INSTALL_MARKER/chatgpt.x86_64.rpm"
  dnf -y install "$INSTALL_MARKER/chatgpt.x86_64.rpm"
fi
# The desktop package includes Codex; create a terminal entry if it exists.
if [[ -x /usr/lib/chatgpt/resources/codex ]]; then
  ln -sfn /usr/lib/chatgpt/resources/codex /usr/local/bin/codex
fi

# Official manual runtime install avoids third-party installer's automatic GPU driver changes.
if ! command -v ollama >/dev/null; then
  curl --proto '=https' --tlsv1.2 -fL https://ollama.com/download/ollama-linux-amd64.tar.zst -o "$INSTALL_MARKER/ollama-amd64.tar.zst"
  tar --zstd -xf "$INSTALL_MARKER/ollama-amd64.tar.zst" -C /usr
  if lspci -dn 1002: | rg -q .; then
    curl --proto '=https' --tlsv1.2 -fL https://ollama.com/download/ollama-linux-amd64-rocm.tar.zst -o "$INSTALL_MARKER/ollama-rocm.tar.zst"
    tar --zstd -xf "$INSTALL_MARKER/ollama-rocm.tar.zst" -C /usr
  fi
fi
id ollama >/dev/null 2>&1 || useradd --system --no-create-home --home-dir /var/lib/vikingtools-ollama --shell /usr/sbin/nologin ollama
for group in render video; do
  if getent group "$group" >/dev/null; then usermod -aG "$group" ollama; fi
done
OLLAMA_BIN=$(command -v ollama)
cat > /etc/systemd/system/ollama.service <<UNIT
[Unit]
Description=Local-only VikingTools model runtime
After=network-online.target
Wants=network-online.target
[Service]
User=ollama
Group=ollama
Environment="HOME=/var/lib/vikingtools-ollama"
ExecStart=$OLLAMA_BIN serve
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
id vt-help >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin vt-help
[[ $(getent passwd vt-help | cut -d: -f7) == /usr/sbin/nologin ]]
[[ $(id -nG vt-help) == vt-help ]] || { echo 'vt-help must have no supplementary groups.' >&2; exit 1; }
passwd -l vt-help >/dev/null
install -d -m 755 /opt/vikingtools-ai
install -d -m 750 -o root -g vt-help /etc/vikingtools-ai
install -d -m 750 -o root -g vt-help /var/lib/vikingtools-ai /var/lib/vikingtools-ai/knowledge
install -d -m 750 -o ollama -g ollama /var/lib/vikingtools-ollama/models
install -m 644 "$BASE/files/support.py" /opt/vikingtools-ai/support.py
install -m 644 "$BASE/files/support.service" /etc/systemd/system/vikingtools-support.service
install -m 755 "$BASE/files/activate-model.sh" /usr/local/sbin/vt-activate-model
install -m 755 "$BASE/files/diagnostics.sh" /usr/local/sbin/vt-diagnostics
install -m 755 "$BASE/files/gpu-inventory.py" /usr/local/sbin/vt-gpu-inventory
install -m 755 "$BASE/files/import-help.sh" /usr/local/sbin/vt-import-help
install -m 755 "$BASE/files/add-admin-key.sh" /usr/local/sbin/vt-add-admin-key
install -m 755 "$BASE/files/enable-ai-admin.sh" /usr/local/sbin/vt-enable-ai-admin
# User requested full AI control: only the named admin session gets passwordless sudo.
/usr/local/sbin/vt-enable-ai-admin
if [[ ! -f /etc/vikingtools-ai/settings.json ]]; then
  install -m 640 -o root -g vt-help "$BASE/files/settings.json" /etc/vikingtools-ai/settings.json
fi
if [[ ! -f /etc/vikingtools-ai/backend-token ]]; then
  python3 -c 'import secrets; print(secrets.token_urlsafe(48))' > /etc/vikingtools-ai/backend-token
fi
chown root:vt-help /etc/vikingtools-ai/backend-token
chmod 640 /etc/vikingtools-ai/backend-token
# Install reviewed public knowledge only; never copy a private repository into this directory.
if [[ ! -f /var/lib/vikingtools-ai/knowledge/public-help.txt ]]; then
  install -m 640 -o root -g vt-help "$BASE/files/public-help.txt" /var/lib/vikingtools-ai/knowledge/public-help.txt
fi
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/vikingtools.conf <<'UNIT'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=/var/lib/vikingtools-ollama/models"
Environment="OLLAMA_NO_CLOUD=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_MAX_QUEUE=4"
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/vikingtools-ollama
PrivateTmp=true
CapabilityBoundingSet=
UNIT
# Customer process can connect ONLY to the inference port, never SSH or other services.
HELP_UID=$(id -u vt-help)
cat > /etc/vikingtools-ai/help-egress.nft <<NFT
table inet vt_help {
 chain output {
  type filter hook output priority -10; policy accept;
  meta skuid $HELP_UID ct state established,related accept
  meta skuid $HELP_UID ip daddr 127.0.0.1 tcp dport 11434 accept
  meta skuid $HELP_UID reject
 }
}
NFT
cat > /usr/local/sbin/vt-help-network <<'NET'
#!/usr/bin/env bash
set -euo pipefail
# Atomic replace on rerun; no flush of unrelated host firewall rules.
if nft list table inet vt_help >/dev/null 2>&1; then
 { echo 'delete table inet vt_help'; cat /etc/vikingtools-ai/help-egress.nft; } | nft -f -
else nft -f /etc/vikingtools-ai/help-egress.nft; fi
NET
chmod 755 /usr/local/sbin/vt-help-network
cat > /etc/systemd/system/vikingtools-help-network.service <<'UNIT'
[Unit]
Description=Restrict customer service outbound connections
Before=vikingtools-support.service
After=firewalld.service
Requires=firewalld.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vt-help-network
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now vikingtools-help-network
systemctl restart vikingtools-help-network
systemctl enable ollama vikingtools-support
systemctl restart ollama vikingtools-support
/usr/local/sbin/vt-gpu-inventory > "$INSTALL_MARKER/graphics-cards.json"
echo "Automatic GPU report saved to $INSTALL_MARKER/graphics-cards.json"
install -m 600 "$BASE/ADMIN-CONTROL.md" "$ADMIN_HOME/ADMIN-CONTROL.md"
chown "$ADMIN:$(id -gn "$ADMIN")" "$ADMIN_HOME/ADMIN-CONTROL.md"
install -m 600 -o "$ADMIN" -g "$(id -gn "$ADMIN")" "$BASE/FIRST-CHAT-PROMPT.txt" "$ADMIN_HOME/FIRST-CHAT-PROMPT.txt"
echo "Prepared. Admin SSH: ssh $ADMIN@$TS_IP"
echo "VNC tunnel: ssh -N -L 5901:127.0.0.1:5901 $ADMIN@$TS_IP"
echo 'Open ChatGPT as your admin user and sign in yourself. Never run the desktop app as root.'
echo 'Next: open ChatGPT, use FIRST-CHAT-PROMPT.txt in your home folder, and finish GPU/model setup.'
echo 'If no SSH key was supplied, add it later with: sudo vt-add-admin-key'
echo 'Customer API is private and disabled for answers until a model is activated. No site deployment performed.'
