# Codex Quota release invariant

Before creating a version tag, DMG, or GitHub Release:

1. Build the app and WidgetKit extension with full Xcode for both `arm64` and
   `x86_64`. Never ship an extension assembled with `swiftc` or copied from an
   older build.
2. Sign the app and embedded extension, package the exact signed app, then run:

   ```sh
   ./scripts/release-preflight.sh "/path/to/Codex Quota.app" "/path/to/Codex-Quota.dmg"
   ```

3. Do not publish when the gate fails. It is the single source of truth for
   widget discovery, non-black rendering, live synchronization, version/build
   monotonicity, signatures, architectures, and DMG payload integrity.
4. Complete the desktop smoke test in `RELEASE_CHECKLIST.md`; a headless runner
   cannot directly operate the macOS widget gallery or desktop compositor.

Keep stable Liquid Glass releases separate from the particle experiment. When
a production bug is fixed, add the smallest regression to the release gate so
the same failure cannot pass a later release.
