#!/usr/bin/env bash
# Homebrew packages, GUI casks, and the Helium default browser.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

install_homebrew() {
  if have brew; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Homebrew"
    return 0
  fi
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

macos_shellenv() {
  if [[ "$DRY_RUN" == "1" || "$(uname -s)" != "Darwin" ]]; then
    return 0
  fi
  if have brew; then
    eval "$(brew shellenv)"
  fi
}

macos_default_browser() {
  local id
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would set Helium as the default browser with duti"
    return 0
  fi
  id=""
  if have osascript; then
    id="$(osascript -e 'id of app "Helium"' 2>/dev/null || true)"
  fi
  if [[ -z "$id" ]]; then
    id="net.imput.helium"
  fi
  duti -s "$id" http || warn "duti could not claim http"
  duti -s "$id" https || warn "duti could not claim https"
  duti -s "$id" public.html all || warn "duti could not claim public.html"
  duti -s "$id" public.xhtml all || warn "duti could not claim public.xhtml"
  log "Helium (${id}) set as the default browser. Chrome stays installed."
}

macos_packages() {
  section "Homebrew"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    require_sudo
    install_homebrew
    macos_shellenv
  elif [[ "$DRY_RUN" == "1" ]]; then
    log "dry-run off macOS; printing the Homebrew steps"
  else
    die "Homebrew setup requires macOS"
  fi

  local arch
  arch="$(uname -m)"
  if [[ "$(uname -s)" == "Darwin" && "$arch" != "arm64" ]]; then
    warn "this bootstrap targets Apple silicon; continuing on ${arch}"
  fi

  run brew bundle --file "${DOTFILES_ROOT}/Brewfile"

  if [[ "$SKIP_GUI" == "1" ]]; then
    section "Tailscale CLI"
    if [[ "$DRY_RUN" == "1" ]]; then
      log "would brew install tailscale (CLI only; --skip-gui)"
    elif brew list --cask tailscale-app >/dev/null 2>&1 || brew list --formula tailscale >/dev/null 2>&1; then
      log "Tailscale already installed"
    else
      brew install tailscale
    fi
    return 0
  fi

  section "Homebrew apps"
  run brew bundle --file "${DOTFILES_ROOT}/Brewfile.gui"
  install_1password_helium
  macos_default_browser
}
