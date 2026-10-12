use anyhow::Result;
use clap::{Parser, Subcommand};
use status_core::{query_tailscale, run_doctor, status_line};

#[derive(Debug, Parser)]
#[command(
    name = "dx",
    version,
    about = "Dawsson status CLI — machine/dotfiles checks and live status",
    long_about = "dx is the CLI half of the status app that lives in this dotfiles repo \
(apps/status). The tray binary is dx-tray."
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Basic machine and dotfiles health checks
    Doctor,
    /// Show Tailscale status (graceful if the CLI is missing)
    #[command(name = "tailscale", visible_alias = "ts")]
    Tailscale {
        /// Print raw CLI/JSON summary details when available
        #[arg(long, short = 'v')]
        verbose: bool,
    },
    /// One-line rollup of known providers (Tailscale today)
    Status,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Doctor => cmd_doctor(),
        Commands::Tailscale { verbose } => cmd_tailscale(verbose),
        Commands::Status => cmd_status(),
    }
}

fn cmd_doctor() -> Result<()> {
    let report = run_doctor();
    for check in &report.checks {
        let mark = if check.ok { "ok" } else { "!!" };
        println!("[{mark}] {:<10} {}", check.name, check.detail);
    }
    if report.all_ok() {
        println!("doctor: all checks passed");
        Ok(())
    } else {
        anyhow::bail!("doctor: one or more checks failed");
    }
}

fn cmd_tailscale(verbose: bool) -> Result<()> {
    let report = query_tailscale();
    println!("{}", status_line(&report));
    if verbose {
        if let Some(raw) = &report.raw_summary {
            println!("{raw}");
        }
    }
    Ok(())
}

fn cmd_status() -> Result<()> {
    let ts = query_tailscale();
    println!("{}", status_line(&ts));
    Ok(())
}
