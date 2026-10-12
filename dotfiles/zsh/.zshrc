# Dawson's zshrc for macOS and Fedora.
# Paths that only exist on one OS are guarded. Secrets stay in files, not here.

_prepend_path() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

_prepend_path "$HOME/.local/bin"

if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  if [[ -d /opt/homebrew/opt/coreutils/libexec/gnubin ]]; then
    _prepend_path /opt/homebrew/opt/coreutils/libexec/gnubin
  elif [[ -d /usr/local/opt/coreutils/libexec/gnubin ]]; then
    _prepend_path /usr/local/opt/coreutils/libexec/gnubin
  fi
  if [[ -r /opt/homebrew/etc/grc.zsh ]]; then
    source /opt/homebrew/etc/grc.zsh
  elif [[ -r /usr/local/etc/grc.zsh ]]; then
    source /usr/local/etc/grc.zsh
  fi
  # OrbStack's shell hook is mac-only and is not always installed.
  if [[ -r "$HOME/.orbstack/shell/init.zsh" ]]; then
    source "$HOME/.orbstack/shell/init.zsh"
  fi
elif [[ -r /etc/grc.zsh ]]; then
  source /etc/grc.zsh
fi

_prepend_path "$HOME/.cargo/bin"
_prepend_path "$HOME/.bun/bin"
_prepend_path "$HOME/.nub/bin"
_prepend_path "$HOME/.grok/bin"
_prepend_path "$HOME/.opencode/bin"
_prepend_path "$HOME/.lmstudio/bin"
_prepend_path "$HOME/.ascii/bin"

export PATH

if [[ "${TERM:-}" != "dumb" ]] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi

cl() { claude --dangerously-skip-permissions "$@"; }
c() {
  if [[ "${1:-}" == "resume" ]]; then
    shift
    codex resume --dangerously-bypass-approvals-and-sandbox "$@"
    return
  fi

  d agents run --dangerously-bypass-approvals-and-sandbox "$@"
}
_cxlb_load_codex_lb_key() {
  [[ -n "${CODEX_LB_API_KEY:-}" ]] && return 0
  local key
  key="$(awk -F'"' '/api_key = / { print $2; exit }' "$HOME/.codex/config.toml" 2>/dev/null)"
  [[ -n "$key" ]] && export CODEX_LB_API_KEY="$key"
}
_cxlb_write_profile() {
  mkdir -p "$HOME/.codex"
  cat > "$HOME/.codex/cxlb.config.toml" <<EOF
model = "gpt-5.5"
model_provider = "codex-lb"
model_reasoning_effort = "medium"
model_context_window = 225000
model_auto_compact_token_limit = 200000
suppress_unstable_features_warning = true

[features]
fast_mode = false
responses_websockets = true

[model_providers.codex-lb]
name = "openai"
base_url = "https://api.clb.dev.dawson.gg/backend-api/codex"
wire_api = "responses"
env_key = "CODEX_LB_API_KEY"
supports_websockets = true
requires_openai_auth = true
EOF
}
_cxlb_ensure_app_server() {
  local port="${CX_APP_SERVER_PORT:-8875}"
  local listen="ws://127.0.0.1:${port}"
  local ready_url="http://127.0.0.1:${port}/readyz"
  local pid_file="$HOME/.codex/cxlb-app-server.pid"
  local log_file="$HOME/.codex/cxlb-app-server.log"
  local -a server_config
  server_config=(
    -c 'model="gpt-5.5"'
    -c 'model_provider="codex-lb"'
    -c 'model_reasoning_effort="medium"'
    -c 'model_context_window=225000'
    -c 'model_auto_compact_token_limit=200000'
    -c 'suppress_unstable_features_warning=true'
    -c 'features.fast_mode=false'
    -c 'features.responses_websockets=true'
    -c 'model_providers.codex-lb.name="openai"'
    -c 'model_providers.codex-lb.base_url="https://api.clb.dev.dawson.gg/backend-api/codex"'
    -c 'model_providers.codex-lb.wire_api="responses"'
    -c 'model_providers.codex-lb.env_key="CODEX_LB_API_KEY"'
    -c 'model_providers.codex-lb.supports_websockets=true'
    -c 'model_providers.codex-lb.requires_openai_auth=true'
  )

  if curl -fsS --max-time 1 "$ready_url" >/dev/null 2>&1; then
    export CX_APP_SERVER_URL="$listen"
    return 0
  fi

  if [[ -f "$pid_file" ]]; then
    local old_pid
    old_pid="$(cat "$pid_file" 2>/dev/null)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
      kill "$old_pid" 2>/dev/null
    fi
  fi

  CODEX_LB_UPSTREAM_STREAM_TRANSPORT=websocket \
    nohup codex app-server "${server_config[@]}" --listen "$listen" \
    < /dev/null >"$log_file" 2>&1 &!
  echo $! > "$pid_file"

  local i
  for i in {1..40}; do
    if curl -fsS --max-time 1 "$ready_url" >/dev/null 2>&1; then
      export CX_APP_SERVER_URL="$listen"
      return 0
    fi
    sleep 0.25
  done

  echo "cxlb: app-server did not become ready at $listen. See $log_file." >&2
  return 1
}
_cxlb_export_mobile_urls() {
  local port="$1" token_file="$2"
  local tailscale_ip
  tailscale_ip="$(tailscale ip -4 2>/dev/null | head -n 1)"
  export CX_SHARED_APP_SERVER_URL="ws://127.0.0.1:${port}"
  if [[ -n "$tailscale_ip" ]]; then
    export CX_MOBILE_APP_SERVER_URL="ws://${tailscale_ip}:${port}"
  else
    export CX_MOBILE_APP_SERVER_URL="$CX_SHARED_APP_SERVER_URL"
  fi
  export CX_MOBILE_APP_SERVER_TOKEN="$(cat "$token_file" 2>/dev/null)"
}
_cxlb_ensure_mobile_app_server() {
  local port="${CX_MOBILE_APP_SERVER_PORT:-8876}"
  local ready_url="http://127.0.0.1:${port}/readyz"
  local token_file="$HOME/.codex/cxlb-mobile-app-server.token"
  local plist="$HOME/Library/LaunchAgents/com.dawson.codex.cxlb-mobile-app-server.plist"
  local label="gui/$(id -u)/com.dawson.codex.cxlb-mobile-app-server"

  if curl -fsS --max-time 1 "$ready_url" >/dev/null 2>&1; then
    _cxlb_export_mobile_urls "$port" "$token_file"
    return 0
  fi

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "cxlb: mobile app-server is not running. LaunchAgents are macOS-only." >&2
    return 1
  fi

  launchctl bootstrap "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
  launchctl kickstart -k "$label" >/dev/null 2>&1 || true

  local i
  for i in {1..40}; do
    if curl -fsS --max-time 1 "$ready_url" >/dev/null 2>&1; then
      _cxlb_export_mobile_urls "$port" "$token_file"
      return 0
    fi
    sleep 0.25
  done

  echo "cxlb: mobile app-server did not become ready on port $port. See ~/.codex/cxlb-mobile-app-server.err.log." >&2
  return 1
}
cxlb() {
  local repo="$HOME/projects/codex-lb"
  local api_url="https://api.clb.dev.dawson.gg"
  _cxlb_load_codex_lb_key
  if [[ -z "${CODEX_LB_API_KEY:-}" ]]; then
    echo "cxlb: CODEX_LB_API_KEY is not set and no api_key was found in ~/.codex/config.toml." >&2
    return 1
  fi
  if ! dev status --cwd "$repo" 2>/dev/null | grep -q "session codex-lb running"; then
    CODEX_LB_UPSTREAM_STREAM_TRANSPORT=websocket dev up --cwd "$repo" >/dev/null || return 1
  fi
  _cxlb_write_profile
  export CODEX_LB_UPSTREAM_STREAM_TRANSPORT=websocket
  if ! curl -fsS --max-time 3 -H "Authorization: Bearer ${CODEX_LB_API_KEY}" "$api_url/backend-api/codex/models" >/dev/null 2>&1; then
    echo "cxlb: codex-lb is running but its Codex model endpoint did not answer at $api_url." >&2
    return 1
  fi
  _cxlb_ensure_mobile_app_server || return 1
  codex --remote "$CX_SHARED_APP_SERVER_URL" --remote-auth-token-env CX_MOBILE_APP_SERVER_TOKEN --cd "$PWD" --dangerously-bypass-approvals-and-sandbox "$@"
}
cx() { cxlb "$@"; }
cxm() {
  _cxlb_load_codex_lb_key
  if [[ -z "${CODEX_LB_API_KEY:-}" ]]; then
    echo "cxm: CODEX_LB_API_KEY is not set and no api_key was found in ~/.codex/config.toml." >&2
    return 1
  fi
  _cxlb_ensure_mobile_app_server || return 1
  echo "Codex mobile app-server: $CX_MOBILE_APP_SERVER_URL"
  echo "Codex local app-server: $CX_SHARED_APP_SERVER_URL"
  echo "Token: $CX_MOBILE_APP_SERVER_TOKEN"
}
_nx_load_nvidia_key() {
  [[ -n "${NVIDIA_API_KEY:-}" ]] && return 0
  [[ -f "$HOME/.codex/secrets.env" ]] && source "$HOME/.codex/secrets.env"
}
nkx() {
  _nx_load_nvidia_key
  codex --profile nvidia-kimi --remote ws://127.0.0.1:8765 --cd "$PWD" --dangerously-bypass-approvals-and-sandbox "$@"
}
# dss = desktop ssh (formerly dx; dx is the status CLI binary).
dss() { ssh dawson@desktop "$@"; }
nbrew() { command nb "$@"; }

if [[ "$(uname -s)" == "Darwin" ]]; then
  alias km='killall MenuBarAgent'
  alias c2='open -na "Cursor" --args --glass --user-data-dir="$HOME/Library/Application Support/Cursor Agents 2"'
fi

[[ -s "$HOME/.bun/_bun" ]] && source "$HOME/.bun/_bun"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if [[ -r "$HOME/.vite-plus/env" ]]; then
  . "$HOME/.vite-plus/env"
fi

if (( ! $+functions[compdef] )); then
  autoload -Uz compinit
  compinit
fi
[[ -r "$HOME/.config/d/completion.zsh" ]] && source "$HOME/.config/d/completion.zsh"

if [[ -x "$HOME/.ascii/bin/box" ]]; then
  box() {
    current_file=$(mktemp)
    old_current_file=${BOX_CURRENT_ID_FILE-}
    export BOX_CURRENT_ID_FILE="$current_file"
    command "$HOME/.ascii/bin/box" "$@"
    box_status=$?
    if [ "$box_status" -eq 0 ]; then
      case "${1:-}" in
        new|start|fork)
          if [ -s "$current_file" ]; then
            current_id=$(tr -d '[:space:]' < "$current_file")
            if [ -n "$current_id" ]; then export BOX_CURRENT_ID="$current_id"; fi
          fi
          ;;
      esac
    fi
    if [ -n "$old_current_file" ]; then export BOX_CURRENT_ID_FILE="$old_current_file"; else unset BOX_CURRENT_ID_FILE; fi
    rm -f "$current_file"
    return "$box_status"
  }
fi

if [[ -d "$HOME/.grok/completions/zsh" ]]; then
  fpath=("$HOME/.grok/completions/zsh" $fpath)
  autoload -Uz compinit && compinit -C
fi

# Terminal command, not a key. Pass bootstrap flags through, for example: dotup --skip-gui
dotup() {
  local bin link root
  bin="${HOME}/.local/bin/dotup"
  if [[ -x "$bin" ]]; then
    "$bin" "$@"
    return
  fi
  link="${HOME}/.zshrc"
  if [[ ! -L "$link" ]]; then
    printf 'dotup: ~/.zshrc is not a symlink into the dotfiles repo\n' >&2
    return 1
  fi
  link="$(readlink "$link")" || return 1
  root="$(cd "$(dirname "$link")/../.." && pwd)" || return 1
  git -C "$root" pull --ff-only origin main || return 1
  "$root/bootstrap.sh" "$@"
}

# CPA key and the optional Claude Code opt-in. No secrets in this file.
[ -f "$HOME/.codex/cpa.env" ] && . "$HOME/.codex/cpa.env"
