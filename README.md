# dotfiles

One bootstrap for a new Mac (Apple silicon) or a Fedora Workstation 44 machine. It installs the same CLI toolbox on both, symlinks the shared config, and adds the desktop apps that belong on each OS. Re-running it is safe: package installs are no-ops when the tool is already there, symlinks are replaced only when they point somewhere else, and a real file is moved aside to `*.dotfiles-backup.<timestamp>` before it is replaced.

No secrets are stored in this repo. API keys stay in files under `~/.codex/` on the machine.

## Quick start

From a fresh machine, with `git` and `curl` available:

```bash
curl -fsSL https://raw.githubusercontent.com/Dawsson/dotfiles/main/install.sh | bash
```

Pass flags through `bash -s`:

```bash
curl -fsSL https://raw.githubusercontent.com/Dawsson/dotfiles/main/install.sh | bash -s -- --skip-gui
```

Or clone it and run the bootstrap directly:

```bash
git clone https://github.com/Dawsson/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

`install.sh` clones into `~/.dotfiles` (override with `DOTFILES_DIR` or `DOTFILES_REPO`) and then execs `bootstrap.sh`. Running `./install.sh` from a checkout just execs `bootstrap.sh`.

The bootstrap refuses anything that is not macOS or Fedora. On Fedora it warns and continues if the release is not 44 or the CPU is not x86_64.

## Flags

| Flag | Effect |
| --- | --- |
| `--skip-gui` | Skip GUI apps, browsers, and the Fedora desktop layout. CLIs, Docker, libvirt, and Cua still install. |
| `--skip-runtimes` | Skip `mise install` (node, bun, go, Java, Rust, Python, uv, pnpm). |
| `--only-dotfiles` | Only symlink configs and write the Codex CPA config. |
| `--with-claude-cpa` | Opt Claude Code into the CPA host. The Anthropic compatibility of that endpoint is not verified. |
| `--dry-run` | Print the actions and change nothing. |
| `--help` | Show the flags. |

## What each script does

| Path | Role |
| --- | --- |
| `install.sh` | Curl-able entry point. Clones this repo if it is not already a checkout, then runs `bootstrap.sh`. |
| `bootstrap.sh` | Detects the OS, links configs, installs packages, runtimes, and agent CLIs, then prints the manual follow-ups. |
| `lib/common.sh` | Logging, dry-run, sudo, and downloads. |
| `scripts/link.sh` | Symlinks zsh, git, tmux, starship, mise, Ghostty, the CPA env file, and the keyd app map. Clones tmux plugin manager. |
| `scripts/macos.sh` | Installs Homebrew if needed, applies `Brewfile` and `Brewfile.gui`, and sets Helium as the default browser with `duti`. |
| `scripts/fedora.sh` | dnf packages, RPM Fusion, Docker Engine, KVM/libvirt, Cua CLI, and the Linux app installers. |
| `scripts/gnome.sh` | Ulauncher, keyd, WhiteSur, GNOME extensions, fonts, and `gsettings`. Re-run it from a logged-in GNOME session if the first pass had no session bus. |
| `scripts/runtimes.sh` | Installs [mise](https://mise.jdx.dev) if Homebrew did not, then installs the tools in `dotfiles/mise/config.toml`. |
| `scripts/agents.sh` | Claude Code, Codex CLI, and the CPA provider block in `~/.codex/config.toml`. |
| `scripts/pyhelper.py` | Release-asset lookup, Codex config merge, and the Helium MIME default. |
| `tests/smoke.sh` | `bash -n`, shellcheck, dry-run plans, symlink and CPA tests. |

Configs are symlinks back into this repo, except `~/.codex/config.toml`. That file is merged so an existing Codex config is backed up and kept, with the CPA provider added. `model_provider` is set to `cpa` only when the file is new or does not already choose one. A second run refreshes the CPA block and leaves the rest of the file alone.

`git config --global` writes through the symlink into this repo. Commit those edits on purpose, or keep machine-only settings out of the global file.

## Installed on both

- Shell: zsh, Starship, zoxide, the shared zshrc / gitconfig / tmux / Ghostty config
- mise toolchains: Node 24, Bun, Go, Java (Zulu 21), Rust, Python, uv, pnpm
- CLIs: gh, lazygit, btop, tmux, zellij, fastfetch, tree, wget, xh, yt-dlp, ffmpeg, doppler, pscale, cloudflared, restic, sops, poppler, git-lfs, ripgrep, jq
- Tailscale, 1Password app, 1Password CLI
- Ghostty, Cursor, T3 Code Nightly, Grok Bot
- Google Chrome and Helium. Helium becomes the default browser. Chrome stays installed.
- Legcord, Slack, Spotify, Obsidian
- Claude Code (native installer on macOS, official dnf repo on Fedora, native installer as the fallback)
- Codex CLI from `https://chatgpt.com/codex/install.sh`

The zshrc still loads keys from files (`~/.codex/config.toml`, `~/.codex/secrets.env`, `~/.codex/cpa.env`). Homebrew, OrbStack, `open`, and `launchctl` run only on macOS. Paths use `$HOME`.

## macOS only

Homebrew, then the curated casks in `Brewfile.gui`:

- OrbStack, instead of Docker Desktop
- Raycast, Rectangle, Shottr, AlDente
- Tailscale.app, which also provides the `tailscale` CLI

`--skip-gui` installs the `tailscale` formula instead of the app. The first time Raycast opens, let it take Command-Space.

## Fedora only

- dnf for CLIs that Fedora ships, with a GitHub release fallback when a command is still missing
- RPM Fusion, ffmpeg, and the common GStreamer codec packages
- Docker Engine from Docker's repo, service enabled, user added to the `docker` group
- qemu-kvm, libvirt, virt-install, and virt-manager. User added to `libvirt` and `kvm`
- Cua CLI only: `curl -fsSL https://cua.ai/install.sh | sh -s -- --cli-only --yes --no-onboarding`. The Cua Spaces app is mac-only and is not installed
- Flatpak (Flathub) for Legcord, Slack, Spotify, and Obsidian
- Cursor's yum repo, Google Chrome's rpm, Helium from the `imput/helium` COPR, Ghostty from the `scottames/ghostty` COPR (the repo Ghostty's install docs use; Fedora itself does not ship it), Grok Bot from Cursor's Linux rpm feed
- T3 Code Nightly from the current GitHub release. An rpm is used when that nightly published one; otherwise the x86_64 AppImage is installed to `~/.local/opt/t3-code/`
- Ulauncher on Super+Space. GNOME's Super+Space input-source shortcut is cleared. If `ulauncher` is not in the Fedora repos, the script enables the `troycurtisjr/ulauncher` COPR
- Dash to Dock on the bottom, always visible (`autohide` left off). Window buttons on the left: close, minimize, maximize
- WhiteSur GTK, icon, and cursor themes, Inter, and JetBrainsMono Nerd Font
- Natural scrolling and tap-to-click
- keyd from the `alternateved/keyd` COPR (upstream's Fedora package; it is not in the Fedora repos). Holding Super sends the usual Command chords (copy, paste, cut, undo, select-all, and the rest of the Control-letter keys). Super+Space stays Super+Space for Ulauncher. A tap of Super still opens the overview. Terminals are remapped to Ctrl+Shift+C/V through `keyd-application-mapper` when that helper is installed
- Packaged GNOME extensions: Dash to Dock, AppIndicator, user themes (`gnome-shell-extension-user-theme`), and Blur My Shell. If the Blur My Shell package is missing, the script falls back to `gnome-extensions-cli`

Log out and back in after the first Fedora run so the new groups, keyd, and GNOME extensions apply. If the dock or hotkey did not stick, open a terminal inside the graphical session and run `./scripts/gnome.sh`.

## Codex CLI proxy

The devbox CPA speaks the OpenAI Responses API, including websockets, at:

```text
https://devbox-dawson.tail20065d.ts.net/v1
```

`dotfiles/codex/config.toml` selects that provider by default:

```toml
model_provider = "cpa"

[model_providers.cpa]
name = "Devbox CPA"
base_url = "https://devbox-dawson.tail20065d.ts.net/v1"
wire_api = "responses"
env_key = "CPA_API_KEY"
supports_websockets = true
```

The key is never committed. `~/.codex/cpa.env` is symlinked from this repo and sourced at the end of `.zshrc`. It exports `CPA_API_KEY` from `~/.codex/cpa-client-key`. If that file is missing and `~/.codex/cpa-op-ref` contains a single `op://` URI, the next shell runs `op read` and writes the key file (mode 600). An existing key file wins, so `op` is not called on every prompt.

Claude Code does not use this endpoint unless you opt in. `--with-claude-cpa`, or `touch ~/.codex/claude-cpa.enable`, exports:

```text
ANTHROPIC_BASE_URL=https://devbox-dawson.tail20065d.ts.net
ANTHROPIC_AUTH_TOKEN=$CPA_API_KEY
```

There is no `/v1` on that base URL. Whether CPA actually exposes an Anthropic-compatible API still needs to be confirmed before relying on it. Remove `~/.codex/claude-cpa.enable` to turn it off.

## Manual steps after install

1. Open a new terminal so the zshrc, mise, and `cpa.env` are loaded. If `chsh` could not change the login shell, run `chsh -s "$(command -v zsh)"`.
2. Sign in to the 1Password app and turn on the CLI integration. `op signin` if the CLI asks.
3. Run `tailscale up` and approve the device. The CPA host is a Tailscale name and will not resolve before this.
4. Install the CPA client key:
   ```bash
   install -m 600 /dev/stdin ~/.codex/cpa-client-key
   ```
   or, when the item lives in 1Password:
   ```bash
   printf '%s\n' 'op://Vault/Item/password' > ~/.codex/cpa-op-ref
   chmod 600 ~/.codex/cpa-op-ref
   ```
5. Open another shell and check the key without printing it: `[ -n "$CPA_API_KEY" ] && echo "CPA key is set"`. Then run `codex`.
6. Sign in to Cursor, Grok Bot, and T3 Code Nightly.
7. On Fedora, run `cua auth login`. The Spaces app is not part of this install.
8. On Fedora, log out and back in. Confirm `groups` contains `docker` and `libvirt`.
9. On the Mac, accept Raycast's prompt for Command-Space. OrbStack is the Docker runtime; Docker Desktop is not installed.
10. Helium should be the default browser. Chrome is still installed if you want it.

## Not installed

Kubernetes tools (k9s, kubectx, helm, k3d, k3sup, stern), Stripe CLI, flyctl, AltTab, Karabiner, Hammerspoon, the official Discord app, games (Roblox, Steam, Epic, Lunar, Prism), Warp, Zed, VS Code, JetBrains, and Termius. The old full `brew bundle dump` was only a reference for the curated Brewfiles.

Cursor's versioned `origin` credential helper and the machine-specific `sakuracord` signing identity were dropped from gitconfig. Cursor writes its own helper back when it needs one. `gh auth git-credential` is used for GitHub and GitHub gists, without a hardcoded Homebrew path.

## Checks

```bash
./tests/smoke.sh
```

That runs syntax checks, shellcheck, both dry-run plans, a temp-home symlink install, and the CPA merge. It does not install Homebrew packages or change your real home directory.

A Fedora 44 container can execute the Fedora dry-run and `dnf` package-name checks. It cannot apply GNOME settings, start Docker's systemd service, or sign in to anything.

## Gaps

- This was not run on a physical Mac or on a Fedora Workstation GNOME session. Dry-runs and a Fedora 44 container cover the plans and the package names that container can see. On Fedora 44, `lazygit`, `zellij`, `xh`, `sops`, and `starship` are not in the default repos, so the GitHub fallbacks install them. `ffmpeg` and the ugly/freeworld GStreamer plugins come from RPM Fusion, which the script enables first.
- Grok Bot publishes Linux builds (deb, rpm, and AppImage). Fedora installs the rpm from the official stable feed at `https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand`. There is no separate web-app fallback.
- T3 Code Nightly publishes a Linux desktop build. The release checked while writing this repo had an x86_64 AppImage and a deb, and no rpm. The script prefers an rpm when a nightly includes one, and otherwise installs the AppImage. The terminal installer at `https://t3.codes/install.sh` is a different entry point; this bootstrap installs the desktop app.
- The Claude Code CPA opt-in assumes an Anthropic-compatible API on the same host. That has not been verified.
- keyd's terminal override depends on the window class. If Ghostty copy is still Ctrl+C, add the class reported by the application mapper to `dotfiles/keyd/app.conf`.
- WhiteSur, Dash to Dock, and Ulauncher's shortcut need a graphical login. `./scripts/gnome.sh` applies them again.
- Ulauncher's Fedora package moves. The script tries the distro package, then the `troycurtisjr/ulauncher` COPR.
