#!/usr/bin/env bash
# Shared helpers. Safe to source more than once. Bash 3.2 compatible.

if [[ -n "${DOTFILES_COMMON_LOADED:-}" ]]; then
  return 0
fi
DOTFILES_COMMON_LOADED=1

if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  _common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DOTFILES_ROOT="$(cd "${_common_dir}/.." && pwd)"
fi

: "${DRY_RUN:=0}"
: "${SKIP_GUI:=0}"
: "${SKIP_RUNTIMES:=0}"
: "${ONLY_DOTFILES:=0}"
: "${WITH_CLAUDE_CPA:=0}"
: "${SKIP_SETUP:=0}"
: "${SETUP_ONLY:=0}"

log() { printf '==> %s\n' "$*" >&2; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
section() { printf '\n## %s\n' "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'dry-run:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi
  "$@"
}

run_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

require_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  have sudo || die "sudo is required"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  sudo -v
}

current_user() {
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s' "$SUDO_USER"
  else
    printf '%s' "${USER:-$(id -un)}"
  fi
}

download() {
  local url="$1" dest="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would download ${url}"
    return 0
  fi
  curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
}

ensure_user_bin() {
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  mkdir -p "${HOME}/.local/bin"
}

install_user_bin() {
  local src="$1" name="$2"
  ensure_user_bin
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install ${name} into ~/.local/bin"
    return 0
  fi
  install -m 0755 "$src" "${HOME}/.local/bin/${name}"
}

write_root_file() {
  local dest="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would write ${dest}"
    cat >/dev/null
    return 0
  fi
  sudo mkdir -p "$(dirname "$dest")"
  sudo tee "$dest" >/dev/null
}

systemd_active() {
  [[ -d /run/systemd/system ]] && have systemctl
}

enable_system_service() {
  local unit="$1"
  if ! systemd_active; then
    warn "systemd is not running; enable ${unit} on the real machine"
    return 0
  fi
  run_root systemctl enable --now "$unit"
}

ensure_group_member() {
  local user="$1" group="$2"
  if ! getent group "$group" >/dev/null 2>&1; then
    warn "group ${group} does not exist yet"
    return 0
  fi
  if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would add ${user} to ${group}"
    return 0
  fi
  sudo usermod -aG "$group" "$user"
  warn "${user} was added to ${group}. Log out and back in so it applies."
}

dnf_install() {
  if [[ "$#" -eq 0 ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would dnf install: $*"
    return 0
  fi
  if sudo dnf install -y "$@"; then
    return 0
  fi
  warn "batch dnf install failed; retrying one package at a time"
  local pkg
  for pkg in "$@"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      continue
    fi
    sudo dnf install -y "$pkg" || warn "could not install ${pkg}"
  done
}

clone_or_update() {
  local url="$1" dest="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would clone ${url} into ${dest}"
    return 0
  fi
  if [[ -d "${dest}/.git" ]]; then
    git -C "$dest" pull --ff-only || warn "could not fast-forward ${dest}"
  else
    rm -rf "$dest"
    git clone --depth 1 "$url" "$dest"
  fi
}

py() {
  python3 "${DOTFILES_ROOT}/scripts/pyhelper.py" "$@"
}

export PATH="${HOME}/.local/bin:${PATH}"
