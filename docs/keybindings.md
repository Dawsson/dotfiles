# Fedora keybindings (macOS muscle memory)

Fedora/GNOME only. macOS keeps native Command/Option. Applied by `scripts/gnome.sh` (via `./bootstrap.sh` or `dotup`).

## Physical keys

| Key (US PC) | Acts as |
|-------------|---------|
| **Left/Right Alt** (next to Space, where Mac Command sits) | **Command** |
| **Super / Win** | **Option** |
| **Ctrl** | **Control** (never remapped) |

Alt alone does nothing (no menu focus). Super alone still opens the GNOME overview (Mission Control).

keyd implements the map in `dotfiles/keyd/default.conf`. Per-app terminal overrides need `keyd-application-mapper` (autostarted by gnome.sh).

## Cheat sheet (what you press)

Write **Alt** where you would press **⌘**, and **Super** where you would press **⌥**.

### Text

| Action | Press |
|--------|-------|
| Copy / Paste / Cut / Undo / Select all | Alt+C / V / X / Z / A |
| Line start / end | Alt+Left / Right |
| Document start / end | Alt+Up / Down |
| Select line/doc variants | Alt+Shift+arrows |
| Word jump | Super+Left / Right |
| Select by word | Super+Shift+Left / Right |
| Delete previous word | Super+Backspace |
| Delete to line start | Alt+Backspace |

### Apps and windows

| Action | Press |
|--------|-------|
| Launcher (Vicinae) | Alt+Space |
| 1Password Quick Access | Alt+Shift+Space |
| App switcher (hold Alt, Tab cycles) | Alt+Tab |
| Cycle windows of same app | Alt+` |
| Close / Quit | Alt+W / Alt+Q |
| Minimize / Hide | Alt+M / Alt+H |
| New / Tab / Reopen / Refresh / Find / Save / Open / Print / Prefs | Alt+N / T / Shift+T / R / L / F / S / O / P / , → Ctrl equivalents |
| Fullscreen | Ctrl+Alt+F |
| Lock screen | Ctrl+Alt+Q |
| Force Quit (System Monitor) | Alt+Super+Esc |
| Overview | Super tap |

### Screenshots

| Action | Press |
|--------|-------|
| Full screen | Alt+Shift+3 |
| Area / screenshot UI | Alt+Shift+4 or Alt+Shift+5 |

### Terminals (Ghostty, GNOME Terminal, Ptyxis)

| Action | Press |
|--------|-------|
| Copy / Paste | **Ctrl+C / Ctrl+V** (same as GUI; with no selection Ctrl+C may still SIGINT) |
| Interrupt (SIGINT) | **Alt+C** |
| New tab / window, close tab / quit | Alt+T / N / W / Q |

Physical Ctrl is never rewritten by keyd. Terminal copy/paste is configured in Ghostty + gsettings.

## Apply on the desktop

```bash
# From the repo (or after git pull via dotup):
./scripts/gnome.sh
# or
dotup
# or
./bootstrap.sh
```

Then log out/in once so keyd group membership and the application mapper autostart. If gsettings ran without a session bus, re-run `./scripts/gnome.sh` inside GNOME.

## Gaps vs macOS

- Force Quit opens System Monitor (no true Force Quit panel on GNOME Wayland; xkill only on X11).
- Hide (⌘H) minimizes; GNOME has no per-app hide.
- Rectangle-style tiling is macOS-only here.
- Some Electron apps ignore Ctrl+W / Ctrl+Q.
- Terminal Alt+C interrupt on Ghostty is solid (`text:\x03`); VTE/Ptyxis best-effort after Ctrl+C is rebound to copy.
