# VikingTools AI computer — Fedora 44

Setup for a dedicated Fedora 44 x86_64 computer running a local customer-help model, with separate administrator access.

## Install on the new computer

```sh
git clone https://github.com/keglerum/vikingtools-ai-fedora44.git
cd vikingtools-ai-fedora44
sudo bash setup.sh /path/to/your-admin-ssh-public-key.pub
```

Copy only your admin SSH **public** key to the new computer. Run initial setup in its local terminal. Sign into Tailscale and ChatGPT yourself when prompted.

## Included

- Official ChatGPT desktop app and bundled Codex terminal tool.
- Tailscale, SSH with an admin key, and loopback-only TigerVNC/Xfce.
- Ollama in local-only mode and a restricted customer support gateway.
- Automatic PCI/chipset, driver and memory discovery for GPUs, including mining cards.
- Admin-only model activation and public-help imports.
- Development, diagnostics and maintenance tools.

**The selected admin account receives passwordless sudo.** Trusted ChatGPT/Codex sessions running as that account can administer the computer. Other programs in that account share the same privileges. Customer messages never receive those permissions.

The customer service has no shell, sudo, execution tools or configuration endpoint. Its private API remains disabled for answers until the admin activates a local model. No live website, DNS or public endpoint is changed by this installer.

## Finish setup

Read [ADMIN-CONTROL.md](ADMIN-CONTROL.md), then give [FIRST-CHAT-PROMPT.txt](FIRST-CHAT-PROMPT.txt) to ChatGPT on the new computer. It describes card identification, supported GPU configuration, model testing, remote-access checks and public help review.

Unknown ASRock mining cards require actual chipset and backend compatibility checks. Full admin access cannot guarantee that both cards support AI. The Linux app preview currently supports local commands but does not provide direct desktop Computer Use; VNC supplies a separate admin desktop.

## Validation

Offline request/authentication tests, shell syntax checks and service-definition checks passed during preparation. The installer has **not** been tested on a fresh target computer. GPU acceleration, remote connectivity, SELinux behavior and reboot survival must be tested there before customer use.

Run the offline checks without installing anything:

```sh
python3 test-support.py
bash -n setup.sh
```

The `public-help-review` folder contains anonymous snapshots of public VikingTools pages from 12 October 2026. Review them before importing; they are not installed automatically. Actual credentials and keys are generated or supplied on the target and are not included here.

See [README.txt](README.txt) for the short checklist and [official Linux app documentation](https://learn.chatgpt.com/docs/linux/linux-app) for platform limitations.
