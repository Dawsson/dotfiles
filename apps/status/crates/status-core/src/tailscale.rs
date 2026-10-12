use std::process::Command;

use serde::Deserialize;

/// High-level Tailscale presence / connectivity.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TailscaleState {
    /// `tailscale` binary not on PATH.
    Missing,
    /// Binary present but the query failed.
    Error(String),
    /// Binary present; not connected / stopped.
    Stopped,
    /// Connected (or at least reporting a backend state).
    Running {
        backend_state: Option<String>,
        self_name: Option<String>,
        peer_count: usize,
    },
}

/// Result of probing Tailscale via its CLI.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TailscaleReport {
    pub state: TailscaleState,
    pub raw_summary: Option<String>,
}

/// Query Tailscale status using the `tailscale` CLI when available.
pub fn query_tailscale() -> TailscaleReport {
    if which("tailscale").is_none() {
        return TailscaleReport {
            state: TailscaleState::Missing,
            raw_summary: None,
        };
    }

    match Command::new("tailscale")
        .args(["status", "--json"])
        .output()
    {
        Ok(out) if out.status.success() => parse_status_json(&out.stdout),
        Ok(out) => {
            let stderr = String::from_utf8_lossy(&out.stderr).trim().to_string();
            let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
            let msg = if !stderr.is_empty() {
                stderr
            } else if !stdout.is_empty() {
                stdout
            } else {
                format!(
                    "tailscale status exited {}",
                    out.status
                        .code()
                        .map(|c| c.to_string())
                        .unwrap_or_else(|| "signal".into())
                )
            };

            // Common when the daemon isn't up — treat as stopped rather than hard error.
            let lowered = msg.to_ascii_lowercase();
            if lowered.contains("stopped")
                || lowered.contains("not running")
                || lowered.contains("failed to connect")
                || lowered.contains("no such file")
            {
                return TailscaleReport {
                    state: TailscaleState::Stopped,
                    raw_summary: Some(msg),
                };
            }

            // Fall back to plain text status.
            match Command::new("tailscale").arg("status").output() {
                Ok(plain) if plain.status.success() => {
                    let text = String::from_utf8_lossy(&plain.stdout).trim().to_string();
                    TailscaleReport {
                        state: TailscaleState::Running {
                            backend_state: Some("Running".into()),
                            self_name: text.lines().next().map(|l| l.to_string()),
                            peer_count: text.lines().count().saturating_sub(1),
                        },
                        raw_summary: Some(text),
                    }
                }
                _ => TailscaleReport {
                    state: TailscaleState::Error(msg),
                    raw_summary: None,
                },
            }
        }
        Err(err) => TailscaleReport {
            state: TailscaleState::Error(err.to_string()),
            raw_summary: None,
        },
    }
}

fn which(bin: &str) -> Option<std::path::PathBuf> {
    env_path().find_map(|dir| {
        let candidate = dir.join(bin);
        if candidate.is_file() {
            Some(candidate)
        } else {
            None
        }
    })
}

fn env_path() -> impl Iterator<Item = std::path::PathBuf> {
    std::env::var_os("PATH")
        .into_iter()
        .flat_map(|paths| std::env::split_paths(&paths).collect::<Vec<_>>())
}

#[derive(Debug, Deserialize)]
struct StatusJson {
    #[serde(rename = "BackendState")]
    backend_state: Option<String>,
    #[serde(rename = "Self")]
    self_node: Option<SelfNode>,
    #[serde(rename = "Peer")]
    peer: Option<serde_json::Map<String, serde_json::Value>>,
}

#[derive(Debug, Deserialize)]
struct SelfNode {
    #[serde(rename = "HostName")]
    host_name: Option<String>,
    #[serde(rename = "DNSName")]
    dns_name: Option<String>,
}

fn parse_status_json(bytes: &[u8]) -> TailscaleReport {
    match serde_json::from_slice::<StatusJson>(bytes) {
        Ok(status) => {
            let backend = status.backend_state.clone();
            let self_name = status.self_node.as_ref().and_then(|n| {
                n.host_name
                    .clone()
                    .or_else(|| n.dns_name.clone().map(|d| d.trim_end_matches('.').to_string()))
            });
            let peer_count = status.peer.as_ref().map(|p| p.len()).unwrap_or(0);
            let raw_summary = Some(format!(
                "BackendState={}; self={}; peers={}",
                backend.as_deref().unwrap_or("?"),
                self_name.as_deref().unwrap_or("?"),
                peer_count
            ));

            let state = match backend.as_deref() {
                Some("Running") | Some("Starting") => TailscaleState::Running {
                    backend_state: backend,
                    self_name,
                    peer_count,
                },
                Some("Stopped") | Some("NoState") | Some("NeedsLogin") => TailscaleState::Stopped,
                Some(_) => TailscaleState::Running {
                    backend_state: backend,
                    self_name,
                    peer_count,
                },
                None => TailscaleState::Running {
                    backend_state: None,
                    self_name,
                    peer_count,
                },
            };

            TailscaleReport { state, raw_summary }
        }
        Err(err) => TailscaleReport {
            state: TailscaleState::Error(format!("json parse: {err}")),
            raw_summary: None,
        },
    }
}
