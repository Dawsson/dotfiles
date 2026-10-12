#!/usr/bin/env bash
# Open Ulauncher from the Super+Space shortcut. GNOME runs this with a small PATH.
set -u

toggle="/usr/bin/ulauncher-toggle"
daemon="/usr/bin/ulauncher"
if [[ ! -x "$toggle" ]]; then
  toggle=""
fi
if [[ ! -x "$daemon" ]]; then
  daemon=""
fi
if [[ -n "$daemon" ]] && ! pgrep -x ulauncher >/dev/null 2>&1; then
  "$daemon" --hide-window >/dev/null 2>&1 &
  i=0
  while [[ "$i" -lt 10 ]]; do
    if pgrep -x ulauncher >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
    i=$((i + 1))
  done
fi
if [[ -n "$toggle" ]]; then
  exec "$toggle"
fi
if [[ -n "$daemon" ]]; then
  exec "$daemon"
fi
printf 'ulauncher is not installed\n' >&2
exit 1
