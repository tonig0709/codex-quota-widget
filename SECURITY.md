# Security

The app launches the locally installed `codex app-server` and uses its official
JSONL protocol. OAuth credentials are stored and refreshed by Codex itself.
This project never reads `~/.codex/auth.json`, never stores access tokens, and
never sends credentials to a third-party server.

The widget reads a quota-only JSON snapshot from `127.0.0.1:48193`. The listener
binds only to loopback, accepts only `GET /snapshot`, sends `Cache-Control:
no-store`, and removes the account email and plan before encoding the response.
No OAuth credential or account identifier crosses this local bridge.

Release builds are ad-hoc signed and are not Apple-notarized. Verify the
download against the `.sha256` file attached to each GitHub Release. A local
process could still impersonate the fixed loopback port; the impact is limited
to displaying false quota data, not account access or token exposure.

Please report vulnerabilities privately to the repository maintainer rather
than opening a public issue.
