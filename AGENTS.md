# Agent instructions (Claude Code, Codex and other coding agents)

This file tells a coding agent how to set up a CLIProxyAPI server on a Mac, or how to connect a client to one. Codex reads `AGENTS.md` automatically. Claude Code reads it through `CLAUDE.md`.

The human guide is [`docs/guide.md`](docs/guide.md). It is the source of truth. If this file and the guide disagree, follow the guide and tell the human.

## Rules

1. Ask before you start. Ask the human two questions: "Is this Mac the **server** or a **client**?" and, for a server, "Which access method from guide section 9: A (LAN), B (Tailscale direct), C (Tailscale Serve), or D (SSH tunnel)?" Do not guess.
2. Stop at every **HUMAN** step. Tell the human the exact command or setting, then wait until they say it is done. You cannot type passwords, approve browser sign-ins or change System Settings.
3. Never print, log or commit a client key, a provider token or the `~/.cli-proxy-api` folder. Keys live in files under `~/.config/cliproxyapi/` with mode 600. Pass them to commands with `"$(cat <file>)"`.
4. Never ask the human to paste a key into the chat. Ask them to put it in the key file.
5. Never use `sudo` yourself. Never set up router port forwarding or `tailscale funnel`.
6. Back up a file before you change it. Do not overwrite an existing backup.
7. Use only the command-line flags listed in [`tests/upstream_flags.txt`](tests/upstream_flags.txt).
8. The task is done only when `scripts/check-proxy.sh` exits 0. If one step fails twice, stop and report the error. Do not try workarounds.

## Server setup

Run commands from a clone of this repository.

1. **Check the machine.** Run `uname -m` (expect `arm64`), `sw_vers -productVersion` and `brew --version`.
   - **HUMAN** if Homebrew is missing: install it from <https://brew.sh/>. The installer asks for the login password.
2. **HUMAN: keep the Mac awake.** Ask the human to run the `pmset` commands in guide section 3 and to turn on automatic login (System Settings → Users & Groups). Explain that automatic login is not available with FileVault.
3. **Install.** Run `brew install cliproxyapi`.
4. **Write the configuration.** Set `HOST` from the access method: `""` for A or B, `"127.0.0.1"` for C or D. Then run:

   ```sh
   HOST=""   # or "127.0.0.1" for access method C or D
   umask 077
   mkdir -p ~/.config/cliproxyapi
   for n in 1 2; do
     [ -s ~/.config/cliproxyapi/client-$n.key ] || openssl rand -hex 32 > ~/.config/cliproxyapi/client-$n.key
   done
   CONF="$(brew --prefix)/etc/cliproxyapi.conf"
   [ -e "$CONF.orig" ] || cp "$CONF" "$CONF.orig"
   python3 scripts/write-config.py examples/config.server.yaml "$CONF" "$HOST"
   ```

   The script replaces the key placeholders with the key files and does not print the keys.
5. **HUMAN: sign in to the provider accounts.** The sign-in opens a browser and waits, so the human runs it in their own terminal, as the same macOS user. Give them the command from guide section 6, for example `cliproxyapi -claude-login` or `cliproxyapi -codex-login`. On a server without a screen, give them `cliproxyapi -codex-device-login` or the SSH method in guide section 6.
6. **Start the service.** Run `brew services start cliproxyapi`, then `brew services list`.
7. **Check.** Run:

   ```sh
   PROXY_URL=http://127.0.0.1:8317 PROXY_KEY="$(cat ~/.config/cliproxyapi/client-1.key)" ./scripts/check-proxy.sh
   ```

   It must print `ALL CHECKS PASSED` and exit 0. If the model list is empty, step 5 is not complete.
8. **Remote access.**
   - A or B: find the address with `ipconfig getifaddr en0` or `tailscale ip -4`. **HUMAN** if Tailscale is not signed in.
   - C: run `tailscale serve --bg 8317`, then `tailscale serve status`. **HUMAN** if Tailscale asks to turn on HTTPS certificates.
   - D: nothing on the server.
9. **Report.** Tell the human the client address, the key file paths (not the keys) and the check result. Tell them to copy one key file to each client by a private channel, for example AirDrop or `scp`.

## Client setup

1. Ask the human for the proxy address (guide section 9). **HUMAN:** ask them to save the client key at `~/.config/cliproxyapi/client.key` and to run `chmod 600 ~/.config/cliproxyapi/client.key`.
2. Check the connection from this computer:

   ```sh
   PROXY_URL=<proxy-address> PROXY_KEY="$(cat ~/.config/cliproxyapi/client.key)" ./scripts/check-proxy.sh
   ```

   Do not continue until it exits 0. For access method D, the SSH tunnel must be open first.
3. Configure only the tools that the human names. Follow guide section 10.
   - Claude Code: the variables `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN`. Ask before you change a shell profile such as `~/.zshrc`. Write `export ANTHROPIC_AUTH_TOKEN="$(cat ~/.config/cliproxyapi/client.key)"`, not the key itself.
   - Codex: back up `~/.codex/config.toml`, then add the provider block from [`examples/clients/codex-config.toml`](examples/clients/codex-config.toml). If the file already sets `model_provider`, ask before you change it.
   - Other services: give the human the Base URL `<proxy-address>/v1` and the key file path.
4. Report what you changed, with the backup paths, and the check result.

## What this repository does not prove

The authors checked the commands against the CLIProxyAPI source at commit `7df5607`. They did not run the full procedure on a real server. Report a command that fails as a failure. Do not report the setup as working until step 7 (server) or step 2 (client) exits 0.
