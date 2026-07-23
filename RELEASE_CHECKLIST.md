# Release checklist

Every tagged release runs `scripts/release-preflight.sh` before a DMG can be
created. The automated gate rejects a release if any of these checks fail:

- the widget extension is embedded, version-matched, and declares both small
  and large widget kinds, so macOS can list it in the widget gallery;
- the installed-app registration repair and App Translocation guard are present;
- each widget has a real container background and the known black-screen
  fallback contract is intact;
- quota and seven-day usage are committed as one snapshot, both widget sizes
  receive a targeted refresh, cached HTTP data is bypassed, and a one-minute
  timeline fallback remains enabled;
- the localhost snapshot endpoint returns usage data without email or plan data.

Before announcing a release, complete this short visual smoke test on a Mac:

- [ ] Drag the new app into **Applications**, eject the DMG, and launch that copy.
- [ ] Open **Edit Widgets**, search **Codex Quota**, and confirm both **小型** and
      **大型** can be added.
- [ ] Confirm neither size is black or blank in both light and dark appearance.
- [ ] Use **立即刷新**, then confirm quota and seven-day trend update within one
      minute after new Codex usage is available.

The automated gate runs on every tag; this final smoke test covers the desktop
compositor and widget gallery UI, which GitHub's headless macOS runner cannot
reliably open.
