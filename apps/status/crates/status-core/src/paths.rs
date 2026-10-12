use std::env;
use std::path::{Path, PathBuf};

/// Resolved location of this machine's dotfiles checkout.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DotfilesRoot {
    pub path: PathBuf,
    pub source: &'static str,
}

impl DotfilesRoot {
    /// Look for a checkout via `DOTFILES_DIR`, `~/.dotfiles`, then walk up from cwd.
    pub fn discover() -> Option<Self> {
        if let Ok(dir) = env::var("DOTFILES_DIR") {
            let path = PathBuf::from(dir);
            if looks_like_dotfiles(&path) {
                return Some(Self {
                    path,
                    source: "DOTFILES_DIR",
                });
            }
        }

        if let Some(home) = env::var_os("HOME") {
            let path = PathBuf::from(home).join(".dotfiles");
            if looks_like_dotfiles(&path) {
                return Some(Self {
                    path,
                    source: "~/.dotfiles",
                });
            }
        }

        let mut dir = env::current_dir().ok()?;
        loop {
            if looks_like_dotfiles(&dir) {
                return Some(Self {
                    path: dir,
                    source: "cwd walk",
                });
            }
            if !dir.pop() {
                break;
            }
        }

        None
    }
}

fn looks_like_dotfiles(path: &Path) -> bool {
    path.join("bootstrap.sh").is_file() && path.join("install.sh").is_file()
}
