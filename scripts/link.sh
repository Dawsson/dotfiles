#!/usr/bin/env bash
# Symlink the repo's config files into the home directory.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

link_file() {
  local src="$1" dest="$2" current backup
  if [[ ! -e "$src" ]]; then
    die "missing config source: ${src}"
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would link ${dest} -> ${src}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      log "linked ${dest}"
      return 0
    fi
  elif [[ -e "$dest" ]]; then
    backup="${dest}.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
    log "backing up ${dest} -> ${backup}"
    mv "$dest" "$backup"
  fi
  ln -sfn "$src" "$dest"
  log "linked ${dest}"
}

install_tpm() {
  local dest="${HOME}/.tmux/plugins/tpm"
  if [[ -d "${dest}/.git" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would clone tmux plugin manager into ${dest}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$dest" \
    || warn "could not clone tmux plugin manager"
}

link_dotfiles() {
  section "Dotfiles"
  link_file "${DOTFILES_ROOT}/dotfiles/zsh/.zshrc" "${HOME}/.zshrc"
  link_file "${DOTFILES_ROOT}/dotfiles/git/.gitconfig" "${HOME}/.gitconfig"
  link_file "${DOTFILES_ROOT}/dotfiles/tmux/.tmux.conf" "${HOME}/.tmux.conf"
  link_file "${DOTFILES_ROOT}/dotfiles/starship/starship.toml" "${HOME}/.config/starship.toml"
  link_file "${DOTFILES_ROOT}/dotfiles/mise/config.toml" "${HOME}/.config/mise/config.toml"
  link_file "${DOTFILES_ROOT}/dotfiles/codex/cpa.env" "${HOME}/.codex/cpa.env"
  case "$OS" in
    macos)
      link_file "${DOTFILES_ROOT}/dotfiles/ghostty/config" \
        "${HOME}/Library/Application Support/com.mitchellh.ghostty/config"
      ;;
    fedora)
      link_file "${DOTFILES_ROOT}/dotfiles/ghostty/config" "${HOME}/.config/ghostty/config"
      link_file "${DOTFILES_ROOT}/dotfiles/keyd/app.conf" "${HOME}/.config/keyd/app.conf"
      ;;
    *)
      die "unsupported OS: ${OS}"
      ;;
  esac
  install_tpm
  ensure_bashrc_cpa
}

ensure_bashrc_cpa() {
  local bashrc="${HOME}/.bashrc" marker="# dawsson-dotfiles cpa.env"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would source ~/.codex/cpa.env from ~/.bashrc"
    return 0
  fi
  if [[ -f "$bashrc" ]] && grep -F -q "$marker" "$bashrc"; then
    log "bashrc already sources cpa.env"
    return 0
  fi
  if [[ -f "$bashrc" ]] && grep -F -q '.codex/cpa.env' "$bashrc"; then
    log "bashrc already sources cpa.env"
    return 0
  fi
  touch "$bashrc"
  if [[ -s "$bashrc" ]]; then
    printf '\n' >> "$bashrc"
  fi
  cat >> "$bashrc" <<'EOF'
# dawsson-dotfiles cpa.env
[ -f "$HOME/.codex/cpa.env" ] && . "$HOME/.codex/cpa.env"
EOF
  log "bashrc sources cpa.env"
}
