VIKINGTOOLS DEDICATED AI COMPUTER — FEDORA 44
Prepared 12 October 2026. x86_64 Fedora 44 desktop; run on the NEW computer only.

1. Connect the new Fedora computer to the internet and open Terminal.
2. Paste these three lines:

   sudo dnf install -y curl
   curl --proto '=https' --tlsv1.2 -fL https://raw.githubusercontent.com/keglerum/vikingtools-ai-fedora44/main/bootstrap.sh -o /tmp/vikingtools-bootstrap.sh
   sudo bash /tmp/vikingtools-bootstrap.sh

3. Enter your Fedora admin password, sign into Tailscale when prompted, and set
   the VNC password. The installer installs the apps and tools itself.
4. Open ChatGPT from the applications menu and sign into your own account.
5. Give ChatGPT FIRST-CHAT-PROMPT.txt from your home folder to finish GPU/model
   setup. Read ADMIN-CONTROL.md for details.

No Git or AI app needs to be installed beforehand. SSH keys can be added later
with sudo vt-add-admin-key. Remote password login stays disabled. A downloaded
bundle can also be started locally with sudo bash setup.sh (no key required).

INSTALLED
Tailscale; private SSH; private TigerVNC/Xfce desktop; ChatGPT with bundled Codex;
Python/Node development tools; Git; Podman; monitoring/diagnostic tools; Ollama;
a restricted customer support gateway; admin-only model/knowledge controls.

ACCESS
Only your selected admin account can sign in over the configured SSH service.
The script enables passwordless sudo for that account, allowing trusted
ChatGPT/Codex sessions running as that account to perform privileged repairs.
Every program running as that account shares that power. Keep it admin-only.
The customer service has no shell, sudo, execution tools, or configuration API.
Nothing is published to the internet or deployed to vikingtools.no by this setup.

AFTER INSTALL
The support gateway runs at 127.0.0.1:8088 and Ollama at 127.0.0.1:11434.
Answers remain disabled until the admin selects, downloads and activates a model.
VNC starts at boot, or via SSH after signing out of the physical desktop.
Card chipsets and driver status are detected automatically and saved for ChatGPT.
Full admin control cannot guarantee unsupported mining cards will run AI.
Finish restricting Tailscale access to your admin identity and verify remote login.

TEST STATUS
Offline gateway checks and shell syntax checks passed on the existing laptop.
This installer has NOT been executed on a fresh Fedora 44 computer. Actual GPU,
VNC, SELinux, reboot, and remote connectivity still require target-machine tests.
No setup can guarantee remote recovery if power, networking, boot or the OS fails.
