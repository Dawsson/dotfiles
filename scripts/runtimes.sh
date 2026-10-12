#!/usr/bin/env bash
# Install mise and the toolchains declared in the global config.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

install_mise_binary() {
  if have mise; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install mise from https://mise.run"
    return 0
  fi
  curl -fsSL https://mise.run | sh
  export PATH="${HOME}/.local/bin:${PATH}"
  have mise || die "mise install finished but the binary is not on PATH"
}

install_runtimes() {
  section "Runtimes (mise)"
  if [[ "$OS" == "fedora" ]]; then
    install_mise_binary
  elif ! have mise; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log "would use the mise binary from Homebrew"
    else
      die "mise is not installed; Homebrew should have provided it"
    fi
  fi

  local config="${HOME}/.config/mise/config.toml"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would mise trust and install tools from ${config}"
    log "channels: node 24, bun, go, java zulu-21, rust, python, uv, pnpm"
    return 0
  fi
  if [[ ! -f "$config" ]]; then
    die "mise config is missing at ${config}"
  fi
  mise trust "$config"
  mise install
  mise reshim || true
  log "mise tools installed"
}

# Install the tiny `dx` CLI (status-cli only — not dx-tray) into ~/.cargo/bin.
install_dx_cli() {
  section "dx CLI"
  local status_dir="${DOTFILES_ROOT}/apps/status"
  if [[ ! -f "${status_dir}/Cargo.toml" ]]; then
    warn "apps/status missing; skip dx install"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would cargo install --path crates/status-cli (dx) into ~/.cargo/bin"
    return 0
  fi
  export PATH="${HOME}/.cargo/bin:${PATH}"
  if ! have cargo; then
    warn "cargo not on PATH; skip dx install (ensure mise rust is installed)"
    return 0
  fi
  (
    cd "$status_dir"
    cargo install --path crates/status-cli --locked --force
  )
  have dx || die "cargo install finished but dx is not on PATH (expected ~/.cargo/bin)"
  log "dx installed at $(command -v dx)"
}
