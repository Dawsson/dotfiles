#!/usr/bin/env bash
# Fedora packages, Docker, libvirt, Cua CLI, and desktop apps.

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
# shellcheck source=gnome.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gnome.sh"

fedora_cli_packages() {
  cat <<'EOF'
zsh
git
git-lfs
curl
ca-certificates
gnupg2
wget
tar
unzip
xz
jq
python3
ripgrep
tmux
tree
btop
fastfetch
gh
lazygit
zellij
xh
yt-dlp
restic
sops
poppler-utils
starship
zoxide
xdg-utils
fontconfig
util-linux
EOF
}

fedora_require() {
  local id="" version=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    version="${VERSION_ID:-}"
  fi
  if [[ "$id" == "fedora" && "$version" != "44" ]]; then
    warn "this bootstrap targets Fedora Workstation 44 (found ${version}). Continuing."
  fi
  if [[ "$(uname -m)" != "x86_64" ]]; then
    warn "this bootstrap targets x86_64 (found $(uname -m)). Continuing."
  fi
  if [[ "$id" != "fedora" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log "dry-run off Fedora; printing the Fedora steps"
      return 0
    fi
    die "Fedora setup requires Fedora"
  fi
  require_sudo
  have dnf || die "dnf is required"
}

install_listed_packages() {
  local pkg
  local pkgs=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    pkgs[${#pkgs[@]}]="$pkg"
  done
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  dnf_install "${pkgs[@]}"
}

install_github_cli() {
  local cmd="$1" repo="$2" regex="$3"
  local url tmp bin
  if have "$cmd"; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install ${cmd} from GitHub ${repo} when the distro package is missing"
    return 0
  fi
  url="$(py github-asset "$repo" "$regex" || true)"
  if [[ -z "$url" ]]; then
    warn "could not find a ${cmd} release asset"
    return 0
  fi
  tmp="$(mktemp -d)"
  if ! download "$url" "$tmp/asset"; then
    warn "could not download ${cmd}"
    rm -rf "$tmp"
    return 0
  fi
  case "$url" in
    *.tar.xz) tar -xJf "$tmp/asset" -C "$tmp" ;;
    *.tar.gz | *.tgz) tar -xzf "$tmp/asset" -C "$tmp" ;;
    *.tbz | *.tar.bz2) tar -xjf "$tmp/asset" -C "$tmp" ;;
    *.bz2)
      bunzip2 -c "$tmp/asset" > "$tmp/$cmd"
      ;;
    *.zip) unzip -q "$tmp/asset" -d "$tmp" ;;
    *) cp "$tmp/asset" "$tmp/$cmd" ;;
  esac
  bin="$(find "$tmp" -type f -name "$cmd" -print -quit || true)"
  if [[ -z "$bin" ]]; then
    warn "release archive for ${cmd} did not contain a ${cmd} binary"
  else
    install_user_bin "$bin" "$cmd"
  fi
  rm -rf "$tmp"
}

install_github_fallbacks() {
  case "$(uname -m)" in
    x86_64)
      install_github_cli lazygit jesseduffield/lazygit 'linux_x86_64\.tar\.gz$'
      install_github_cli zellij zellij-org/zellij 'x86_64-unknown-linux-musl\.tar\.gz$'
      install_github_cli starship starship/starship 'x86_64-unknown-linux-musl\.tar\.gz$'
      install_github_cli zoxide ajeetdsouza/zoxide 'x86_64-unknown-linux-musl\.tar\.gz$'
      install_github_cli xh ducaale/xh 'x86_64-unknown-linux-musl\.tar\.gz$'
      install_github_cli fastfetch fastfetch-cli/fastfetch '^fastfetch-linux-amd64\.tar\.gz$'
      install_github_cli gh cli/cli 'linux_amd64\.tar\.gz$'
      install_github_cli sops getsops/sops 'linux\.amd64$'
      install_github_cli btop aristocratos/btop 'btop-x86_64-unknown-linux-musl\.tar\.gz$'
      install_github_cli restic restic/restic 'linux_amd64\.bz2$'
      ;;
    aarch64)
      install_github_cli lazygit jesseduffield/lazygit 'linux_arm64\.tar\.gz$'
      install_github_cli zellij zellij-org/zellij 'aarch64-unknown-linux-musl\.tar\.gz$'
      install_github_cli starship starship/starship 'aarch64-unknown-linux-musl\.tar\.gz$'
      install_github_cli zoxide ajeetdsouza/zoxide 'aarch64-unknown-linux-musl\.tar\.gz$'
      install_github_cli gh cli/cli 'linux_arm64\.tar\.gz$'
      ;;
    *)
      warn "no GitHub fallback mapping for $(uname -m)"
      ;;
  esac
}

enable_rpmfusion() {
  local ver
  ver="$(rpm -E %fedora 2>/dev/null || true)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would enable RPM Fusion free and nonfree (Fedora ${ver:-unknown})"
    return 0
  fi
  if [[ -z "$ver" ]]; then
    warn "could not read the Fedora release number for RPM Fusion"
    return 0
  fi
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
      || warn "RPM Fusion free was not enabled"
  fi
  if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm" \
      || warn "RPM Fusion nonfree was not enabled"
  fi
}

install_ffmpeg_and_codecs() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install ffmpeg and RPM Fusion codecs"
    return 0
  fi
  sudo dnf install -y --allowerasing ffmpeg || warn "ffmpeg was not installed"
  local pkg
  for pkg in gstreamer1-plugins-ugly gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld gstreamer1-plugin-libav; do
    sudo dnf install -y "$pkg" || warn "codec package ${pkg} was not installed"
  done
}

install_pscale() {
  local regex url
  if have pscale; then
    log "pscale already installed"
    return 0
  fi
  case "$(uname -m)" in
    x86_64) regex='linux_amd64\.rpm$' ;;
    aarch64) regex='linux_arm64\.rpm$' ;;
    *)
      warn "no pscale package for $(uname -m)"
      return 0
      ;;
  esac
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install pscale from planetscale/cli"
    return 0
  fi
  url="$(py github-asset planetscale/cli "$regex" || true)"
  if [[ -z "$url" ]]; then
    warn "could not resolve the pscale rpm"
    return 0
  fi
  sudo dnf install -y "$url" || warn "pscale was not installed"
}

install_cloudflared() {
  local asset url
  if have cloudflared; then
    log "cloudflared already installed"
    return 0
  fi
  case "$(uname -m)" in
    x86_64) asset="cloudflared-linux-x86_64.rpm" ;;
    aarch64) asset="cloudflared-linux-arm64.rpm" ;;
    *)
      warn "no cloudflared package for $(uname -m)"
      return 0
      ;;
  esac
  url="https://github.com/cloudflare/cloudflared/releases/latest/download/${asset}"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install cloudflared from ${url}"
    return 0
  fi
  sudo dnf install -y "$url" || warn "cloudflared was not installed"
}

install_doppler() {
  if have doppler; then
    log "doppler already installed"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Doppler from packages.doppler.com"
    return 0
  fi
  curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
    'https://packages.doppler.com/public/cli/script.rpm.sh' | sudo bash \
    || warn "Doppler repo script failed"
  sudo dnf install -y doppler || warn "doppler was not installed"
}

install_tailscale() {
  if have tailscale; then
    log "Tailscale already installed"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Tailscale from https://tailscale.com/install.sh"
    return 0
  fi
  curl -fsSL https://tailscale.com/install.sh | sh || warn "Tailscale was not installed"
}

install_1password_repo() {
  if [[ -f /etc/yum.repos.d/1password.repo ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would add the 1Password yum repo"
    return 0
  fi
  sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc \
    || warn "could not import the 1Password signing key"
  write_root_file /etc/yum.repos.d/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF
}

install_1password_cli() {
  section "1Password CLI"
  install_1password_repo
  if have op; then
    log "1Password CLI already installed"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would dnf install 1password-cli"
    return 0
  fi
  sudo dnf install -y 1password-cli || warn "1Password CLI was not installed"
}

install_docker() {
  section "Docker Engine"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install Docker Engine and add the user to the docker group"
    return 0
  fi
  if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
    if ! sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo; then
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo \
        || warn "could not add the Docker repo"
    fi
  fi
  sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    || warn "Docker Engine packages were not installed"
  enable_system_service docker
  ensure_group_member "$(current_user)" docker
}

install_virt() {
  section "KVM / libvirt"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install qemu-kvm, libvirt, and virt-install"
    return 0
  fi
  dnf_install qemu-kvm libvirt virt-install virt-viewer
  if [[ "$SKIP_GUI" != "1" ]]; then
    sudo dnf install -y virt-manager || warn "virt-manager was not installed"
  fi
  enable_system_service libvirtd
  ensure_group_member "$(current_user)" libvirt
  if getent group kvm >/dev/null 2>&1; then
    ensure_group_member "$(current_user)" kvm
  fi
}

install_cua() {
  section "Cua CLI"
  if have cua; then
    log "cua already installed ($(cua --version 2>/dev/null || true))"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install the Cua CLI only (Spaces app is mac-only and is not installed)"
    return 0
  fi
  curl -fsSL https://cua.ai/install.sh | sh -s -- --cli-only --yes --no-onboarding \
    || warn "Cua CLI was not installed"
}

install_nerd_font() {
  local url tmp
  if have fc-list && fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    log "JetBrainsMono Nerd Font already installed"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log "would install JetBrainsMono Nerd Font"
    return 0
  fi
  url="$(py github-asset ryanoasis/nerd-fonts '^JetBrainsMono\.(tar\.xz|zip)$' || true)"
  if [[ -z "$url" ]]; then
    warn "could not resolve JetBrainsMono Nerd Font"
    return 0
  fi
  tmp="$(mktemp -d)"
  mkdir -p "${HOME}/.local/share/fonts/JetBrainsMonoNerd"
  if download "$url" "$tmp/font"; then
    case "$url" in
      *.tar.xz) tar -xJf "$tmp/font" -C "${HOME}/.local/share/fonts/JetBrainsMonoNerd" ;;
      *.zip) unzip -qo "$tmp/font" -d "${HOME}/.local/share/fonts/JetBrainsMonoNerd" ;;
    esac
    fc-cache -f "${HOME}/.local/share/fonts" || true
  else
    warn "could not download JetBrainsMono Nerd Font"
  fi
  rm -rf "$tmp"
}

fedora_packages() {
  fedora_require
  section "Fedora packages"
  install_listed_packages < <(fedora_cli_packages)
  install_github_fallbacks
  enable_rpmfusion
  install_ffmpeg_and_codecs
  install_pscale
  install_cloudflared
  install_doppler
  install_tailscale
  install_1password_cli
  install_nerd_font
  install_docker
  install_virt
  install_cua
  if [[ "$SKIP_GUI" == "1" ]]; then
    log "skipping Fedora GUI apps and GNOME settings"
    return 0
  fi
  fedora_gui
  fedora_desktop
}
