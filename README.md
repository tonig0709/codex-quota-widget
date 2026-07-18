# Codex Quota Widget for macOS

A native macOS menu bar app and desktop widget for Codex weekly quota and
seven-day token usage. The widget uses the system material, keeps the five-hour
limit hidden, and colors remaining quota as follows:

- 60–100%: green
- 30–59%: orange
- 0–29%: red

## Privacy-first account connection

The app launches the locally installed `codex app-server`, then uses the public
`account/read`, `account/login/start`, `account/rateLimits/read`, and
`account/usage/read` protocol methods. Login and token refresh stay inside
Codex. This app does not receive or persist OAuth tokens.

Rate-limit notifications trigger an immediate refresh while the menu bar app is
running. WidgetKit still controls the final desktop refresh schedule; the widget
also requests a fallback refresh every 15 minutes.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer
- Codex CLI, or ChatGPT for Mac with its bundled Codex binary
- A personal Codex-compatible ChatGPT account

## Build

1. Open `CodexQuotaWidget.xcodeproj` in Xcode.
2. Select your Apple development team for the app and widget targets.
3. If needed, change `group.dev.codexquota.widget` in both entitlement files and
   in `Shared/UsageSnapshot.swift` to an App Group registered to your team.
4. Run the `CodexQuota` scheme.
5. In macOS, open the widget gallery and add **Codex Quota**.

The first launch reuses an existing Codex CLI login. If no account is connected,
Codex opens its own browser login flow.

## Test

```bash
swift run quota-self-check
```

## Data flow

```text
Codex account → local codex app-server → menu bar app → App Group snapshot → WidgetKit
```

## Independence and trademarks

This is an independent open-source project and is not affiliated with or
endorsed by OpenAI. Source code is MIT licensed. The unmodified Codex icon is an
OpenAI trademark asset and is excluded from the MIT license; see
[`TRADEMARKS.md`](TRADEMARKS.md).
