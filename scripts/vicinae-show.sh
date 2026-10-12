#!/usr/bin/env bash
# Open Vicinae from the Super+Space shortcut. GNOME runs this with a small PATH.
set -u

vicinae=""
for candidate in \
  "${HOME}/.local/bin/vicinae" \
  /usr/local/bin/vicinae \
  /usr/bin/vicinae
do
  if [[ -x "$candidate" ]]; then
    vicinae="$candidate"
    break
  fi
done
if [[ -z "$vicinae" ]] && command -v vicinae >/dev/null 2>&1; then
  vicinae="$(command -v vicinae)"
fi
if [[ -z "$vicinae" ]]; then
  printf 'vicinae is not installed\n' >&2
  exit 1
fi
exec "$vicinae" toggle
