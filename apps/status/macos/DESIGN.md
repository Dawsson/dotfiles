---
name: DX Status
description: Native macOS menu bar view of shared proxy spending and account quotas.
---

# Design System: DX Status

## Overview

Use native SwiftUI typography, controls, and system appearance. The compact menu bar window puts shared proxy spending above account quotas, with secondary details behind disclosure controls. Source of truth: `Sources/DXStatus/App.swift`.

## Colors

Use system semantic colors rather than fixed palette values. Primary text carries amounts and labels; secondary text carries identities, plans, resets, and explanatory copy. Spending bars use the system accent color at 80% opacity. Quota bars use orange for Claude, teal for Codex, and purple for other providers; remaining quota at or below 10% uses red. Green indicates active accounts and the header's no-error state; orange marks notices and the header's error state. Unavailable account status uses secondary text.

## Typography

Use the system font. The window title is 19pt semibold; account titles are 15pt semibold. Section headings use `.headline`, supporting text uses `.caption`, and reset labels use 11pt. The spending total uses 28pt rounded semibold type. Apply monospaced digits to totals, quota percentages, and numeric detail values.

## Layout

The window is 440pt wide. Header and scrolling content have 20pt padding; the scroll area is 590pt high. Major content groups have 20pt spacing, with 12pt spacing inside spending and account groups. The footer uses 20pt horizontal and 14pt vertical padding. Native dividers separate header, footer, and accounts.

Keep the order: header, shared spending overview, account count, provider segmented picker, account details. Align account identity left and status/plan right. Quota labels sit above progress bars, with percentages and reset times aligned right. The header and footer remain outside the scrolling content.

## Elevation & Depth

Rely on the native window surface and control treatments. Content has no custom card backgrounds or shadows; spacing and dividers establish grouping.

## Shapes

Use native segmented controls, progress bars, disclosure indicators, and window corners. The header status dot is 6pt in diameter. Spending chart bars have a 2pt corner radius.

## Components

- **Header:** title, status dot, source name, relative refresh time, and borderless refresh button. Show a small progress indicator and disable refresh while loading.
- **Spending:** 30-day total, token/request counts, a 46pt bar chart with hidden axes, today's figures, and a persistent shared-traffic explanation. Expand model details with a disclosure group.
- **Provider filter:** native segmented picker with All and available provider names. Filtering changes the account list, leaving shared spending visible.
- **Accounts:** provider and identity, status and plan, labeled quota bars, resets, and available billing details. Cursor usage and proxy notices use disclosure groups.
- **Footer:** dashboard link and borderless Quit button.

## Do's and Don'ts

- Do preserve plain unknown states such as “Plan not reported,” “Quota not reported by the proxy,” and “Unpriced.”
- Do retain text percentages and status labels alongside color, and accessibility labels for refresh, quota bars, and the spending chart.
- Do show the lower-bound prefix for incomplete spending estimates and explain stale or unavailable data in text.
- Don't attribute shared proxy spending to an account or describe it as subscription billing.
- Don't replace native appearance with invented web tokens or decorative cards.
