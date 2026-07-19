# Codex Quota for macOS

A native macOS menu bar app and desktop widget for checking your Codex weekly
quota and seven-day Token usage at a glance.

**Latest release: [v0.3.2](https://github.com/tonig0709/codex-quota-widget/releases/tag/v0.3.2)** ·
[Download the macOS DMG](https://github.com/tonig0709/codex-quota-widget/releases/download/v0.3.2/Codex-Quota-v0.3.2-macOS.dmg)

## What it shows

- **Codex Quota · 小型** — a compact circular remaining-quota gauge with the
  Codex mark at its center.
- **Codex Quota · 大型** — weekly remaining quota plus a seven-day Token trend.
- **Per-widget light or dark appearance** — Control-click a widget, choose
  **编辑小组件**, then toggle **浅色外观**.
- **Clear quota states** — green at 60% or above, orange from 30% to 59%, and
  red below 30%.

The app deliberately omits the five-hour limit. It reads the locally available
weekly quota and Token-usage data while Codex remains in charge of login.

## Install in two minutes

1. Download [Codex-Quota-v0.3.2-macOS.dmg](https://github.com/tonig0709/codex-quota-widget/releases/download/v0.3.2/Codex-Quota-v0.3.2-macOS.dmg).
2. Open the DMG and drag **Codex Quota.app** to **Applications**.
3. Eject the DMG, then open **Codex Quota** from **Applications** or Launchpad.
   Do not run the app directly from the DMG: macOS may isolate that copy and
   hide its widget extension from the gallery.
4. On first launch, Control-click the app and choose **Open**. The public build
   is ad-hoc signed because this open-source project has no Apple Developer ID
   certificate.
5. Keep Codex Quota running in the menu bar. Control-click the desktop, choose
   **Edit Widgets**, search for **Codex Quota**, then add either **小型** or
   **大型**.

No Terminal is needed for normal use. If macOS still blocks the app after the
Control-click **Open** step, remove quarantine from the installed copy only:

```bash
xattr -dr com.apple.quarantine "/Applications/Codex Quota.app"
```

### Updating from an older version

Install the new app in **Applications**, quit the previous copy, then remove
and re-add any existing Codex Quota desktop widgets once. v0.3.2 publishes the
small and large layouts as separate gallery entries so both remain visible.

## Live-data behavior

Codex Quota starts the locally installed `codex app-server`, polls the account
every 30 seconds, and asks WidgetKit to refresh only when the underlying quota
or usage changes. WidgetKit ultimately controls desktop refresh timing, so the
trend is near-real-time rather than a guaranteed per-second display.

## Privacy and security

- Your Codex login and token refresh remain inside Codex; this app never reads
  or stores OAuth tokens.
- The widget receives a quota-only snapshot over `127.0.0.1`; email and plan
  details are removed before it is sent.
- No account data is sent to a third-party service.

Read [SECURITY.md](SECURITY.md) for the full threat model and release-signing
notes.

## Requirements

- macOS 14 or later
- Codex CLI, or ChatGPT for Mac with its bundled Codex binary
- A Codex-compatible personal ChatGPT account

## Build from source

Building from source requires Xcode 16 or later.

1. Open `CodexQuotaWidget.xcodeproj` in Xcode.
2. Select your Apple development team for the app and widget targets.
3. Run the `CodexQuota` scheme.
4. Open the widget gallery and add either the small or large widget.

```bash
swift run quota-self-check
```

## Data flow

```text
Codex account → local codex app-server → menu bar app → localhost snapshot → WidgetKit
```

## Independence and trademarks

This is an independent open-source project and is not affiliated with or
endorsed by OpenAI. Source code is MIT licensed. The unmodified Codex icon is
an OpenAI trademark asset and is excluded from the MIT license; see
[`TRADEMARKS.md`](TRADEMARKS.md).
