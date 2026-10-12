#!/usr/bin/env bash
# Detect the OS and run the matching bootstrap sections.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$ROOT"

# shellcheck source=lib/common.sh
source "${ROOT}/lib/common.sh"
# shellcheck source=scripts/link.sh
source "${ROOT}/scripts/link.sh"
# shellcheck source=scripts/runtimes.sh
source "${ROOT}/scripts/runtimes.sh"
# shellcheck source=scripts/agents.sh
source "${ROOT}/scripts/agents.sh"
# shellcheck source=scripts/macos.sh
source "${ROOT}/scripts/macos.sh"
# shellcheck source=scripts/fedora.sh
source "${ROOT}/scripts/fedora.sh"
# shellcheck source=scripts/setup.sh
source "${ROOT}/scripts/setup.sh"
# shellcheck source=scripts/browser-1password.sh
source "${ROOT}/scripts/browser-1password.sh"

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [options]

Sets up Dawson's macOS (Apple silicon) or Fedora Workstation 44 machine.
Safe to re-run. Existing config files are backed up before they are replaced.

Options:
  --skip-gui         Skip GUI apps, browsers, and Fedora desktop tweaks
  --skip-runtimes    Skip mise language and CLI installs
  --only-dotfiles    Only symlink configs and write the Codex CPA config
  --with-claude-cpa  Point Claude Code at the CPA host (unverified)
  --setup            Only link configs and run the sign-in prompts
  --skip-setup       Install packages without asking to sign in
  --dry-run          Print actions without changing the system
  -h, --help         Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --skip-gui
  ./bootstrap.sh --dry-run
  ./bootstrap.sh --setup
  ./bootstrap.sh --with-claude-cpa
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-gui) SKIP_GUI=1 ;;
      --skip-runtimes) SKIP_RUNTIMES=1 ;;
      --only-dotfiles) ONLY_DOTFILES=1 ;;
      --with-claude-cpa) WITH_CLAUDE_CPA=1 ;;
      --setup) SETUP_ONLY=1 ;;
      --skip-setup) SKIP_SETUP=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1 (try --help)"
        ;;
    esac
    shift
  done
}

detect_os() {
  local uname_s id
  if [[ -n "${DOTFILES_OS:-}" ]]; then
    if [[ "$DRY_RUN" != "1" && "$ONLY_DOTFILES" != "1" ]]; then
      die "DOTFILES_OS is only honored with --dry-run or --only-dotfiles"
    fi
    case "$DOTFILES_OS" in
      macos | fedora) OS="$DOTFILES_OS" ;;
      *) die "DOTFILES_OS must be macos or fedora" ;;
    esac
    return 0
  fi
  uname_s="$(uname -s)"
  case "$uname_s" in
    Darwin) OS="macos" ;;
    Linux)
      id=""
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
      fi
      if [[ "$id" == "fedora" ]]; then
        OS="fedora"
      else
        die "Unsupported Linux (${id:-unknown}). This bootstrap supports macOS and Fedora Workstation."
      fi
      ;;
    *) die "Unsupported operating system: ${uname_s}" ;;
  esac
}

current_login_shell() {
  local user entry
  user="$(current_user)"
  entry="$(getent passwd "$user" 2>/dev/null || true)"
  if [[ -n "$entry" ]]; then
    printf '%s' "${entry##*:}"
    return 0
  fi
  if [[ "$(uname -s)" == "Darwin" ]] && have dscl; then
    dscl . -read "/Users/${user}" UserShell 2>/dev/null | awk '{print $2}'
    return 0
  fi
  printf '%s' "${SHELL:-}"
}

ensure_login_shell() {
  local zsh_path current
  section "Login shell"
  zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    warn "zsh is not on PATH yet"
    return 0
  fi
  current="$(current_login_shell)"
  if [[ "${current##*/}" == "zsh" ]]; then
    log "login shell is already zsh"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$OS" == "fedora" ]]; then
      log "would run sudo chsh -s ${zsh_path} $(current_user); log out and back in"
    else
      log "would set the login shell to ${zsh_path}"
    fi
    return 0
  fi
  if ! grep -qx "$zsh_path" /etc/shells 2>/dev/null; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null || warn "could not add zsh to /etc/shells"
  fi
  if [[ "$OS" == "fedora" ]]; then
    if sudo chsh -s "$zsh_path" "$(current_user)"; then
      log "login shell set to ${zsh_path}. Log out and back in so new terminals use zsh."
    else
      warn "could not change the login shell. Run: sudo chsh -s ${zsh_path} $(current_user)"
    fi
    return 0
  fi
  if chsh -s "$zsh_path" "$(current_user)"; then
    log "login shell set to ${zsh_path}. Log out and back in so new terminals use zsh."
  else
    warn "could not change the login shell. Run: chsh -s ${zsh_path}"
  fi
}

print_next_steps() {
  if [[ "$SKIP_SETUP" == "1" ]]; then
    cat <<'EOF' >&2

Next:
  1. Re-run ./bootstrap.sh --setup from a terminal to sign in to 1Password, Tailscale, and GitHub.
  2. The CPA reference is ~/.codex/cpa-op-ref. Sign in to 1Password so the key file can be written.
  3. Codex uses https://devbox-dawson.tail20065d.ts.net/v1 only after Tailscale is up.
  4. Sign in to Cursor, Grok Bot, T3 Code, and Slack. On Fedora, log out so the zsh login shell, docker, libvirt, keyd, and GNOME extensions apply.
EOF
    return 0
  fi
  cat <<'EOF' >&2

Next:
  1. On Fedora, log out and back in so the login shell is zsh and cpa.env loads. Until then, bash still sources ~/.codex/cpa.env from ~/.bashrc.
  2. Shift+Command+Space opens 1Password Quick Access. On Fedora that chord is Shift+Super+Space. Super+W closes a tab and Super+Q quits, same as Command+W and Command+Q on the Mac.
  3. Codex uses https://devbox-dawson.tail20065d.ts.net/v1 only after Tailscale is up.
  4. Claude Code's Anthropic base URL is opt-in (`--with-claude-cpa`) and unverified.
  5. Sign in to Cursor, Grok Bot, T3 Code, and Slack. On Fedora, log out so the zsh login shell, docker, libvirt, keyd, and GNOME extensions apply.
  6. Later, run dotup to pull the latest dotfiles from GitHub and run this script again.
EOF
}

main() {
  parse_args "$@"
  if [[ "$(id -u)" -eq 0 && "$DRY_RUN" != "1" ]]; then
    die "Run bootstrap as your user. It will sudo when it needs to."
  fi
  if [[ "$SETUP_ONLY" == "1" && "$SKIP_SETUP" == "1" ]]; then
    die "--setup and --skip-setup cannot be used together"
  fi
  detect_os
  log "bootstrap for ${OS}"
  link_dotfiles
  install_codex_config
  if [[ "$SETUP_ONLY" == "1" ]]; then
    ensure_login_shell
    run_account_setup
    print_next_steps
    return 0
  fi
  if [[ "$ONLY_DOTFILES" == "1" ]]; then
    ensure_cpa_from_1password
    print_next_steps
    return 0
  fi
  case "$OS" in
    macos) macos_packages ;;
    fedora) fedora_packages ;;
  esac
  if [[ "$SKIP_RUNTIMES" != "1" ]]; then
    install_runtimes
  else
    log "skipping mise toolchains"
  fi
  install_agent_clis
  ensure_login_shell
  if [[ "$SKIP_SETUP" == "1" ]]; then
    log "skipping interactive account setup"
    ensure_cpa_from_1password
  else
    run_account_setup
  fi
  print_next_steps
}

main "$@"
