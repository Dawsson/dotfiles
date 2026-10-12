#!/usr/bin/env bash
# Register the 1Password browser extension with Helium and let the desktop
# app trust that browser. Helium is not an officially supported 1Password
# browser; this is the connection method 1Password documents for other
# Chromium browsers.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

if [[ -n "${DOTFILES_BROWSER_1PASSWORD_LOADED:-}" ]]; then
  return 0
fi
DOTFILES_BROWSER_1PASSWORD_LOADED=1

ONEPASSWORD_EXTENSION_ID="aeblfdkhhhdcdjpifhhbdiojplfjncoa"

write_extension_manifest() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF
}

write_native_manifest() {
  local dest="$1" helper="$2"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<EOF
{
  "name": "com.1password.1password",
  "description": "1Password BrowserSupport",
  "path": "${helper}",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://${ONEPASSWORD_EXTENSION_ID}/"
  ]
}
EOF
}

allow_1password_browser() {
  local name="$1" file="/etc/1password/custom_allowed_browsers"
  if [[ -f "$file" ]] && grep -qx "$name" "$file"; then
    return 0
  fi
  sudo mkdir -p /etc/1password
  sudo chmod 755 /etc/1password
  echo "$name" | sudo tee -a "$file" >/dev/null
  sudo chown root:root "$file"
  sudo chmod 644 "$file"
}

copy_native_manifest() {
  local dest_dir="$1"
  shift
  local candidate dest="${dest_dir}/com.1password.1password.json"
  mkdir -p "$dest_dir"
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      cp "$candidate" "$dest"
      log "1Password native messaging host copied for Helium"
      return 0
    fi
  done
  return 1
}

install_1password_helium_macos() {
  local ext_dir nm_dir helper
  ext_dir="${HOME}/Library/Application Support/net.imput.helium/External Extensions"
  nm_dir="${HOME}/Library/Application Support/net.imput.helium/NativeMessagingHosts"
  write_extension_manifest "${ext_dir}/${ONEPASSWORD_EXTENSION_ID}.json"
  if ! copy_native_manifest "$nm_dir" \
    "${HOME}/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.1password.1password.json" \
    "/Library/Google/Chrome/NativeMessagingHosts/com.1password.1password.json"; then
    helper="/Applications/1Password.app/Contents/Library/LoginItems/1Password Browser Helper.app/Contents/MacOS/1Password-BrowserSupport"
    if [[ -x "$helper" ]]; then
      write_native_manifest "${nm_dir}/com.1password.1password.json" "$helper"
    else
      warn "1Password's browser helper was not found. Open 1Password once, then re-run ./bootstrap.sh so Helium can connect."
    fi
  fi
  log "1Password extension registered for Helium. Quit and reopen Helium and 1Password once."
}

install_1password_helium_linux() {
  local ext_dir ext_file nm_dir helper tmp
  ext_dir="/usr/share/chromium/extensions"
  ext_file="${ext_dir}/${ONEPASSWORD_EXTENSION_ID}.json"
  # Helium keeps Chromium's extension directory. This is not a managed policy,
  # so it does not mark the browser as enterprise-managed. Google Chrome uses
  # a different directory and is left alone.
  if [[ ! -f "$ext_file" ]]; then
    tmp="$(mktemp)"
    write_extension_manifest "$tmp"
    sudo mkdir -p "$ext_dir"
    sudo cp "$tmp" "$ext_file"
    sudo chmod 644 "$ext_file"
    rm -f "$tmp"
  fi
  allow_1password_browser helium
  allow_1password_browser helium-wrapper
  nm_dir="${HOME}/.config/net.imput.helium/NativeMessagingHosts"
  if ! copy_native_manifest "$nm_dir" \
    /etc/opt/chrome/native-messaging-hosts/com.1password.1password.json \
    /etc/chromium/native-messaging-hosts/com.1password.1password.json; then
    helper="/opt/1Password/1Password-BrowserSupport"
    if [[ -x "$helper" ]]; then
      write_native_manifest "${nm_dir}/com.1password.1password.json" "$helper"
    else
      warn "1Password's browser helper was not found. Open 1Password once, then re-run ./bootstrap.sh so Helium can connect."
    fi
  fi
  log "1Password extension registered for Helium. Quit and reopen Helium and 1Password once."
}

install_1password_helium() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install the 1Password extension in Helium and trust that browser"
    return 0
  fi
  case "${OS:-}" in
    macos) install_1password_helium_macos ;;
    fedora) install_1password_helium_linux ;;
    *) warn "not registering the 1Password Helium extension on ${OS:-unknown}" ;;
  esac
}
