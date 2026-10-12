#!/usr/bin/env bash
# Thin wrapper: day-to-day updates go through `dx update`.
# Example: dotup --skip-gui
set -euo pipefail

resolve_root() {
  local link root
  link="${HOME}/.zshrc"
  if [[ -L "$link" ]]; then
    link="$(readlink "$link")"
    root="$(cd "$(dirname "$link")/../.." && pwd)" || return 1
    if [[ -f "${root}/bootstrap.sh" ]]; then
      printf '%s\n' "$root"
      return 0
    fi
  fi
  if [[ -n "${DOTFILES_DIR:-}" && -f "${DOTFILES_DIR}/bootstrap.sh" ]]; then
    printf '%s\n' "$DOTFILES_DIR"
    return 0
  fi
  if [[ -f "${HOME}/.dotfiles/bootstrap.sh" ]]; then
    printf '%s\n' "${HOME}/.dotfiles"
    return 0
  fi
  return 1
}

ensure_dx() {
  if command -v dx >/dev/null 2>&1; then
    return 0
  fi
  local root cargo_bin
  root="$(resolve_root)" || {
    printf 'dotup: cannot find the dotfiles checkout (expected ~/.zshrc symlink or ~/.dotfiles)\n' >&2
    return 1
  }
  if [[ ! -f "${root}/apps/status/Cargo.toml" ]]; then
    printf 'dotup: apps/status missing in %s — pull main first\n' "$root" >&2
    return 1
  fi
  cargo_bin=""
  if command -v cargo >/dev/null 2>&1; then
    cargo_bin="$(command -v cargo)"
  elif [[ -x "${HOME}/.cargo/bin/cargo" ]]; then
    cargo_bin="${HOME}/.cargo/bin/cargo"
  else
    printf 'dotup: cargo not found; run bootstrap once, or: curl -fsSL …/install.sh | bash\n' >&2
    return 1
  fi
  printf '==> installing dx CLI (first-time)\n' >&2
  (cd "${root}/apps/status" && "$cargo_bin" install --path crates/status-cli --locked --force)
  export PATH="${HOME}/.cargo/bin:${PATH}"
  command -v dx >/dev/null 2>&1 || {
    printf 'dotup: dx still missing after cargo install\n' >&2
    return 1
  }
}

ensure_dx
exec dx update "$@"
