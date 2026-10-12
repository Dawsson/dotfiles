#!/usr/bin/env bash
# Fedora desktop apps and mac-like GNOME settings.
# Re-run from a graphical session if gsettings had no session bus:
#   ./scripts/gnome.sh

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

enable_copr() {
  local repo="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable COPR ${repo}"
    return 0
  fi
  sudo dnf install -y dnf5-plugins >/dev/null 2>&1 \
    || sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 \
    || true
  if sudo dnf copr enable -y "$repo"; then
    return 0
  fi
  sudo dnf copr enable --assumeyes "$repo"
}

gset() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "gsettings set $*"
    return 0
  fi
  if ! have gsettings; then
    warn "gsettings is not available"
    return 0
  fi
  gsettings set "$@" || warn "gsettings set $* failed"
}

enable_gnome_extension() {
  local uuid="$1"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable GNOME extension ${uuid}"
    return 0
  fi
  if ! have gnome-extensions; then
    warn "gnome-extensions is not available; enable ${uuid} after logging into GNOME"
    return 0
  fi
  gnome-extensions enable "$uuid" \
    || warn "could not enable ${uuid}; log into GNOME and re-run ./scripts/gnome.sh"
}

install_flatpaks() {
  local app
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable Flathub and install Legcord, Slack, Spotify, and Obsidian"
    return 0
  fi
  sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || warn "could not add Flathub"
  for app in app.legcord.Legcord com.slack.Slack com.spotify.Client md.obsidian.Obsidian; do
    sudo flatpak install -y flathub "$app" || warn "could not flatpak install ${app}"
  done
}

install_chrome() {
  if [[ "$(uname -m)" != "x86_64" ]]; then
    warn "Google's Chrome rpm repo is x86_64-only; skipping Chrome"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install google-chrome-stable"
    return 0
  fi
  write_root_file /etc/yum.repos.d/google-chrome.repo <<'EOF'
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
  sudo dnf install -y google-chrome-stable || warn "Google Chrome was not installed"
}

install_cursor_rpm() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Cursor from downloads.cursor.com"
    return 0
  fi
  write_root_file /etc/yum.repos.d/cursor.repo <<'EOF'
[cursor]
name=Cursor
baseurl=https://downloads.cursor.com/yumrepo
enabled=1
gpgcheck=1
gpgkey=https://downloads.cursor.com/keys/anysphere.asc
EOF
  sudo dnf install -y cursor || warn "Cursor was not installed"
}

install_helium() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable the imput/helium COPR and install helium-bin"
    return 0
  fi
  enable_copr imput/helium || warn "could not enable the Helium COPR"
  sudo dnf install -y helium-bin || warn "Helium was not installed"
}

install_grok_bot() {
  local arch feed rpm
  case "$(uname -m)" in
    x86_64) arch="linux-x64" ;;
    aarch64) arch="linux-arm64" ;;
    *)
      warn "no Grok Bot arch mapping for $(uname -m)"
      return 0
      ;;
  esac
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Grok Bot from the official ${arch} rpm feed"
    return 0
  fi
  if rpm -q grok-bot >/dev/null 2>&1; then
    log "Grok Bot already installed"
    return 0
  fi
  feed="$(curl -fsSL "https://api2.cursor.sh/updates/api/download/stable/${arch}/sand" || true)"
  rpm="$(printf '%s' "$feed" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("rpmUrl",""))' 2>/dev/null || true)"
  if [[ -z "$rpm" ]]; then
    warn "Grok Bot rpm URL was not in the release feed. Download it from https://x.ai/bot"
    return 0
  fi
  sudo dnf install -y "$rpm" || warn "Grok Bot was not installed"
}

install_t3_nightly() {
  local arch meta kind url dir dest
  arch="$(uname -m)"
  dir="${HOME}/.local/opt/t3-code"
  dest="${dir}/T3-Code-Nightly.AppImage"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install the T3 Code nightly desktop app for ${arch}"
    return 0
  fi
  meta="$(py t3-nightly "$arch" || true)"
  kind="$(printf '%s\n' "$meta" | sed -n '1p')"
  url="$(printf '%s\n' "$meta" | sed -n '2p')"
  if [[ -z "$url" ]]; then
    warn "T3 Code nightly has no desktop build for ${arch}. See https://t3.codes/download/"
    return 0
  fi
  if [[ "$kind" == "rpm" ]]; then
    sudo dnf install -y "$url" || warn "T3 Code rpm was not installed"
    return 0
  fi
  mkdir -p "$dir" "${HOME}/.local/share/applications"
  if [[ -f "${dir}/source-url" && "$(cat "${dir}/source-url")" == "$url" && -x "$dest" ]]; then
    log "T3 Code nightly already matches the current AppImage"
  else
    download "$url" "$dest" || warn "could not download T3 Code"
    chmod +x "$dest" || true
    printf '%s\n' "$url" > "${dir}/source-url"
  fi
  cat > "${HOME}/.local/share/applications/t3-code-nightly.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=T3 Code Nightly
Comment=T3 Code nightly
Exec=${dest} %U
Terminal=false
Categories=Development;
StartupWMClass=t3 code
EOF
  update-desktop-database "${HOME}/.local/share/applications" >/dev/null 2>&1 || true
  log "T3 Code nightly installed as an AppImage. Current nightlies publish AppImage and deb, not rpm."
}

install_1password_app() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would dnf install the 1Password app"
    return 0
  fi
  sudo dnf install -y 1password || warn "1Password app was not installed"
}

install_ghostty_package() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable the scottames/ghostty COPR and install ghostty"
    return 0
  fi
  if rpm -q ghostty >/dev/null 2>&1; then
    log "ghostty already installed"
    return 0
  fi
  # Ghostty's install docs point at this COPR. It is not in the Fedora repos.
  enable_copr scottames/ghostty || warn "could not enable the Ghostty COPR"
  sudo dnf install -y ghostty || warn "ghostty was not installed"
}

set_helium_default() {
  local desktop="" candidate found
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would set Helium as the default browser via xdg-settings and xdg-mime"
    return 0
  fi
  for candidate in helium.desktop net.imput.helium.desktop helium-bin.desktop helium-browser.desktop; do
    if [[ -f "/usr/share/applications/${candidate}" || -f "${HOME}/.local/share/applications/${candidate}" ]]; then
      desktop="$candidate"
      break
    fi
  done
  if [[ -z "$desktop" ]]; then
    found="$(find /usr/share/applications "${HOME}/.local/share/applications" -name '*[Hh]elium*.desktop' -print -quit 2>/dev/null || true)"
    desktop="$(basename "$found")"
  fi
  if [[ -z "$desktop" ]]; then
    warn "Helium's desktop file was not found. Set the default browser after it is installed."
    return 0
  fi
  xdg-settings set default-web-browser "$desktop" || warn "xdg-settings could not set the default browser"
  xdg-mime default "$desktop" x-scheme-handler/http || true
  xdg-mime default "$desktop" x-scheme-handler/https || true
  xdg-mime default "$desktop" text/html || true
  py set-default-browser "${HOME}/.config/mimeapps.list" "$desktop" >/dev/null
  log "Helium (${desktop}) set as the default browser. Chrome stays installed."
}

enable_tailscale_systray() {
  local desktop
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable the Tailscale systray desktop app"
    return 0
  fi
  if ! have tailscale; then
    warn "tailscale is not installed; skipping the systray"
    return 0
  fi
  dnf_install wl-clipboard || true
  sudo systemctl enable --now tailscaled || warn "could not enable tailscaled"
  if [[ "$(id -u)" -ne 0 ]]; then
    sudo tailscale set --operator="$(current_user)" \
      || warn "could not set the Tailscale operator"
  fi
  desktop="${HOME}/.config/autostart/tailscale-systray.desktop"
  mkdir -p "${HOME}/.config/autostart"
  if ! tailscale configure systray --enable-startup=freedesktop; then
    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Tailscale
Comment=Tailscale system tray
Exec=tailscale systray
TryExec=tailscale
Icon=tailscale
Terminal=false
Categories=Network;
X-GNOME-Autostart-enabled=true
EOF
    warn "wrote ${desktop} because tailscale configure systray did not install autostart"
  fi
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] && have pgrep; then
    if ! pgrep -f '[t]ailscale systray' >/dev/null 2>&1; then
      nohup tailscale systray >/dev/null 2>&1 &
    fi
  fi
  log "Tailscale systray starts at login. The icon uses the AppIndicator extension."
}

fedora_gui() {
  section "Fedora apps"
  dnf_install flatpak fuse fuse-libs
  install_flatpaks
  install_chrome
  install_cursor_rpm
  install_helium
  install_grok_bot
  install_t3_nightly
  install_1password_app
  install_1password_helium
  install_ghostty_package
  set_helium_default
  enable_tailscale_systray
}

install_vicinae() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Vicinae (COPR quadratech188/vicinae, else https://vicinae.com/install) and bind Super+Space to vicinae toggle"
    return 0
  fi
  if have vicinae || rpm -q vicinae >/dev/null 2>&1; then
    return 0
  fi
  enable_copr quadratech188/vicinae || warn "could not enable the Vicinae COPR"
  if sudo dnf install -y vicinae; then
    return 0
  fi
  warn "Vicinae COPR package was not installed; trying the official install script"
  curl -fsSL https://vicinae.com/install | bash || warn "Vicinae was not installed"
}

enable_vicinae_server() {
  local unit_found=0
  if have systemctl; then
    if systemctl --user cat vicinae.service >/dev/null 2>&1 \
      || systemctl --user cat vicinae >/dev/null 2>&1; then
      unit_found=1
    fi
  fi
  if [[ "$unit_found" -eq 1 ]]; then
    systemctl --user enable --now vicinae.service 2>/dev/null \
      || systemctl --user enable --now vicinae \
      || warn "could not enable the vicinae user service"
    return 0
  fi
  mkdir -p "${HOME}/.config/autostart"
  cat > "${HOME}/.config/autostart/vicinae.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Vicinae
Comment=Application launcher
Exec=vicinae server
Icon=vicinae
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
}

configure_vicinae() {
  local launcher current merged vicinae_path ulauncher_path
  # GNOME launches this with a small PATH. An absolute helper path is reliable.
  launcher="${HOME}/.local/bin/dawsson-vicinae"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would bind Super+Space to ${launcher} (vicinae toggle), enable the vicinae user service, and clear GNOME's input-source binding"
    return 0
  fi
  mkdir -p "${HOME}/.local/bin"
  ln -sfn "${DOTFILES_ROOT}/scripts/vicinae-show.sh" "$launcher"
  rm -f "${HOME}/.local/bin/dawsson-ulauncher" \
    "${HOME}/.config/autostart/ulauncher.desktop"
  enable_vicinae_server
  vicinae_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/"
  ulauncher_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ulauncher/"
  gset org.gnome.desktop.wm.keybindings switch-input-source "[]"
  gset org.gnome.desktop.wm.keybindings switch-input-source-backward "[]"
  current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    current="@as []"
  fi
  merged="$(py gnome-keybindings "$current" "$vicinae_path" --drop "$ulauncher_path")"
  gset org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$merged"
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/ \
    name 'Vicinae'
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/ \
    command "$launcher"
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/ \
    binding '<Super>space'
}

configure_1password_quick_access() {
  local current merged path
  path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password-quick-access/"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would bind Shift+Super+Space to 1password --quick-access"
    return 0
  fi
  current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    current="@as []"
  fi
  merged="$(py gnome-keybindings "$current" "$path")"
  gset org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$merged"
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password-quick-access/ \
    name '1Password Quick Access'
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password-quick-access/ \
    command '1password --quick-access'
  gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/1password-quick-access/ \
    binding '<Shift><Super>space'
}

install_keyd() {
  local mapper unit
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable the alternateved/keyd COPR and apply the Super-as-Command map"
    return 0
  fi
  # keyd is not in Fedora. Upstream documents the alternateved COPR.
  enable_copr alternateved/keyd || warn "could not enable the keyd COPR"
  sudo dnf install -y keyd python3-gobject || warn "keyd was not installed"
  if [[ ! -d /etc/keyd ]]; then
    sudo mkdir -p /etc/keyd
  fi
  if [[ -f /etc/keyd/default.conf ]] && ! grep -q 'dawsson-dotfiles' /etc/keyd/default.conf; then
    sudo cp /etc/keyd/default.conf "/etc/keyd/default.conf.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
  fi
  sudo cp "${DOTFILES_ROOT}/dotfiles/keyd/default.conf" /etc/keyd/default.conf
  if systemctl is-active --quiet keyd 2>/dev/null; then
    sudo systemctl restart keyd || warn "keyd did not restart; run: sudo systemctl restart keyd"
  else
    enable_system_service keyd
  fi
  if getent group keyd >/dev/null 2>&1; then
    ensure_group_member "$(current_user)" keyd
  fi
  mapper=""
  for mapper in /usr/bin/keyd-application-mapper /usr/libexec/keyd-application-mapper /usr/share/keyd/keyd-application-mapper; do
    [[ -x "$mapper" || -f "$mapper" ]] && break
    mapper=""
  done
  if [[ -z "$mapper" ]]; then
    warn "keyd-application-mapper was not found. The global Super map is still installed."
    return 0
  fi
  unit="${HOME}/.config/systemd/user/keyd-application-mapper.service"
  mkdir -p "$(dirname "$unit")"
  cat > "$unit" <<EOF
[Unit]
Description=keyd per-application bindings
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=${mapper} -d
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
  if systemd_active && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    systemctl --user daemon-reload || true
    if systemctl --user is-active --quiet keyd-application-mapper.service; then
      systemctl --user restart keyd-application-mapper.service \
        || warn "could not restart keyd-application-mapper"
    else
      systemctl --user enable --now keyd-application-mapper.service \
        || warn "could not start keyd-application-mapper; enable it after graphical login"
    fi
  else
    warn "after graphical login, run: systemctl --user enable --now keyd-application-mapper"
  fi
}

install_whitesur() {
  local src gtk icons cursors
  src="${HOME}/.local/share/dawsson-dotfiles/src"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install WhiteSur GTK, icon, and cursor themes"
    return 0
  fi
  sudo dnf install -y sassc gtk-murrine-engine git || sudo dnf install -y sassc git || true
  mkdir -p "$src"
  clone_or_update https://github.com/vinceliuice/WhiteSur-gtk-theme.git "${src}/WhiteSur-gtk-theme" || true
  clone_or_update https://github.com/vinceliuice/WhiteSur-icon-theme.git "${src}/WhiteSur-icon-theme" || true
  clone_or_update https://github.com/vinceliuice/WhiteSur-cursors.git "${src}/WhiteSur-cursors" || true
  if [[ -x "${src}/WhiteSur-gtk-theme/install.sh" ]]; then
    (cd "${src}/WhiteSur-gtk-theme" && ./install.sh -c Dark -l) || warn "WhiteSur GTK theme install failed"
  fi
  if [[ -x "${src}/WhiteSur-icon-theme/install.sh" ]]; then
    (cd "${src}/WhiteSur-icon-theme" && ./install.sh) || warn "WhiteSur icon install failed"
  fi
  if [[ -x "${src}/WhiteSur-cursors/install.sh" ]]; then
    (cd "${src}/WhiteSur-cursors" && ./install.sh) || warn "WhiteSur cursor install failed"
  fi
  gtk="$(find "${HOME}/.themes" "${HOME}/.local/share/themes" -maxdepth 1 -type d -name 'WhiteSur-Dark*' -print -quit 2>/dev/null || true)"
  icons="$(find "${HOME}/.local/share/icons" "${HOME}/.icons" -maxdepth 1 -type d -name 'WhiteSur-dark*' -print -quit 2>/dev/null || true)"
  cursors="$(find "${HOME}/.local/share/icons" "${HOME}/.icons" -maxdepth 1 -type d -name 'WhiteSur-cursors*' -print -quit 2>/dev/null || true)"
  gset org.gnome.desktop.interface gtk-theme "$(basename "${gtk:-WhiteSur-Dark}")"
  gset org.gnome.desktop.interface icon-theme "$(basename "${icons:-WhiteSur-dark}")"
  gset org.gnome.desktop.interface cursor-theme "$(basename "${cursors:-WhiteSur-cursors}")"
  gset org.gnome.desktop.interface color-scheme 'prefer-dark'
}

install_inter_font() {
  local url tmp
  if have fc-list && fc-list : family | grep -qx "Inter"; then
    log "Inter already installed"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install the Inter font"
    return 0
  fi
  sudo dnf install -y rsms-inter-fonts && return 0
  sudo dnf install -y inter-fonts && return 0
  url="$(py github-asset rsms/inter '^Inter-[0-9].*\.zip$' || true)"
  if [[ -z "$url" ]]; then
    warn "could not install Inter"
    return 0
  fi
  tmp="$(mktemp -d)"
  mkdir -p "${HOME}/.local/share/fonts/Inter"
  if download "$url" "$tmp/inter.zip"; then
    unzip -qo "$tmp/inter.zip" -d "${HOME}/.local/share/fonts/Inter" || warn "could not unzip Inter"
    fc-cache -f "${HOME}/.local/share/fonts" || true
  fi
  rm -rf "$tmp"
}

install_gnome_extensions() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Dash to Dock, AppIndicator, user themes, and Blur My Shell"
    return 0
  fi
  sudo dnf install -y \
    gnome-shell-extension-dash-to-dock \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-user-theme \
    gnome-shell-extension-blur-my-shell \
    gnome-tweaks \
    pipx \
    || warn "some GNOME extension packages were not installed"
  enable_gnome_extension dash-to-dock@micxgx.gmail.com
  enable_gnome_extension appindicatorsupport@rgcjonas.gmail.com
  enable_gnome_extension user-theme@gnome-shell-extensions.gcampax.github.com
  enable_gnome_extension blur-my-shell@aunetx
  if rpm -q gnome-shell-extension-blur-my-shell >/dev/null 2>&1; then
    return 0
  fi
  if have pipx; then
    pipx ensurepath >/dev/null 2>&1 || true
    if ! pipx list --short 2>/dev/null | grep -q '^gnome-extensions-cli'; then
      pipx install gnome-extensions-cli || warn "gnome-extensions-cli was not installed"
    fi
  fi
  export PATH="${HOME}/.local/bin:${PATH}"
  if have gext; then
    gext install blur-my-shell@aunetx || warn "Blur My Shell was not installed"
  fi
}

apply_gnome_settings() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would set a bottom dock, left window buttons, natural scrolling, and tap-to-click"
    return 0
  fi
  gset org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
  gset org.gnome.desktop.interface font-name 'Inter 11'
  gset org.gnome.desktop.interface document-font-name 'Inter 11'
  gset org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
  gset org.gnome.desktop.peripherals.touchpad tap-to-click true
  gset org.gnome.desktop.peripherals.touchpad natural-scroll true
  gset org.gnome.desktop.peripherals.mouse natural-scroll true
  gset org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
  gset org.gnome.shell.extensions.dash-to-dock dock-fixed true
  gset org.gnome.shell.extensions.dash-to-dock autohide false
  gset org.gnome.shell.extensions.dash-to-dock extend-height false
  gset org.gnome.shell.extensions.user-theme name 'WhiteSur-Dark'
}

fedora_desktop() {
  section "GNOME"
  install_vicinae
  configure_vicinae
  configure_1password_quick_access
  install_keyd
  install_inter_font
  install_whitesur
  install_gnome_extensions
  apply_gnome_settings
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  fedora_desktop
fi
