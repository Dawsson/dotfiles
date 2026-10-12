#!/usr/bin/env bash
# Guided sign-in after the packages are installed.
# Prompts read /dev/tty so `curl | bash` can still ask questions.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if [[ -n "${DOTFILES_SETUP_LOADED:-}" ]]; then
  return 0
fi
DOTFILES_SETUP_LOADED=1

have_tty() {
  [[ -r /dev/tty && -w /dev/tty ]]
}

prompt_line() {
  local reply=""
  printf '%s' "$1" >/dev/tty
  IFS= read -r reply </dev/tty || reply=""
  printf '%s' "$reply"
}

prompt_secret() {
  local reply=""
  printf '%s' "$1" >/dev/tty
  IFS= read -r -s reply </dev/tty || reply=""
  printf '\n' >/dev/tty
  printf '%s' "$reply"
}

prompt_enter() {
  printf '%s' "$1" >/dev/tty
  IFS= read -r _ </dev/tty || true
  printf '\n' >/dev/tty
}

confirm() {
  local reply
  reply="$(prompt_line "$1 [y/N] ")"
  case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

open_1password_app() {
  if [[ "$OS" == "macos" ]] && have open; then
    open -a "1Password" >/dev/null 2>&1 || true
    return 0
  fi
  if have gtk-launch; then
    gtk-launch 1password >/dev/null 2>&1 && return 0
  fi
  if have 1password; then
    1password >/dev/null 2>&1 &
    return 0
  fi
  warn "Open the 1Password app yourself."
}

op_signed_in() {
  have op && op whoami >/dev/null 2>&1
}

setup_1password_account() {
  local session
  section "1Password"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would open 1Password and sign in the CLI before anything else"
    if [[ "$OS" == "macos" ]]; then
      log "Quick Access on macOS is Shift+Command+Space"
    else
      log "Quick Access on Fedora is Shift+Super+Space (1password --quick-access)"
    fi
    return 0
  fi
  if ! have op; then
    warn "1Password CLI is not installed yet. Install the app and CLI, then re-run ./bootstrap.sh --setup."
    return 0
  fi
  if op_signed_in; then
    log "1Password CLI is already signed in"
    return 0
  fi
  cat >/dev/tty <<'EOF'
Sign in to the 1Password app, then turn on Settings → Developer → Integrate with 1Password CLI.
Shift+Command+Space opens Quick Access on macOS. On Fedora that chord is Shift+Super+Space.
EOF
  open_1password_app
  prompt_enter "Press Enter once 1Password is unlocked and the CLI integration is on."
  if op_signed_in; then
    log "1Password CLI is signed in"
    return 0
  fi
  if confirm "The CLI is not signed in yet. Run op signin now?"; then
    session="$(op signin </dev/tty || true)"
    case "$session" in
      export\ OP_SESSION_*) eval "$session" ;;
    esac
  fi
  if op_signed_in; then
    log "1Password CLI is signed in"
  else
    warn "1Password CLI is still not signed in. Run op signin when the app is unlocked."
  fi
}

tailscale_logged_in() {
  have tailscale && tailscale status --json 2>/dev/null \
    | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'
}

setup_tailscale_account() {
  section "Tailscale"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would run tailscale up"
    return 0
  fi
  if ! have tailscale; then
    warn "tailscale is not installed yet"
    return 0
  fi
  if tailscale_logged_in; then
    log "Tailscale is already logged in"
    return 0
  fi
  log "Approve the Tailscale login URL. The CPA host will not resolve before this."
  if [[ "$OS" == "macos" ]] && have open; then
    open -a "Tailscale" >/dev/null 2>&1 || true
  fi
  if [[ "$OS" == "fedora" && "$(id -u)" -ne 0 ]]; then
    # Redirect is for tailscale's login prompt. The shell opens /dev/tty; sudo only forwards that stdin.
    # shellcheck disable=SC2024
    sudo tailscale up </dev/tty || warn "tailscale up failed"
  else
    tailscale up </dev/tty || warn "tailscale up failed"
  fi
}

git_uses_gh_credential() {
  git config --global --get-regexp 'credential\.https://github\.com\.helper' 2>/dev/null \
    | grep -q 'gh auth git-credential'
}

setup_github_account() {
  section "GitHub and git"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would run gh auth login --hostname github.com --git-protocol https --web"
    log "git already uses gh auth git-credential; gh auth setup-git is not run"
    return 0
  fi
  if ! have gh || ! have git; then
    warn "gh and git are both required. Re-run ./bootstrap.sh --setup after they are installed."
    return 0
  fi
  log "Git name: $(git config --global --get user.name || echo unset)"
  log "Git email: $(git config --global --get user.email || echo unset)"
  if git_uses_gh_credential; then
    log "GitHub HTTPS uses gh as the credential helper. gh auth setup-git is not run, because it would rewrite the symlinked gitconfig."
  else
    warn "The gh credential helper is missing from ~/.gitconfig. The linked dotfiles should provide it."
  fi
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    log "gh is already signed in to github.com"
    return 0
  fi
  log "Signing in to GitHub in the browser."
  gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key </dev/tty \
    || warn "gh auth login failed"
}

CPA_OP_REF_DEFAULT='op://Personal/Devbox CPA client key/credential'

trim_line() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

ensure_cpa_from_1password() {
  local ref_file key_file ref key
  ref_file="${HOME}/.codex/cpa-op-ref"
  key_file="${HOME}/.codex/cpa-client-key"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would write ${CPA_OP_REF_DEFAULT} to ~/.codex/cpa-op-ref when that file is missing"
    log "would save ~/.codex/cpa-client-key from 1Password when op is signed in"
    return 0
  fi
  mkdir -p "${HOME}/.codex"
  if [[ ! -s "$ref_file" ]]; then
    write_private_file "$ref_file" "$CPA_OP_REF_DEFAULT"
    log "saved the 1Password CPA reference"
  fi
  if [[ -s "$key_file" ]]; then
    log "CPA key file is already present"
    return 0
  fi
  if ! op_signed_in; then
    log "1Password CLI is not signed in. The next shell reads the CPA key after op sign-in."
    return 0
  fi
  IFS= read -r ref < "$ref_file" || ref=""
  ref="$(trim_line "$ref")"
  case "$ref" in
    op://*) ;;
    *)
      warn "cpa-op-ref is not an op:// URI"
      return 0
      ;;
  esac
  key="$(op read "$ref" 2>/dev/null || true)"
  if [[ -z "$key" ]]; then
    warn "op read did not return the CPA key"
    return 0
  fi
  write_private_file "$key_file" "$key"
  unset key
  log "CPA key saved from 1Password"
}

write_private_file() {
  local dest="$1" content="$2" old_umask
  old_umask="$(umask)"
  mkdir -p "$(dirname "$dest")"
  umask 077
  printf '%s\n' "$content" > "$dest"
  umask "$old_umask"
  chmod 600 "$dest" || true
}

setup_cpa_key() {
  local choice key ref
  section "CPA key"
  ensure_cpa_from_1password
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  if [[ -s "${HOME}/.codex/cpa-client-key" ]]; then
    return 0
  fi
  cat >/dev/tty <<'EOF'
The CPA key is not stored in the dotfiles repo.
  1) Paste the key now
  2) Save an op:// item reference and read it with the 1Password CLI
  3) Skip
EOF
  choice="$(prompt_line "Choice [3]: ")"
  case "$choice" in
    1)
      key="$(prompt_secret "Paste the CPA key: ")"
      if [[ -z "$key" ]]; then
        warn "No key entered"
        return 0
      fi
      write_private_file "${HOME}/.codex/cpa-client-key" "$key"
      unset key
      log "CPA key saved to ~/.codex/cpa-client-key"
      ;;
    2)
      ref="$(prompt_line "op:// URI: ")"
      case "$ref" in
        op://*)
          write_private_file "${HOME}/.codex/cpa-op-ref" "$ref"
          # shellcheck disable=SC1091
          . "${HOME}/.codex/cpa.env" || true
          unset CPA_API_KEY ANTHROPIC_AUTH_TOKEN
          if [[ -s "${HOME}/.codex/cpa-client-key" ]]; then
            log "CPA key saved from 1Password"
          else
            warn "Saved the op:// reference. The next shell will read it once op is signed in."
          fi
          ;;
        *)
          warn "That is not an op:// URI. Nothing was saved."
          ;;
      esac
      ;;
    *)
      log "Skipped the CPA key"
      ;;
  esac
}

setup_cua_account() {
  if [[ "$OS" != "fedora" ]]; then
    return 0
  fi
  section "Cua"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would offer cua auth login"
    return 0
  fi
  if ! have cua; then
    warn "cua is not installed"
    return 0
  fi
  if confirm "Sign in to the Cua CLI now?"; then
    cua auth login </dev/tty || warn "cua auth login failed"
  fi
}

run_account_setup() {
  if [[ "$DRY_RUN" == "1" ]]; then
    setup_1password_account
    setup_tailscale_account
    setup_github_account
    setup_cpa_key
    setup_cua_account
    return 0
  fi
  if ! have_tty; then
    warn "No terminal is available for sign-in prompts. Re-run ./bootstrap.sh --setup from a terminal."
    return 0
  fi
  section "Account setup"
  cat >/dev/tty <<'EOF'
This walks through the accounts the machine needs. Each step that is already done is skipped.
EOF
  setup_1password_account
  setup_tailscale_account
  setup_github_account
  setup_cpa_key
  setup_cua_account
}
