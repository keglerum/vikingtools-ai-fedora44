# VikingTools AI computer — admin guide

Prepared 12 October 2026 for a fresh Fedora 44 x86_64 desktop.

## What gets full control

Use one Fedora administrator account and your own ChatGPT login. The setup grants
that account passwordless sudo. ChatGPT/Codex commands running in that account can
therefore administer the host when the app's project permissions allow execution.
The operating system cannot distinguish the admin from other programs running as
the admin. Never let customers sign in to this account, use its desktop, or send
requests directly to an admin ChatGPT project.

To remove unattended root access: `sudo vt-enable-ai-admin --disable`.
To restore it: `sudo vt-enable-ai-admin`.
These commands do not change the app's own permission settings.

Open ChatGPT as your normal admin, sign in, and add a local VikingTools project.
Use its permission controls to grant full access to your trusted admin work.
Do not run the graphical app as root or copy another computer's session tokens.
The Linux preview supports local files and commands. The official documentation
currently says direct desktop Computer Use is unavailable in Linux. VNC supplies
an admin desktop; installing it does not give ChatGPT a desktop-control tool.
This current chat also does not automatically acquire the new computer's tools.
Use ChatGPT/Codex on that host, or a separately supported connected remote host.

The customer assistant has its own `vt-help` account with a disabled login and no
supplementary groups. Its code, model selection, token, and public help files are
root-owned. It can only submit text to Ollama; it has no execution tools or admin
endpoint. Its process has a read-only filesystem, hidden admin homes and private
service directories, resource limits, and a firewall restricting new outbound
connections to the local inference port. The model's advice can still be wrong;
its prompt is not the security boundary. Customer input never becomes a shell
command or an admin configuration change.

## Private remote access

The setup prints the machine's Tailscale IP and SSH command. Replace ADMIN and
TAILSCALE_IP below with those values; run from your existing admin computer:

```sh
ssh ADMIN@TAILSCALE_IP
ssh -N -L 5901:127.0.0.1:5901 ADMIN@TAILSCALE_IP
```

Keep the second connection open and connect your VNC viewer to `127.0.0.1:5901`.
Compare the SSH host-key fingerprint at the new computer before accepting it.
The server uses your public key over Tailscale. It deliberately leaves the
separate Tailscale SSH authentication feature disabled.

In the Tailscale admin console, restrict network grants to your admin identity
and this machine's TCP port 22. Remove any broad existing grant that would also
allow other users. Enable MFA for the admin's identity account. Grants are
additive: adding a narrow grant does not revoke an existing broad grant.
The setup cannot alter your existing tailnet's membership or policies by itself.
Do not expose VNC, Ollama, or SSH with router port forwarding or Tailscale Funnel.

VNC creates a separate Xfce session. Finish local setup and sign out of the
physical desktop first, then use SSH to run:

```sh
sudo systemctl start vncserver@:1
sudo vt-diagnostics
```

VNC listens on loopback and is reached through the encrypted SSH tunnel. It
restarts at boot. A same-user physical desktop session may conflict with VNC.
The configured SSH service is `vikingtools-ssh`, not the standard `sshd` service.
If the Tailscale IP changes after re-enrollment, rerun setup locally to update it.
For recovery, retain a working physical monitor, keyboard, and admin password.

## Graphics cards and model

The setup automatically identifies the cards by PCI chipset IDs, subsystem IDs,
loaded driver, and memory where the driver exposes it, even for mining cards with
no display connectors. It saves `/var/lib/vikingtools-setup/graphics-cards.json`.
Run `sudo vt-gpu-inventory` to refresh the report. Unknown memory stays unknown.

Run `sudo vt-diagnostics` and record both card models, VRAM, RAM and Secure Boot.
ASRock is the board manufacturer, not proof of an NVIDIA or AMD chipset.
Specialized mining boards may require unusual drivers or may not support AI.
No specific model size or driver family has been selected without those facts.
Ollama chooses supported GPUs automatically; a model that fits one card may use
one card. Two cards do not necessarily double speed or pool VRAM transparently.

For AMD/Intel cards, the setup includes Mesa Vulkan. Check card support in the
Ollama hardware documentation. The setup also fetches the official ROCm runtime bundle when an AMD PCI device
is detected. Runtime installation does not prove that a specific chipset supports it. Do not install Ubuntu AMD driver packages on Fedora or force unsupported
ROCm device overrides. Verify actual inference before enabling customer answers.

For two supported modern NVIDIA cards, after checking BOTH against the current
RPM Fusion driver's supported list, use the optional driver phase:

```sh
sudo bash gpu-driver.sh nvidia-current
```

This adds RPM Fusion and installs its current NVIDIA driver and compute support.
Legacy NVIDIA cards require a suitable older driver branch; this helper does not
choose that branch. With Secure Boot enabled, the script imports the akmods key
and you must enroll it in the firmware MOK screen at the next local reboot.
It never disables Secure Boot or reboots automatically.

Reboot manually when the driver build and key enrollment instructions are ready.
Check `nvidia-smi` for BOTH cards. Then select a local model from Ollama's catalogue
that fits the measured hardware and is suitable for the languages your customers
use. Review its license and test it; do not use a model with a cloud suffix.

```sh
sudo vt-activate-model MODEL_NAME
```

The command downloads the model, runs a short inference test, shows `ollama ps`,
and requires the admin to type ENABLE after reviewing GPU use and help material.
Ollama Cloud is disabled. No OpenAI API key is used by the customer assistant.
The ChatGPT admin app separately uses your existing account and plan limits.

## Approved help information

The initial help file provides basic support boundaries only. The folder
`public-help-review` contains anonymous snapshots of five public website pages,
prepared on 12 October 2026. These are review material, not installed automatically.
Remove navigation, irrelevant form labels, obsolete claims, and any sensitive
material. Check that instructions match real current workflows, then install each
approved text file on the new computer:

```sh
sudo vt-import-help public-help-review/restaurant-menu.txt
```

You can prepare fresh snapshots by running `python3 collect-public-help.py` from
this bundle. Only the admin does this. The customer assistant never crawls the
website or retrieves arbitrary customer-provided URLs. No private repository,
payment records, customer uploads, or operational secrets belong in this corpus.
The gateway uses simple text matching over bounded snippets. Assess its answers
for restaurant menus, QR codes, accounts, payments, unsupported requests, and
prompt-injection attempts before public use. The model is not guaranteed correct.

Config: `/etc/vikingtools-ai/settings.json`.
Knowledge: `/var/lib/vikingtools-ai/knowledge/*.txt`.
Backend token: `/etc/vikingtools-ai/backend-token` (keep secret).
Only root/admin commands can change these. To disable answers, set `enabled` to
false using `sudoedit /etc/vikingtools-ai/settings.json`. Each request reads it.

## Connecting customers later

This bundle provides a PRIVATE support API, not a published website chat widget.
The API accepts only `POST /ask` with `{"question":"…"}` and a bearer backend
secret. It ignores no extra fields: model, tools, configuration, and admin commands
are rejected. Responses are JSON with plain text in `answer`; a UI must render
that text safely, not execute or inject it as HTML. Conversation history is not
stored and questions/answers are not written to the gateway logs.

To connect vikingtools.no, implement a site backend route that authenticates or
rate-limits visitors, enforces a bounded queue and timeout, and forwards the
question through a private authenticated connection to this gateway. Keep the
backend token in server-side secret storage; NEVER place it in browser JavaScript.
Choose and test that transport against the existing hosting architecture before
deploying. Do not expose Ollama's API or an admin account to customers. A private
Tailscale connection must also be authorized for the backend device; a Cloudflare
Worker does not automatically join your tailnet.

Website integration, public chat UI, hosting changes, DNS, and production testing
are separate work. None have been performed. No subscription or paid remote-access
service is added by this script. Local compute still consumes electricity.

## Maintenance and recovery

Use `sudo vt-diagnostics` to inspect services, listeners and GPUs. View failures
with `sudo journalctl -u vikingtools-support -u ollama -u vikingtools-ssh --since today`.
Logs may contain device/network details; review before sharing.

Apply Fedora and app updates with `sudo dnf upgrade --refresh`. Plan a manual
reboot for kernel updates and verify both GPUs and remote access afterward.
Updates are not automatically installed during customer service operation.
The setup saves selected previous configurations under
`/var/lib/vikingtools-setup/backups/` and can be rerun with the same admin account.
Rerunning reapplies the SSH/VNC policy and upgrades packages; it is not an uninstall.
It does not remove other login mechanisms or audit every local account or service.
Use a genuinely fresh dedicated machine. Do not add customer shell accounts.

To stop customer inference: `sudo systemctl disable --now vikingtools-support ollama`.
To stop remote access locally:
`sudo systemctl disable --now vikingtools-ssh vncserver@:1 tailscaled`.
This closes the connection. Do it only with physical access available.
No software remote-control stack fixes a powered-off host, broken boot, or dead
network. If recovery through those failures is required, evaluate separate
hardware management/KVM and a UPS after the actual motherboard is known.

## Verified scope and references

Offline request/authentication tests and shell syntax checks passed on the current
laptop. No installer was executed on the target. Fedora package installation,
SELinux behavior, GPU acceleration, VNC sessions, reboot survival, and end-to-end
remote access must be verified there before customers use it.

- App installation and Linux limitations: https://learn.chatgpt.com/docs/linux/linux-app
- Codex terminal use: https://learn.chatgpt.com/docs/codex/cli
- Ollama installation: https://docs.ollama.com/linux
- Ollama GPUs: https://docs.ollama.com/gpu
- Local-only Ollama settings and GPU checks: https://docs.ollama.com/faq
- SSH over Tailscale: https://tailscale.com/docs/reference/ssh-over-tailscale
- Tailscale grants: https://tailscale.com/docs/features/access-control
- TigerVNC configuration: https://tigervnc.org/doc/vncsession.html
- NVIDIA driver instructions: https://rpmfusion.org/Howto/NVIDIA
- Secure Boot enrollment: https://rpmfusion.org/Howto/Secure%20Boot
