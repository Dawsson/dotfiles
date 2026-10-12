//! Menubar / tray stub for the status app.
//!
//! v1 uses `tray-icon` (StatusNotifierItem via ksni on Linux; AppKit on macOS)
//! so the binary compiles without pulling all of GPUI. The long-term plan is
//! GPUI + gpui-tray (+ gpui-kit); see `apps/status/README.md`.

use anyhow::{Context, Result};
use status_core::{query_tailscale, status_line};

fn main() {
    if let Err(err) = run() {
        eprintln!("dx-tray: {err:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let report = query_tailscale();
    let line = status_line(&report);
    println!("{line}");

    #[cfg(feature = "tray")]
    {
        match start_tray(&line) {
            Ok(()) => Ok(()),
            Err(err) => {
                // Headless CI / SSH: still succeed after printing status.
                eprintln!("dx-tray: tray unavailable ({err:#}); status printed above");
                Ok(())
            }
        }
    }

    #[cfg(not(feature = "tray"))]
    {
        eprintln!("dx-tray: built without `tray` feature");
        Ok(())
    }
}

#[cfg(feature = "tray")]
fn start_tray(tailscale_line: &str) -> Result<()> {
    use std::time::Duration;

    use tray_icon::menu::{Menu, MenuEvent, MenuItem, PredefinedMenuItem};
    use tray_icon::TrayIconBuilder;

    let icon = status_icon().context("build tray icon")?;

    let menu = Menu::new();
    let title = MenuItem::new("Status", false, None);
    let ts_item = MenuItem::new(tailscale_line, false, None);
    let quit = MenuItem::new("Quit", true, None);
    menu.append(&title)?;
    menu.append(&PredefinedMenuItem::separator())?;
    menu.append(&ts_item)?;
    menu.append(&PredefinedMenuItem::separator())?;
    menu.append(&quit)?;

    let quit_id = quit.id().clone();

    let _tray = TrayIconBuilder::new()
        .with_menu(Box::new(menu))
        .with_tooltip("dx status")
        .with_title("Status")
        .with_icon(icon)
        .build()
        .context("create tray icon")?;

    println!("dx-tray: tray running (Quit from the Status menu to exit)");

    // ksni runs its own worker thread on Linux. On macOS an AppKit/run-loop is
    // still required for menu delivery; for this v1 stub we poll MenuEvent and
    // document that a proper GPUI/AppKit loop is the follow-up.
    let menu_channel = MenuEvent::receiver();
    loop {
        if let Ok(event) = menu_channel.try_recv() {
            if event.id == quit_id {
                break;
            }
        }
        std::thread::sleep(Duration::from_millis(200));
    }
    Ok(())
}

#[cfg(feature = "tray")]
fn status_icon() -> Result<tray_icon::Icon> {
    const SIZE: u32 = 32;
    let mut rgba = vec![0_u8; (SIZE * SIZE * 4) as usize];
    for y in 0..SIZE {
        for x in 0..SIZE {
            let i = ((y * SIZE + x) * 4) as usize;
            let dx = x as i32 - 15;
            let dy = y as i32 - 15;
            let in_circle = dx * dx + dy * dy <= 14 * 14;
            if in_circle {
                // Soft teal disc so it reads on light and dark panels.
                rgba[i] = 32;
                rgba[i + 1] = 160;
                rgba[i + 2] = 160;
                rgba[i + 3] = 255;
            }
        }
    }
    tray_icon::Icon::from_rgba(rgba, SIZE, SIZE).context("rgba icon")
}
