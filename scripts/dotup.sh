#!/usr/bin/env bash
# Pull origin/main and run bootstrap again. This is a terminal command, not a key.
# Example: dotup --skip-gui
set -euo pipefail

link="${HOME}/.zshrc"
if [[ ! -L "$link" ]]; then
  printf 'dotup: ~/.zshrc is not a symlink into the dotfiles repo\n' >&2
  exit 1
fi
link="$(readlink "$link")"
root="$(cd "$(dirname "$link")/../.." && pwd)" || exit 1
git -C "$root" pull --ff-only origin main
exec "$root/bootstrap.sh" "$@"
