VIKINGTOOLS DEDICATED AI COMPUTER — FEDORA 44
Prepared 12 October 2026. x86_64 Fedora 44 desktop; run on the NEW computer only.

1. Copy this complete folder to the new computer.
2. Copy your existing admin SSH PUBLIC key (.pub) to that computer too.
   Never copy your private key or current ChatGPT login files.
3. Open a local terminal inside this folder and run:

      sudo bash setup.sh /path/to/your-admin-key.pub

   The script uses the existing Fedora admin account. It asks you to sign into
   Tailscale and choose a VNC password. It downloads the official ChatGPT app.
4. Open ChatGPT from the applications menu and sign into your own account.
5. Read ADMIN-CONTROL.md. It covers the GPU phase, model activation, remote
   connection, and connecting the customer assistant to the website later.

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
