#!/usr/bin/env bash
# Local checks that do not install packages or change the real home directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "missing file $1"
}

echo "== shell syntax"
while IFS= read -r script; do
  bash -n "$script"
done < <(find . -name '*.sh' -not -path './.git/*')
zsh -n dotfiles/zsh/.zshrc
bash -n dotfiles/codex/cpa.env
python3 -m py_compile scripts/pyhelper.py

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck"
  shellcheck -x install.sh bootstrap.sh lib/common.sh scripts/*.sh
else
  echo "== shellcheck skipped (not installed)"
fi

echo "== repo hygiene"
if grep -n '/Users/' dotfiles/zsh/.zshrc; then
  fail "zshrc still has a /Users path"
fi
packages="$(grep -hE '^(brew|cask) ' Brewfile Brewfile.gui || true)"
if printf '%s\n' "$packages" | grep -E 'k9s|kubectx|k3d|k3sup|stern|stripe-cli|flyctl|alt-tab|karabiner|hammerspoon|epic-games|lunar-client|prismlauncher|jetbrains-toolbox|visual-studio-code|termius'; then
  fail "Brewfile contains a package that should not be installed"
fi
if printf '%s\n' "$packages" | grep -E '(^|[^a-z-])(discord|warp|zed|helm|steam|roblox)([^a-z-]|$)'; then
  fail "Brewfile contains a package that should not be installed"
fi
if find . -path './.git' -prune -o -name 'cpa-client-key' -print | grep -q .; then
  fail "cpa-client-key must not be committed"
fi
if [[ -f "${HOME}/.codex/cpa-client-key" ]]; then
  fail "refusing to run with a key file assertion against the real home"
fi

echo "== help and unsupported host"
./bootstrap.sh --help >/dev/null
if ./bootstrap.sh --dry-run >/dev/null 2>&1; then
  fail "dry-run on this host should refuse when it is not macOS or Fedora"
fi

echo "== dry-run plans"
mac_plan="$(DOTFILES_OS=macos ./bootstrap.sh --dry-run 2>&1)"
printf '%s\n' "$mac_plan" | grep -q 'Brewfile' || fail "mac plan missing Brewfile"
printf '%s\n' "$mac_plan" | grep -q 'Brewfile.gui' || fail "mac plan missing GUI casks"
printf '%s\n' "$mac_plan" | grep -q 'Helium' || fail "mac plan missing Helium"
printf '%s\n' "$mac_plan" | grep -q 'mise' || fail "mac plan missing mise"

fed_plan="$(DOTFILES_OS=fedora ./bootstrap.sh --dry-run 2>&1)"
printf '%s\n' "$fed_plan" | grep -q 'Docker Engine' || fail "fedora plan missing Docker"
printf '%s\n' "$fed_plan" | grep -q 'Cua CLI' || fail "fedora plan missing Cua"
printf '%s\n' "$fed_plan" | grep -q 'keyd' || fail "fedora plan missing keyd"
printf '%s\n' "$fed_plan" | grep -q 'Helium' || fail "fedora plan missing Helium"
printf '%s\n' "$fed_plan" | grep -q 'Grok Bot' || fail "fedora plan missing Grok Bot"
printf '%s\n' "$fed_plan" | grep -q 'T3 Code' || fail "fedora plan missing T3 Code"
printf '%s\n' "$fed_plan" | grep -q 'Cursor' || fail "fedora plan missing Cursor"

skip_plan="$(DOTFILES_OS=fedora ./bootstrap.sh --dry-run --skip-gui 2>&1)"
printf '%s\n' "$skip_plan" | grep -q 'Docker Engine' || fail "skip-gui dropped Docker"
if printf '%s\n' "$skip_plan" | grep -q 'would install keyd'; then
  fail "--skip-gui still plans keyd"
fi
if printf '%s\n' "$skip_plan" | grep -q 'would set Helium'; then
  fail "--skip-gui still plans the default browser"
fi

claude_plan="$(DOTFILES_OS=macos ./bootstrap.sh --dry-run --with-claude-cpa --skip-gui --skip-runtimes 2>&1)"
printf '%s\n' "$claude_plan" | grep -q 'unverified' || fail "claude opt-in was not mentioned"

printf '%s\n' "$mac_plan" | grep -q '1Password extension' || fail "mac plan missing the Helium 1Password extension"
printf '%s\n' "$fed_plan" | grep -q '1Password extension' || fail "fedora plan missing the Helium 1Password extension"
printf '%s\n' "$fed_plan" | grep -q 'would bind Shift+Super+Space' || fail "fedora plan missing 1Password Quick Access"
printf '%s\n' "$fed_plan" | grep -q 'Slack' || fail "fedora plan missing Slack"
printf '%s\n' "$fed_plan" | grep -q 'Tailscale systray' || fail "fedora plan missing the Tailscale desktop app"
printf '%s\n' "$fed_plan" | grep -q '/usr/bin/ulauncher-toggle' || fail "fedora plan missing the Ulauncher shortcut command"
printf '%s\n' "$fed_plan" | grep -q 'dawsson-ulauncher' || fail "fedora plan missing the Ulauncher helper"
printf '%s\n' "$fed_plan" | grep -q '.local/bin/dotup' || fail "fedora plan missing the dotup command"
printf '%s\n' "$fed_plan" | grep -q 'sudo chsh -s' || fail "fedora plan missing sudo chsh"
printf '%s\n' "$fed_plan" | grep -q 'cpa.env from ~/.bashrc' || fail "fedora plan missing the bashrc CPA fallback"
printf '%s\n' "$fed_plan" | grep -q 'op://Personal/Devbox CPA client key/credential' || fail "fedora plan missing the default CPA reference"
printf '%s\n' "$fed_plan" | grep -q 'restart managed services' || fail "fedora plan missing service refresh"
grep -q 'w = macro(leftcontrol+w)' dotfiles/keyd/default.conf || fail "Super+W is not close"
grep -q 'q = macro(leftcontrol+q)' dotfiles/keyd/default.conf || fail "Super+Q is not quit"
grep -q 'space = macro(leftmeta+space)' dotfiles/keyd/default.conf || fail "Super+Space is not a real Super chord"
grep -q 'cmd.w = C-S-w' dotfiles/keyd/app.conf || fail "terminal Super+W is not close-tab"
grep -q 'dotup()' dotfiles/zsh/.zshrc || fail "zshrc missing dotup"
[[ -x scripts/dotup.sh ]] || fail "dotup command is not executable"
if printf '%s\n' "$skip_plan" | grep -q 'Tailscale systray'; then
  fail "--skip-gui still plans the Tailscale desktop app"
fi
printf '%s\n' "$mac_plan" | grep -q 'gh auth login' || fail "mac plan missing GitHub sign-in"
printf '%s\n' "$mac_plan" | grep -q 'setup-git is not run' || fail "mac plan should skip gh auth setup-git"
if printf '%s\n' "$skip_plan" | grep -q 'would bind Shift+Super+Space'; then
  fail "--skip-gui still plans 1Password Quick Access"
fi
if printf '%s\n' "$skip_plan" | grep -q '1Password extension'; then
  fail "--skip-gui still plans the Helium 1Password extension"
fi

setup_plan="$(DOTFILES_OS=fedora ./bootstrap.sh --dry-run --setup 2>&1)"
printf '%s\n' "$setup_plan" | grep -q 'tailscale up' || fail "setup plan missing Tailscale"
printf '%s\n' "$setup_plan" | grep -q 'gh auth login' || fail "setup plan missing GitHub"
printf '%s\n' "$setup_plan" | grep -q '1Password' || fail "setup plan missing 1Password"
if printf '%s\n' "$setup_plan" | grep -q 'Docker Engine'; then
  fail "--setup still plans package installation"
fi

skip_setup="$(DOTFILES_OS=macos ./bootstrap.sh --dry-run --skip-setup --skip-gui --skip-runtimes 2>&1)"
if printf '%s\n' "$skip_setup" | grep -q 'gh auth login'; then
  fail "--skip-setup still plans GitHub sign-in"
fi

echo "== dotfiles install in a temp home"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
HOME="$tmp" DOTFILES_OS=fedora ./bootstrap.sh --only-dotfiles >/dev/null
[[ -L "$tmp/.zshrc" ]] || fail "zshrc was not linked"
[[ -L "$tmp/.local/bin/dotup" ]] || fail "dotup command was not installed"
[[ "$(readlink "$tmp/.local/bin/dotup")" == "$ROOT/scripts/dotup.sh" ]] || fail "dotup link target"
[[ "$(readlink "$tmp/.zshrc")" == "$ROOT/dotfiles/zsh/.zshrc" ]] || fail "zshrc link target"
[[ -L "$tmp/.config/ghostty/config" ]] || fail "linux ghostty config was not linked"
[[ -L "$tmp/.codex/cpa.env" ]] || fail "cpa.env was not linked"
grep -q 'devbox-dawson.tail20065d.ts.net/v1' "$tmp/.codex/config.toml" || fail "CPA base URL missing"
grep -q 'model_provider = "cpa"' "$tmp/.codex/config.toml" || fail "CPA is not the default provider"
HOME="$tmp" DOTFILES_OS=fedora ./bootstrap.sh --only-dotfiles >/dev/null
find "$tmp" -name '*.dotfiles-backup.*' | grep -q . && fail "re-run created a backup"
HOME="$tmp" DOTFILES_OS=macos ./bootstrap.sh --only-dotfiles >/dev/null
[[ -L "$tmp/Library/Application Support/com.mitchellh.ghostty/config" ]] || fail "macOS ghostty path"
grep -F -q '# dawsson-dotfiles cpa.env' "$tmp/.bashrc" || fail "bashrc does not source cpa.env"
[[ "$(grep -F -c '# dawsson-dotfiles cpa.env' "$tmp/.bashrc")" -eq 1 ]] || fail "bashrc CPA source was duplicated"
grep -F -q 'op://Personal/Devbox CPA client key/credential' "$tmp/.codex/cpa-op-ref" || fail "default CPA reference was not written"
[[ "$(stat -c %a "$tmp/.codex/cpa-op-ref")" == "600" ]] || fail "cpa-op-ref is not mode 600"

echo "== codex merge preserves an existing config"
work="$(mktemp -d)"
cat > "$work/config.toml" <<'EOF'
model = "gpt-5.5"
model_provider = "openai"

[notice]
ignore = true
EOF
python3 scripts/pyhelper.py merge-codex "$work/config.toml" dotfiles/codex/config.toml | grep -q '^updated ' \
  || fail "existing config was not updated"
grep -q 'model = "gpt-5.5"' "$work/config.toml" || fail "existing model was dropped"
grep -q 'model_provider = "openai"' "$work/config.toml" || fail "existing provider was replaced"
grep -q '\[notice\]' "$work/config.toml" || fail "existing section was dropped"
grep -q 'base_url = "https://devbox-dawson.tail20065d.ts.net/v1"' "$work/config.toml" || fail "provider was not added"
python3 scripts/pyhelper.py merge-codex "$work/config.toml" dotfiles/codex/config.toml | grep -qx unchanged \
  || fail "second merge was not a no-op"
find "$work" -name '*.dotfiles-backup.*' | grep -q . || fail "missing backup of the original config"

echo "== cpa.env loads the key and keeps Claude opt-in off"
printf '%s\n' 'test-key' > "$tmp/.codex/cpa-client-key"
chmod 600 "$tmp/.codex/cpa-client-key"
# shellcheck disable=SC1091
HOME="$tmp" bash -c 'source "$HOME/.codex/cpa.env"; [ "$CPA_API_KEY" = "test-key" ] && [ -z "${ANTHROPIC_BASE_URL:-}" ]' \
  || fail "cpa.env did not export only the key"
touch "$tmp/.codex/claude-cpa.enable"
# shellcheck disable=SC1091
HOME="$tmp" bash -c 'source "$HOME/.codex/cpa.env"; [ "$ANTHROPIC_BASE_URL" = "https://devbox-dawson.tail20065d.ts.net" ] && [ "$ANTHROPIC_AUTH_TOKEN" = "test-key" ]' \
  || fail "claude opt-in did not export the unverified Anthropic endpoint"
case "${ANTHROPIC_BASE_URL:-}" in
  */v1) fail "ANTHROPIC_BASE_URL leaked into this shell with a /v1 suffix" ;;
esac

echo "== cpa.env keeps spaces in the 1Password reference"
rm -f "$tmp/.codex/cpa-client-key"
mkdir -p "$tmp/bin"
cat > "$tmp/bin/op" <<'EOF'
#!/bin/sh
printf '%s\n' "$2" > "$HOME/op-ref-seen"
printf '%s\n' 'from-op'
EOF
chmod +x "$tmp/bin/op"
PATH="$tmp/bin:$PATH" HOME="$tmp" bash -c 'source "$HOME/.codex/cpa.env"; [ "$CPA_API_KEY" = "from-op" ]' \
  || fail "cpa.env did not read the spaced op reference"
grep -F -q 'op://Personal/Devbox CPA client key/credential' "$tmp/op-ref-seen" \
  || fail "op read dropped spaces from the CPA reference"
[[ "$(stat -c %a "$tmp/.codex/cpa-client-key")" == "600" ]] || fail "materialized CPA key is not mode 600"

echo "== release metadata"
t3="$(python3 scripts/pyhelper.py t3-nightly x86_64)"
printf '%s\n' "$t3" | grep -Eq '^(appimage|rpm)$' || fail "unexpected T3 Code artifact kind"
printf '%s\n' "$t3" | grep -q 'github.com/pingdotgg/t3code/releases/download' || fail "T3 Code URL is not a GitHub release"
font="$(python3 scripts/pyhelper.py github-asset ryanoasis/nerd-fonts '^JetBrainsMono\.(tar\.xz|zip)$')"
printf '%s\n' "$font" | grep -q 'JetBrainsMono' || fail "JetBrainsMono Nerd Font URL"
pscale="$(python3 scripts/pyhelper.py github-asset planetscale/cli 'linux_amd64\.rpm$')"
printf '%s\n' "$pscale" | grep -q 'linux_amd64.rpm' || fail "pscale rpm URL"
lazygit="$(python3 scripts/pyhelper.py github-asset jesseduffield/lazygit 'linux_x86_64\.tar\.gz$')"
printf '%s\n' "$lazygit" | grep -q 'linux_x86_64.tar.gz' || fail "lazygit archive URL"
btop="$(python3 scripts/pyhelper.py github-asset aristocratos/btop 'btop-x86_64-unknown-linux-musl\.tar\.gz$')"
printf '%s\n' "$btop" | grep -q 'btop-x86_64-unknown-linux-musl.tar.gz' || fail "btop archive URL"
feed="$(curl -fsSL https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand)"
printf '%s\n' "$feed" | python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["rpmUrl"].endswith(".rpm")'

echo "ok"
