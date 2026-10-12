#!/usr/bin/env bash
# First-time bootstrap only (curl | bash). Day-to-day updates use `dx update` / `dotup`.
#
#   curl -fsSL https://raw.githubusercontent.com/Dawsson/dotfiles/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Dawsson/dotfiles/main/install.sh | bash -s -- --skip-gui
#
# After the first run, prefer:
#   dx update
#   dx up --skip-gui
#   dotup            # thin wrapper → dx update
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/Dawsson/dotfiles.git}"
DEST="${DOTFILES_DIR:-${HOME}/.dotfiles}"

running_from_checkout() {
  local source="${BASH_SOURCE[0]:-}"
  local dir
  [[ -n "$source" && -f "$source" ]] || return 1
  dir="$(cd "$(dirname "$source")" && pwd)"
  [[ -f "${dir}/bootstrap.sh" ]] || return 1
  printf '%s\n' "$dir"
}

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git
    return 0
  fi
  echo "git is required. On macOS, run: xcode-select --install" >&2
  exit 1
}

checkout="$(running_from_checkout || true)"
if [[ -n "$checkout" ]]; then
  # From a checkout: hand off to bootstrap (install.sh is not the day-to-day path).
  # Prefer `dx update` once the CLI is on PATH.
  if command -v dx >/dev/null 2>&1; then
    echo "note: day-to-day updates use \`dx update\` (or \`dotup\`); running bootstrap once from checkout" >&2
  fi
  exec "${checkout}/bootstrap.sh" "$@"
fi

ensure_git
if [[ -d "${DEST}/.git" ]]; then
  git -C "$DEST" pull --ff-only || echo "warning: git pull failed; using the existing checkout" >&2
elif [[ -e "$DEST" ]]; then
  echo "error: ${DEST} exists and is not a git checkout" >&2
  exit 1
else
  git clone "$REPO_URL" "$DEST"
fi

exec "${DEST}/bootstrap.sh" "$@"
