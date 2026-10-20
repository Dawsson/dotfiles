# Status app (`dx` / `dx-tray`)

Rust workspace for the machine/dotfiles CLI and Linux tray stub.

The native macOS menu bar app is [DX Status](macos/README.md), with CLI Proxy API accounts, quotas, resets, and spending. Install it with `./apps/status/macos/install.sh` from the repo root.
Lives **in this dotfiles repo** under `apps/status/`.

| Binary | Crate | Role |
| --- | --- | --- |
| `dx` | `status-cli` | **Primary updater:** `update` / `up`, plus `doctor`, `status`, `tailscale` |
| `dx-tray` | `status-ui` | Menubar/tray stub with a Status menu |

Shared providers live in `status-core`. Desktop SSH is the shell helper **`dss`** (not `dx`).

## Day-to-day vs first-time

| When | Command |
| --- | --- |
| First-time machine | `curl …/install.sh \| bash` (or clone + `./bootstrap.sh`) |
| Already bootstrapped | `dx update` / `dx up` / `dotup` |

`dx update` pulls `origin/main`, refreshes only the tiny `status-cli` binary into `~/.cargo/bin`, then runs `bootstrap.sh` with any flags you pass (`--skip-gui`, etc.). It does **not** go through `install.sh`.

Bootstrap installs `dx` via `cargo install --path crates/status-cli` after mise/runtimes.

## Requirements

- Rust **1.90+** (`rust-toolchain.toml` pins the channel)
- Optional: `tailscale` on `PATH` for live Tailscale status

## Build / install

```bash
cd apps/status
cargo build --release -p status-cli          # tiny CLI only
cargo install --path crates/status-cli --locked --force
# optional tray:
cargo install --path crates/status-ui --locked
```

## Smoke commands

```bash
dx --help
dx update --help
dx doctor
dx status
dx tailscale -v
dx-tray   # prints status; tray needs a session bus / panel
```

## Tray / GPUI gap

v1 ships a **tray-icon** stub (`ksni` on Linux). Intended follow-up: **GPUI** + gpui-tray (+ gpui-kit). Keep providers in `status-core`.

## Layout

```
apps/status/
  Cargo.toml
  rust-toolchain.toml
  crates/
    status-core/   # doctor, Tailscale, update orchestration
    status-cli/    # dx
    status-ui/     # dx-tray
```
