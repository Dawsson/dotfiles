//! Shared status providers for the `dx` CLI and `dx-tray` menubar.

mod doctor;
mod paths;
mod tailscale;

pub use doctor::{DoctorCheck, DoctorReport, run_doctor};
pub use paths::DotfilesRoot;
pub use tailscale::{TailscaleReport, TailscaleState, query_tailscale};

/// One-line summary suitable for a menu item or CLI status line.
pub fn status_line(report: &TailscaleReport) -> String {
    match &report.state {
        TailscaleState::Missing => "Tailscale: not installed".to_string(),
        TailscaleState::Error(msg) => format!("Tailscale: error ({msg})"),
        TailscaleState::Stopped => "Tailscale: stopped".to_string(),
        TailscaleState::Running { backend_state, self_name, .. } => {
            let name = self_name.as_deref().unwrap_or("connected");
            match backend_state.as_deref() {
                Some("Running") | None => format!("Tailscale: {name}"),
                Some(state) => format!("Tailscale: {name} ({state})"),
            }
        }
    }
}
