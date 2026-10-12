#!/usr/bin/env bash
# Closest GNOME/Wayland stand-in for macOS Force Quit (Cmd+Option+Esc).
# Prefer System Monitor; fall back to xkill on X11 only.
set -u

if command -v gnome-system-monitor >/dev/null 2>&1; then
  exec gnome-system-monitor
fi
if [[ -n "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && command -v xkill >/dev/null 2>&1; then
  exec xkill
fi
if command -v notify-send >/dev/null 2>&1; then
  notify-send 'Force Quit' 'Install gnome-system-monitor, or use xkill on X11.'
fi
exit 1
