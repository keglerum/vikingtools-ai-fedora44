#!/usr/bin/env bash
# Optional GPU phase: choose only after verifying exact cards against current vendor support.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]]
case ${1:-auto} in
  auto)
    python3 "$(dirname -- "${BASH_SOURCE[0]}")/files/gpu-inventory.py"
    echo 'Safe automatic discovery completed. Mesa is installed by setup.'
    echo 'Unknown mining chipsets require checking PCI IDs against backend support before changing drivers.'
    ;;
  mesa)
    dnf -y install mesa-vulkan-drivers vulkan-tools
    echo 'Mesa backend installed. Check both actual GPUs with vulkaninfo --summary and Ollama logs.'
    ;;
  nvidia-current)
    lspci -nn | rg -i 'VGA|3D|Display' | rg -qi NVIDIA || { echo 'No NVIDIA display card found.' >&2; exit 1; }
    lspci -nn | rg -i 'VGA|3D|Display'
    read -rp 'Have you confirmed BOTH cards support the current RPM Fusion NVIDIA driver? Type CURRENT: ' CONFIRM
    [[ $CONFIRM == CURRENT ]] || exit 1
    dnf -y install \
      https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm
    dnf -y install akmods kernel-devel-matched akmod-nvidia xorg-x11-drv-nvidia-cuda
    if mokutil --sb-state | rg -qi enabled; then
      kmodgenca -a
      CERT=/etc/pki/akmods/certs/public_key.der
      if ! mokutil --test-key "$CERT"; then
        echo 'Secure Boot requires local key enrollment. Choose a temporary enrollment password.'
        mokutil --import "$CERT"
        echo 'At the next reboot: Enroll MOK -> Continue -> Yes -> enter that password.'
      fi
    fi
    akmods --force --rebuild
    echo 'Driver build completed. Reboot manually, then verify BOTH cards with nvidia-smi.'
    ;;
  *) echo 'Usage: sudo bash gpu-driver.sh auto|mesa|nvidia-current'; exit 1 ;;
esac
