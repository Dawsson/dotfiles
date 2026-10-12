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
