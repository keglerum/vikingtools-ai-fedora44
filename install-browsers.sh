#!/usr/bin/env bash
# Install native stable Chrome and Brave from their official signed repositories.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo bash install-browsers.sh' >&2; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]] || { echo 'Requires Fedora 44 x86_64.' >&2; exit 1; }
dnf -y install curl ca-certificates
install -d -m 755 /etc/yum.repos.d /etc/pki/rpm-gpg
curl --retry 3 --retry-delay 2 --connect-timeout 20 --proto '=https' --tlsv1.2 -fsSL \
  https://dl.google.com/linux/linux_signing_key.pub \
  -o /etc/pki/rpm-gpg/google-linux-signing-key.pub
rpm --import /etc/pki/rpm-gpg/google-linux-signing-key.pub
cat > /etc/yum.repos.d/google-chrome.repo <<'REPO'
[google-chrome]
name=Google Chrome stable
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
REPO
curl --retry 3 --retry-delay 2 --connect-timeout 20 --proto '=https' --tlsv1.2 -fsSL \
  https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo \
  -o /etc/yum.repos.d/brave-browser.repo
curl --retry 3 --retry-delay 2 --connect-timeout 20 --proto '=https' --tlsv1.2 -fsSL \
  https://brave-browser-rpm-release.s3.brave.com/brave-core.asc \
  -o /etc/pki/rpm-gpg/brave-browser-signing-key.asc
rpm --import /etc/pki/rpm-gpg/brave-browser-signing-key.asc
chmod 644 /etc/yum.repos.d/google-chrome.repo /etc/yum.repos.d/brave-browser.repo \
  /etc/pki/rpm-gpg/google-linux-signing-key.pub /etc/pki/rpm-gpg/brave-browser-signing-key.asc
dnf -y install --refresh google-chrome-stable brave-browser
rpm -q google-chrome-stable brave-browser
echo 'Chrome and Brave installed. Open them from the applications menu as your normal admin user.'
