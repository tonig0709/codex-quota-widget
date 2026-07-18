# Security

The app launches the locally installed `codex app-server` and uses its official
JSONL protocol. OAuth credentials are stored and refreshed by Codex itself.
This project never reads `~/.codex/auth.json`, never stores access tokens, and
never sends credentials to a third-party server.

Only the quota snapshot (percentage, reset time, daily token totals, account
label, and update time) is saved to the app group used by the widget.

Please report vulnerabilities privately to the repository maintainer rather
than opening a public issue.
