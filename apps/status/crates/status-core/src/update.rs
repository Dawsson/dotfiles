//! Dotfiles pull + `dx` self-install + bootstrap orchestration.

use std::env;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use thiserror::Error;

use crate::paths::DotfilesRoot;

/// Env var set after a successful self-rebuild so a re-exec skips cargo install.
pub const SKIP_SELF_UPDATE_ENV: &str = "DX_SKIP_SELF_UPDATE";

#[derive(Debug, Error)]
pub enum UpdateError {
    #[error("dotfiles checkout not found (set DOTFILES_DIR or use ~/.dotfiles)")]
    RootMissing,
    #[error("{0}")]
    Step(String),
    #[error(transparent)]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone)]
pub struct UpdateOptions {
    /// Arguments forwarded to `bootstrap.sh` (e.g. `--skip-gui`).
    pub bootstrap_args: Vec<String>,
    /// Skip `git pull` (useful in tests).
    pub skip_pull: bool,
    /// Skip rebuilding/installing the `dx` binary.
    pub skip_cli_install: bool,
    /// Skip running `bootstrap.sh`.
    pub skip_bootstrap: bool,
}

impl Default for UpdateOptions {
    fn default() -> Self {
        Self {
            bootstrap_args: Vec::new(),
            skip_pull: false,
            skip_cli_install: false,
            skip_bootstrap: false,
        }
    }
}

/// Resolve the checkout used for update/bootstrap.
pub fn require_root() -> Result<DotfilesRoot, UpdateError> {
    DotfilesRoot::discover().ok_or(UpdateError::RootMissing)
}

/// `git -C <root> pull --ff-only origin main`
pub fn pull_dotfiles(root: &Path) -> Result<(), UpdateError> {
    let status = Command::new("git")
        .arg("-C")
        .arg(root)
        .args(["pull", "--ff-only", "origin", "main"])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if !status.success() {
        return Err(UpdateError::Step(format!(
            "git pull --ff-only origin main failed (exit {})",
            status.code().unwrap_or(-1)
        )));
    }
    Ok(())
}

fn status_workspace(root: &Path) -> PathBuf {
    root.join("apps/status")
}

fn cargo_bin() -> Option<PathBuf> {
    which("cargo").or_else(|| {
        env::var_os("HOME").map(|h| PathBuf::from(h).join(".cargo/bin/cargo"))
            .filter(|p| p.is_file())
    })
}

fn which(name: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths).find_map(|dir| {
            let candidate = dir.join(name);
            candidate.is_file().then_some(candidate)
        })
    })
}

/// Install only the tiny `dx` CLI (`status-cli`) into `~/.cargo/bin`.
pub fn install_dx_cli(root: &Path) -> Result<PathBuf, UpdateError> {
    let workspace = status_workspace(root);
    let manifest = workspace.join("Cargo.toml");
    if !manifest.is_file() {
        return Err(UpdateError::Step(format!(
            "status workspace missing at {} (apps/status not checked out?)",
            workspace.display()
        )));
    }
    let cargo = cargo_bin().ok_or_else(|| {
        UpdateError::Step(
            "cargo not found on PATH (install Rust via mise/bootstrap, then re-run dx update)"
                .into(),
        )
    })?;

    eprintln!("==> installing dx CLI from {}", workspace.display());
    let status = Command::new(&cargo)
        .current_dir(&workspace)
        .args([
            "install",
            "--path",
            "crates/status-cli",
            "--locked",
            "--force",
        ])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if !status.success() {
        return Err(UpdateError::Step(format!(
            "cargo install --path crates/status-cli failed (exit {})",
            status.code().unwrap_or(-1)
        )));
    }

    let dx = env::var_os("HOME")
        .map(|h| PathBuf::from(h).join(".cargo/bin/dx"))
        .filter(|p| p.is_file())
        .or_else(|| which("dx"))
        .ok_or_else(|| UpdateError::Step("dx binary missing after cargo install".into()))?;
    Ok(dx)
}

/// Run `bootstrap.sh` with the given args (inherit stdio; replaces process on success via exec semantics approximated by wait).
pub fn run_bootstrap(root: &Path, args: &[String]) -> Result<(), UpdateError> {
    let script = root.join("bootstrap.sh");
    if !script.is_file() {
        return Err(UpdateError::Step(format!(
            "bootstrap.sh missing at {}",
            script.display()
        )));
    }
    eprintln!("==> running bootstrap.sh {}", args.join(" "));
    let status = Command::new(&script)
        .args(args)
        .current_dir(root)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()?;
    if !status.success() {
        return Err(UpdateError::Step(format!(
            "bootstrap.sh failed (exit {})",
            status.code().unwrap_or(-1)
        )));
    }
    Ok(())
}

/// Whether this process should skip cargo self-install (already done, or env set).
pub fn env_skips_self_update() -> bool {
    matches!(
        env::var(SKIP_SELF_UPDATE_ENV).as_deref(),
        Ok("1") | Ok("true") | Ok("yes")
    )
}

/// Full day-to-day update: pull → refresh `dx` → bootstrap.
///
/// After installing a newer `dx`, re-execs that binary with the same args and
/// `DX_SKIP_SELF_UPDATE=1` so subsequent logic uses the fresh binary.
pub fn run_update(opts: UpdateOptions) -> Result<(), UpdateError> {
    let root = require_root()?;
    eprintln!(
        "==> dx update using {} ({})",
        root.path.display(),
        root.source
    );

    if !opts.skip_pull {
        pull_dotfiles(&root.path)?;
    } else {
        eprintln!("==> skipping git pull");
    }

    if !opts.skip_cli_install && !env_skips_self_update() {
        let new_dx = install_dx_cli(&root.path)?;
        // Always re-exec after cargo install: --force overwrites the same path, so
        // the running process would otherwise keep the old mapped binary.
        eprintln!("==> re-exec {}", new_dx.display());
        let mut cmd = Command::new(&new_dx);
        cmd.arg("update");
        for a in &opts.bootstrap_args {
            cmd.arg(a);
        }
        cmd.env(SKIP_SELF_UPDATE_ENV, "1");
        let err = cmd
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .exec();
        return Err(UpdateError::Io(err));
    } else if opts.skip_cli_install {
        eprintln!("==> skipping dx CLI install");
    } else {
        eprintln!("==> dx CLI already refreshed this run");
    }

    if !opts.skip_bootstrap {
        run_bootstrap(&root.path, &opts.bootstrap_args)?;
    } else {
        eprintln!("==> skipping bootstrap.sh");
    }
    Ok(())
}

// Unix-only: CommandExt::exec
use std::os::unix::process::CommandExt;
