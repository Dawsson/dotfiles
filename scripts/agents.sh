#!/usr/bin/env bash
# Claude Code, Codex CLI, and the CPA client config.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

install_claude_dnf() {
  local tmp fpr expected
  expected="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would add the Claude Code dnf repo and install claude-code"
    return 0
  fi
  tmp="$(mktemp)"
  curl -fsSL https://downloads.claude.ai/keys/claude-code.asc -o "$tmp"
  fpr="$(gpg --show-keys --with-colons "$tmp" | awk -F: '/^fpr:/ { print $10; exit }')"
  if [[ "$fpr" != "$expected" ]]; then
    rm -f "$tmp"
    die "Claude Code signing key fingerprint mismatch"
  fi
  sudo rpm --import "$tmp"
  rm -f "$tmp"
  write_root_file /etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
  sudo dnf install -y claude-code
}

install_claude_native() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Claude Code from https://claude.ai/install.sh"
    return 0
  fi
  if ! curl -fsSL https://claude.ai/install.sh | bash; then
    warn "Claude Code native installer failed"
    return 1
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
}

install_claude() {
  section "Claude Code"
  if have claude; then
    log "Claude Code already installed ($(claude --version 2>/dev/null | head -n 1 || true))"
    return 0
  fi
  if [[ "$OS" == "fedora" ]]; then
    if install_claude_dnf; then
      return 0
    fi
    warn "Claude Code dnf install failed; trying the native installer"
  fi
  install_claude_native
}

install_codex() {
  section "Codex CLI"
  if have codex; then
    log "Codex CLI already installed ($(codex --version 2>/dev/null | head -n 1 || true))"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Codex CLI from https://chatgpt.com/codex/install.sh"
    return 0
  fi
  if ! curl -fsSL https://chatgpt.com/codex/install.sh | sh; then
    warn "Codex CLI installer failed"
    return 1
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
}

install_codex_config() {
  section "Codex CPA config"
  local dest="${HOME}/.codex/config.toml"
  local status
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would merge the CPA provider into ${dest}"
    if [[ "$WITH_CLAUDE_CPA" == "1" ]]; then
      log "would opt Claude Code into the unverified CPA Anthropic endpoint"
    fi
    return 0
  fi
  mkdir -p "${HOME}/.codex"
  chmod 700 "${HOME}/.codex"
  status="$(py merge-codex "$dest" "${DOTFILES_ROOT}/dotfiles/codex/config.toml")"
  log "Codex config ${status}"
  if [[ "$WITH_CLAUDE_CPA" == "1" ]]; then
    printf '%s\n' "Enabled by bootstrap --with-claude-cpa. CPA Anthropic compatibility is unverified." \
      > "${HOME}/.codex/claude-cpa.enable"
    log "Claude Code CPA opt-in written to ~/.codex/claude-cpa.enable"
  fi
}

install_agent_clis() {
  install_claude || warn "Claude Code was not installed"
  install_codex || warn "Codex CLI was not installed"
}
