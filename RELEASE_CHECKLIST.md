# Release checklist

Every push and pull request, every version tag, and the final signed release
payload run the same gate:

```sh
./scripts/release-preflight.sh "/path/to/Codex Quota.app" "/path/to/Codex-Quota.dmg"
```

The gate blocks release unless all of these pass:

- **Widget gallery:** the signed universal extension is embedded, version
  matched, AppIntent metadata is valid, both sizes exist, and Apple's
  `pluginkit` registry reports exactly one enabled extension at the tested
  installed-app path.
- **No black or blank widget:** SwiftUI renders small/large × light/dark into
  four bitmaps and verifies visible pixels plus foreground contrast.
- **Live synchronization:** a deterministic fake Codex app-server proves the
  full initialize/account/rate-limit/usage path, forced port-collision recovery,
  15-second A→B refresh, advancing `updatedAt`, cache prevention, and removal of
  account identity from the widget snapshot.
- **Update safety:** the bundle build is greater than every existing release
  tag; temporary DMG/build copies cannot run registration repair or occupy
  port 48193.
- **Release artifact:** app/widget signatures and `arm64` + `x86_64` slices are
  valid, and the DMG contains the same signed version and build.

## Final desktop smoke test

The automated checks use Apple's registration database and off-screen
rendering, but a headless GitHub runner cannot click the widget gallery or
inspect the live desktop compositor. Before announcing a release:

- [ ] Remove prior test builds, drag the new app into **Applications**, eject
      the DMG, and launch only that copy.
- [ ] Open **Edit Widgets**, search **Codex Quota**, and add both **小型** and
      **大型**.
- [ ] Confirm neither size is black or blank in light and dark appearance.
- [ ] Confirm the small widget shows separate 5h and weekly rings and the large
      widget shows 5h above weekly quota.
- [ ] Generate new Codex usage and confirm quota plus seven-day trend update
      within one minute.
