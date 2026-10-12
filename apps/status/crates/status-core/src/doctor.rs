use std::env;
use std::process::Command;

use crate::paths::DotfilesRoot;
use crate::tailscale::{TailscaleState, query_tailscale};

/// Outcome of a single doctor check.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DoctorCheck {
    pub name: String,
    pub ok: bool,
    pub detail: String,
}

/// Aggregate doctor report.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DoctorReport {
    pub checks: Vec<DoctorCheck>,
}

impl DoctorReport {
    pub fn all_ok(&self) -> bool {
        self.checks.iter().all(|c| c.ok)
    }
}

/// Run basic machine / dotfiles health checks.
pub fn run_doctor() -> DoctorReport {
    let mut checks = Vec::new();

    checks.push(os_check());
    checks.push(command_check("rustc", &["--version"]));
    checks.push(command_check("cargo", &["--version"]));
    checks.push(dotfiles_check());
    checks.push(tailscale_check());

    DoctorReport { checks }
}

fn os_check() -> DoctorCheck {
    let os = env::consts::OS;
    let arch = env::consts::ARCH;
    let ok = matches!(os, "macos" | "linux");
    DoctorCheck {
        name: "os".into(),
        ok,
        detail: format!("{os}/{arch}"),
    }
}

fn command_check(bin: &str, args: &[&str]) -> DoctorCheck {
    match Command::new(bin).args(args).output() {
        Ok(out) if out.status.success() => {
            let detail = String::from_utf8_lossy(&out.stdout)
                .lines()
                .next()
                .unwrap_or(bin)
                .trim()
                .to_string();
            DoctorCheck {
                name: bin.into(),
                ok: true,
                detail,
            }
        }
        Ok(out) => DoctorCheck {
            name: bin.into(),
            ok: false,
            detail: format!(
                "exited {}",
                out.status
                    .code()
                    .map(|c| c.to_string())
                    .unwrap_or_else(|| "signal".into())
            ),
        },
        Err(err) => DoctorCheck {
            name: bin.into(),
            ok: false,
            detail: format!("missing ({err})"),
        },
    }
}

fn dotfiles_check() -> DoctorCheck {
    match DotfilesRoot::discover() {
        Some(root) => DoctorCheck {
            name: "dotfiles".into(),
            ok: true,
            detail: format!("{} ({})", root.path.display(), root.source),
        },
        None => DoctorCheck {
            name: "dotfiles".into(),
            ok: false,
            detail: "no checkout found (set DOTFILES_DIR or use ~/.dotfiles)".into(),
        },
    }
}

fn tailscale_check() -> DoctorCheck {
    let report = query_tailscale();
    match report.state {
        // Optional provider: missing CLI is a note, not a hard doctor failure.
        TailscaleState::Missing => DoctorCheck {
            name: "tailscale".into(),
            ok: true,
            detail: "not installed (optional; status will report gracefully)".into(),
        },
        TailscaleState::Error(msg) => DoctorCheck {
            name: "tailscale".into(),
            ok: false,
            detail: msg,
        },
        TailscaleState::Stopped => DoctorCheck {
            name: "tailscale".into(),
            ok: true,
            detail: "installed; daemon not running (or logged out)".into(),
        },
        TailscaleState::Running {
            backend_state,
            self_name,
            peer_count,
        } => {
            let name = self_name.unwrap_or_else(|| "node".into());
            let state = backend_state.unwrap_or_else(|| "unknown".into());
            DoctorCheck {
                name: "tailscale".into(),
                ok: true,
                detail: format!("{name}; BackendState={state}; peers={peer_count}"),
            }
        }
    }
}
