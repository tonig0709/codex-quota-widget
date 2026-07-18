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
running. The app also polls every 30 seconds and asks WidgetKit to reload only
this widget. WidgetKit still controls the final desktop refresh schedule; the
widget requests a five-minute fallback refresh.

## Requirements

- macOS 14 or newer
- Codex CLI, or ChatGPT for Mac with its bundled Codex binary
- A personal Codex-compatible ChatGPT account

## Install a release

1. Open [Releases](https://github.com/tonig0709/codex-quota-widget/releases)
   and download `Codex-Quota-<version>-macOS.dmg`.
2. Open the DMG and drag **Codex Quota.app** onto **Applications**.
3. On first launch, Control-click the app and choose **Open**. The public build
   is ad-hoc signed because this open-source repository does not contain an
   Apple Developer ID certificate.
4. Keep **Codex Quota** running in the menu bar, then Control-click the desktop,
   choose **Edit Widgets**, and add **Codex Quota**.

Use the segmented **深色 / 浅色** control in the app to change both the app
preview and the default widget appearance. In macOS, Control-click a widget,
choose **编辑小组件**, then turn **浅色外观** on for light or off for dark.
The widget gallery offers both a detailed large widget and a small circular
remaining-quota widget.

When upgrading from v0.3.0 or earlier, remove the old desktop widget once and
add it again. v0.3.1 uses a fresh WidgetKit identifier to discard the cached
configuration schema that caused blank widgets and hid the small size.

No Terminal is normally required. If macOS still reports that the app cannot be
opened after Control-clicking **Open**, remove only the downloaded app's
quarantine attribute, then open it again:

```bash
xattr -dr com.apple.quarantine "/Applications/Codex Quota.app"
```

## Build from source

Building from source requires Xcode 16 or newer.

1. Open `CodexQuotaWidget.xcodeproj` in Xcode.
2. Select your Apple development team for the app and widget targets.
3. Run the `CodexQuota` scheme.
4. In macOS, open the widget gallery and add **Codex Quota**.

The first launch reuses an existing Codex CLI login. If no account is connected,
Codex opens its own browser login flow.

## Test

```bash
swift run quota-self-check
```

## Data flow

```text
Codex account → local codex app-server → menu bar app → localhost snapshot → WidgetKit
```

## Independence and trademarks

This is an independent open-source project and is not affiliated with or
endorsed by OpenAI. Source code is MIT licensed. The unmodified Codex icon is an
OpenAI trademark asset and is excluded from the MIT license; see
[`TRADEMARKS.md`](TRADEMARKS.md).
