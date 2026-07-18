# Contributing

1. Install Xcode 16 or newer and a current Codex CLI.
2. Open `CodexQuotaWidget.xcodeproj`.
3. Select your development team for both targets and replace the example bundle
   IDs/app group if Xcode asks.
4. Run `swift run quota-self-check` before opening a pull request.

Keep dependencies at zero unless the standard Apple frameworks cannot solve the
problem. Do not add code that reads or exports Codex OAuth tokens.
