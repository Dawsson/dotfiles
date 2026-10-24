---
name: DX Status
description: Native macOS menu bar view of total AI usage and account quotas.
---

# Design System: DX Status

## Overview

Native SwiftUI, system appearance. One compact window, no scrolling: total usage on top, then accounts grouped by provider as a dense table of quota meters. Source of truth: `Sources/DXStatus/App.swift`.

## Menu bar label

A rendered template image: each provider's logo followed by its percentage, like OpenUsage, and nothing else. Each value is the provider's combined weekly quota: weekly remaining over weekly cap, pooled across every account, disabled ones included. The 5-hour window is ignored. Before data arrives it falls back to the `gauge.with.dots.needle.33percent` symbol. The Store polls every 60 seconds whether or not the window is open. When the proxy's `observedAt` is over ten minutes old, the label draws at 40% opacity and the header adds an orange "Quotas from Xm ago" line.

## Colors

System semantic colors. Section headers use the real provider logos (`Logo.swift`, LobeHub icons): Claude in its brand orange, OpenAI and Grok in the text color. Meter fills use orange for Claude, teal for Codex, purple for others. A meter at or below 10% turns red, percentage included. Green dot for active accounts; disabled accounts render at 50% opacity with a secondary dot. Notices are orange. The usage chart uses primary at 35% opacity.

## Typography

System font with monospaced digits for every number. The total is 26pt rounded semibold. Provider titles and account emails are 12pt; meter percentages are 11pt semibold; column labels, resets, and plan/status are 10pt.

## Layout

420pt wide, 16pt padding. The header has the total, today plus lifetime tokens, a token breakdown popover, and a 150×34 chart of the most recent 30 recorded days with a refresh button. Each provider section has a header row carrying its column labels (`5h`, `Week`, `30 days`, `Resets`; Claude's Fable and Cloud windows are hidden), so meters show only the percentage, a 4pt capsule, and the reset time. Columns are the union of window ids within a provider, so meters line up across accounts. Identity column is 118pt. Active accounts sort above disabled ones.

## Content rules

- The header shows lifetime proxy spending only, from Devbox’s permanent daily history. Cursor’s separate 30-day account usage stays in its account row and is never added to lifetime totals. Incomplete estimates use ≥. Token breakdown opens a compact popover with exact input, cache read/write, output, reasoning and request counts and the recorded start date.
- Hide noise: no "Plan not reported", no prepaid or on-demand rows, no model breakdown. Show a plan only when one is reported.
- Emails are shortened (`tim…@gmail.com`); the full address is in the tooltip.
- Keep accessibility labels on refresh, meters, the chart, and the menu bar label.
- A meter keeps its reset time and adds “Lasts until reset” or orange “Runs out in X” below it. The pace tick marks expected remaining quota when consumption is spread evenly through the window: white if it lasts, red if it runs out first. Forecasts match Devbox’s average-since-reset calculation and short-window suppression. Unknown or expired reset windows have no forecast.
- Codex accounts get a `Resets` column: banked resets from `/cpa/reset-credits` (fetched every 10 minutes) and the next expiry, orange under 3 days. Read-only; spending a reset stays in the dashboard.
- The app registers itself as a login item on first launch; the footer checkbox turns it off.
