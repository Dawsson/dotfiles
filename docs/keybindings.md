# Fedora keybindings (macOS muscle memory)

Fedora/GNOME only. macOS keeps native Command/Option. Applied by `scripts/gnome.sh` (via `./bootstrap.sh` or `dotup`).

## Physical keys

| Key (US PC) | Acts as |
|-------------|---------|
| **Left/Right Alt** (next to Space, where Mac Command sits) | **Command** |
| **Super / Win** | **Option** |
| **Ctrl** | **Control** (never remapped) |

- **Alt alone** does nothing (no menu focus, no overview).
- **Super tap** opens GNOME **Activities / Overview** (desktops + search — Mission Control-like). It does **not** open Vicinae or any Spotlight-style launcher.
- **Alt+Space** opens the launcher (Vicinae). **Alt+Tab** is the app switcher.

keyd implements the map in `dotfiles/keyd/default.conf`. Terminal Ctrl+C/V and Alt+C are native (Ghostty config + `configure_terminal_copy_paste` in gnome.sh) and do not need `keyd-application-mapper`. Optional close/tab overrides in `app.conf` still need the mapper (GNOME Shell extension; not available on Shell 50 yet).

### Inland / Keychron MK Pro V2 (and similar)

Use **Windows / Android mode** on the keyboard (rear switch), not Mac/iOS mode.

Mac mode swaps Alt and Super/Command in firmware, so keyd’s physical-position map (Alt=Command, Super=Option, Super-tap→Overview) lands on the wrong keys. Win mode reports standard PC modifiers and matches this repo.

The board also identifies as Apple USB id `05ac:024f` over Bluetooth and the 2.4G dongle. keyd treats that id like a trackpad under a bare `[ids] *`, so `dotfiles/keyd/default.conf` lists `05ac:024f` explicitly (install via `gnome.sh` / `dotup`).

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
| Activities / Overview (desktops + search) | **Super tap** (not the launcher) |
| Launcher (Vicinae) | **Alt+Space** |
| 1Password Quick Access | Alt+Shift+Space |
| App switcher (hold Alt, Tab cycles) | **Alt+Tab** |
| Cycle windows of same app | Alt+` |
| Close / Quit | Alt+W / Alt+Q |
| Minimize / Hide | Alt+M / Alt+H |
| New / Tab / Reopen / Refresh / Find / Save / Open / Print / Prefs | Alt+N / T / Shift+T / R / L / F / S / O / P / , → Ctrl equivalents |
| Fullscreen | Ctrl+Alt+F |
| Lock screen | Ctrl+Alt+Q |
| Force Quit (System Monitor) | Alt+Super+Esc |
| Alt alone | Does nothing |

**Super+Tab does not switch apps.** GNOME’s default includes Super+Tab; this map clears it and keyd no-ops Option+Tab so only **Alt+Tab** (hold Alt, Tab cycles) opens the switcher. Reverse with Alt+Shift+Tab.

### Screenshots

| Action | Press |
|--------|-------|
| Full screen | Alt+Shift+3 |
| Area / screenshot UI | Alt+Shift+4 or Alt+Shift+5 |

### Terminals (Ghostty, GNOME Terminal, Ptyxis)

| Action | Press |
|--------|-------|
| Copy / Paste | **Ctrl+C / Ctrl+V** (same as GUI; with no selection Ctrl+C may still SIGINT) |
| Interrupt (SIGINT) | **Alt+C** (Ghostty: `text:\x03`; keyd emits Ctrl+Insert for Alt+C) |
| New tab / window, close tab / quit | Alt+T / N / W / Q (needs mapper; best-effort on GNOME 50) |

Physical Ctrl is never rewritten by keyd. Copy/paste and Ghostty Alt+C interrupt are native configs applied by gnome.sh / linked Ghostty config — not `app.conf`.

## Apply on the desktop

```bash
# From the repo (or after git pull via dotup):
./scripts/gnome.sh
# or
dotup
# or
./bootstrap.sh
```

Then log out/in once so keyd group membership applies. If gsettings ran without a session bus, re-run `./scripts/gnome.sh` inside GNOME. New Ghostty windows pick up the linked config immediately.

## Gaps vs macOS

- Force Quit opens System Monitor (no true Force Quit panel on GNOME Wayland; xkill only on X11).
- Hide (⌘H) minimizes; GNOME has no per-app hide.
- Rectangle-style tiling is macOS-only here.
- Some Electron apps ignore Ctrl+W / Ctrl+Q.
- Terminal Alt+C interrupt is solid in **Ghostty** (`alt+c` / `ctrl+insert` → `text:\x03`). Ptyxis/GNOME Terminal get Ctrl+C/V copy/paste via gsettings; they have no “send ^C” shortcut action, so Alt+C interrupt there is not guaranteed (Ctrl+Insert may still copy in VTE).
