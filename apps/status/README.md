# Status app (`dx` / `dx-tray`)

Rust workspace for a shared machine/dotfiles status CLI and a menubar/tray stub.
Lives **in this dotfiles repo** (monorepo) under `apps/status/` so shell configs stay untouched.

| Binary | Crate | Role |
| --- | --- | --- |
| `dx` | `status-cli` | clap CLI: `doctor`, `tailscale` / `status` |
| `dx-tray` | `status-ui` | Menubar/tray stub with a Status menu |

Shared providers live in `status-core`. The shell helper for SSH to the desktop is **`dss`** (not `dx`); this PR renames the old `dx()` zsh function so the cargo-installed `dx` binary is reachable.

## Requirements

- Rust **1.90+** (a `rust-toolchain.toml` pins the channel for this workspace)
- Optional: `tailscale` on `PATH` for live Tailscale status

## Build / install

From the repo root:

```bash
cd apps/status
cargo build --release
```

Binaries land in `apps/status/target/release/{dx,dx-tray}`.

Install into `~/.cargo/bin`:

```bash
cd apps/status
cargo install --path crates/status-cli --locked
cargo install --path crates/status-ui --locked
```

Or without `--locked` if you prefer resolving fresh:

```bash
cargo install --path crates/status-cli
cargo install --path crates/status-ui
```

Bootstrap does **not** install these yet (low-risk: keep package install separate until the CLI is in daily use). Put the release binaries on your `PATH` manually, or use `cargo install` as above.

## Smoke commands

```bash
cd apps/status
cargo run -p status-cli -- --help
cargo run -p status-cli -- doctor
cargo run -p status-cli -- status
cargo run -p status-cli -- tailscale -v

# Tray: prints Tailscale line, then tries to show a Status menu.
# On headless SSH/CI (no session bus / panel), it prints status and exits 0.
cargo run -p status-ui
```

## Tray / GPUI gap

v1 ships a **tray-icon** stub (`ksni` StatusNotifierItem on Linux) so `dx-tray` compiles without pulling Zed’s full GPUI stack.

**Intended next step:** switch `status-ui` to **GPUI** + [gpui-tray](https://crates.io/crates/gpui-tray) and [gpui-kit](https://gpui-kit.com) once tray/menubar behavior is validated on macOS and Fedora GNOME. crates.io `gpui` 0.2.x needs a recent Rust (edition 2024) and a large native dependency set; keep the provider logic in `status-core` so the UI crate can swap.

## Layout

```
apps/status/
  Cargo.toml              # workspace
  rust-toolchain.toml
  crates/
    status-core/          # doctor + Tailscale providers
    status-cli/           # dx
    status-ui/            # dx-tray
```
