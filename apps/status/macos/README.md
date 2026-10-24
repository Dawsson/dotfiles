# DX Status for macOS

Native SwiftUI menu bar app, backed by CLI Proxy API through Devbox. Uses the existing `~/.config/devbox/api-key`; provider credentials and the CPA management key remain server-side. No separate provider login.

```sh
./apps/status/macos/install.sh
```

Installs and opens `~/Applications/DX Status.app`. Requires macOS 14+ and Swift 6. It does not replace CodexBar or change login items.

The overview shows lifetime proxy API-rate estimates from Devbox's persistent history, today's proxy usage, and a token breakdown popover with cache reads/writes and reasoning. The chart shows the latest 30 recorded days. Cursor's separate 30-day account usage remains in the account row and is excluded from the lifetime total. Quota meters show the same expected-remaining tick and average-since-reset forecast as the dashboard: red when projected to run out, white when lasting until reset. Accounts show all proxy-reported quota windows, resets, status, plan and billing metadata, plus Cursor usage when supplied. Provider filters preserve disabled accounts.

The proxy currently omits Claude/Codex plan metadata from its dashboard response. These display “Plan not reported”; no plan is guessed from filenames. Spending is shared proxy traffic, not per-account subscription spend. Unpriced models remain unpriced and incomplete totals use ≥. Previously fetched data stays visible on network failure with an error notice.

Refresh reads the existing server cache every minute while the panel is open, respecting server-side provider refresh/backoff. It never triggers provider login, reset-credit consumption or account changes.

```sh
./apps/status/macos/test.sh
```

The Rust `dx` CLI and Linux tray stub remain in the parent workspace. This app uses SwiftUI's native menu-bar lifecycle on macOS.
