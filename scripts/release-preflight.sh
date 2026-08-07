#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$root"

app_input="${1:-}"
if [ -z "$app_input" ] || [ ! -d "$app_input" ]; then
    echo "Usage: $0 <Codex Quota.app> [Codex-Quota.dmg]" >&2
    exit 64
fi
dmg_input="${2:-}"
[ -z "$dmg_input" ] || [ -f "$dmg_input" ] || { echo "DMG not found: $dmg_input" >&2; exit 66; }

app="$(cd "$(dirname "$app_input")" && pwd -P)/$(basename "$app_input")"
widget="$app/Contents/PlugIns/CodexQuotaWidgetExtension.appex"
app_executable="$app/Contents/MacOS/Codex Quota"
widget_executable="$widget/Contents/MacOS/CodexQuotaWidgetExtension"
app_info="$app/Contents/Info.plist"
widget_info="$widget/Contents/Info.plist"
app_metadata="$app/Contents/Resources/Metadata.appintents/extract.actionsdata"
widget_metadata="$widget/Contents/Resources/Metadata.appintents/extract.actionsdata"
widget_identifier="dev.codexquota.app.widget"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/codex-quota-release.XXXXXX")"
app_pid=""
blocker_pid=""
translocated_pid=""
translocation_mount=""
payload_mount=""
runtime_app=""
runtime_widget=""
registered_here=0

cleanup() {
    if [ -n "$blocker_pid" ]; then kill "$blocker_pid" 2>/dev/null || true; fi
    if [ -n "$app_pid" ]; then
        pkill -TERM -P "$app_pid" 2>/dev/null || true
        kill "$app_pid" 2>/dev/null || true
        wait "$app_pid" 2>/dev/null || true
    fi
    if [ -n "$translocated_pid" ]; then kill "$translocated_pid" 2>/dev/null || true; fi
    if [ "$registered_here" -eq 1 ] && [ -n "$runtime_widget" ]; then
        /usr/bin/pluginkit -r "$runtime_widget" >/dev/null 2>&1 || true
    fi
    if [ -n "$translocation_mount" ]; then hdiutil detach "$translocation_mount" -force >/dev/null 2>&1 || true; fi
    if [ -n "$payload_mount" ]; then hdiutil detach "$payload_mount" -force >/dev/null 2>&1 || true; fi
    if [ -n "$runtime_app" ] && [ -e "$runtime_app" ]; then rm -rf "$runtime_app"; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

section() { printf '\n==> %s\n' "$1"; }
pass() { printf '    PASS  %s\n' "$1"; }
fail() {
    printf '    FAIL  %s\n' "$1" >&2
    if [ -s "$tmp/app.log" ]; then tail -80 "$tmp/app.log" >&2; fi
    exit 1
}
require_text() {
    grep -Fq "$1" "$2" || fail "$3"
}
plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1"
}

section "Source, parser, and visual render checks"
swift run quota-self-check
require_text 'SmallCodexQuotaWidget()' Widget/CodexQuotaWidget.swift "small widget is missing from WidgetBundle"
require_text 'LargeCodexQuotaWidget()' Widget/CodexQuotaWidget.swift "large widget is missing from WidgetBundle"
require_text '.supportedFamilies([.systemSmall])' Widget/CodexQuotaWidget.swift "small widget family is missing"
require_text '.supportedFamilies([.systemExtraLarge])' Widget/CodexQuotaWidget.swift "large widget family is missing"
require_text '.containerBackground(for: .widget)' Widget/CodexQuotaWidget.swift "widget container background is missing"
require_text 'reloadIgnoringLocalCacheData' Widget/CodexQuotaWidget.swift "widget HTTP cache bypass is missing"
require_text 'addingTimeInterval(60)' Widget/CodexQuotaWidget.swift "one-minute WidgetKit fallback is missing"
require_text 'withTimeInterval: 15' App/CodexAppServer.swift "15-second app refresh timer is missing"
require_text 'private func retry()' App/CodexAppServer.swift "snapshot listener recovery is missing"
require_text 'reloadTimelines(ofKind: SnapshotStore.smallWidgetKind)' App/CodexAppServer.swift "small widget reload is missing"
require_text 'reloadTimelines(ofKind: SnapshotStore.largeWidgetKind)' App/CodexAppServer.swift "large widget reload is missing"
require_text 'WidgetRepairService.repair()' App/CodexQuotaApp.swift "launch-time widget repair is missing"
require_text 'isCurrentWidgetRegistered' App/WidgetRepairService.swift "installed widget registration check is missing"
require_text '["-e", "use", "-i", extensionIdentifier]' App/WidgetRepairService.swift "widget enable repair is missing"
pass "quota parsing, color thresholds, four widget renders, and refresh contracts"

section "Built app and WidgetKit extension"
[ -x "$app_executable" ] || fail "app executable is missing"
[ -x "$widget_executable" ] || fail "widget executable is missing"
[ -f "$app_metadata" ] || fail "app intent metadata is missing"
[ -f "$widget_metadata" ] || fail "widget intent metadata is missing"
[ -f "$app/Contents/Resources/Assets.car" ] || fail "compiled widget assets are missing"

app_identifier="$(plist_value "$app_info" CFBundleIdentifier)"
extension_point="$(plist_value "$widget_info" NSExtension:NSExtensionPointIdentifier)"
app_version="$(plist_value "$app_info" CFBundleShortVersionString)"
widget_version="$(plist_value "$widget_info" CFBundleShortVersionString)"
app_build="$(plist_value "$app_info" CFBundleVersion)"
widget_build="$(plist_value "$widget_info" CFBundleVersion)"
[ "$app_identifier" = "dev.codexquota.app" ] || fail "unexpected app bundle identifier: $app_identifier"
[ "$(plist_value "$widget_info" CFBundleIdentifier)" = "$widget_identifier" ] || fail "unexpected widget bundle identifier"
[ "$extension_point" = "com.apple.widgetkit-extension" ] || fail "invalid WidgetKit extension point"
[ "$app_version" = "$widget_version" ] || fail "app and widget marketing versions differ"
[ "$app_build" = "$widget_build" ] || fail "app and widget build numbers differ"

if [ "${GITHUB_REF_TYPE:-}" = "tag" ]; then
    tag_version="${GITHUB_REF_NAME#v}"
    [ "$app_version" = "$tag_version" ] || fail "tag $GITHUB_REF_NAME does not match bundle version $app_version"
fi

app_archs="$(lipo -archs "$app_executable")"
widget_archs="$(lipo -archs "$widget_executable")"
case " $app_archs " in *" arm64 "*) ;; *) fail "app is missing arm64" ;; esac
case " $app_archs " in *" x86_64 "*) ;; *) fail "app is missing x86_64" ;; esac
case " $widget_archs " in *" arm64 "*) ;; *) fail "widget is missing arm64" ;; esac
case " $widget_archs " in *" x86_64 "*) ;; *) fail "widget is missing x86_64" ;; esac
codesign --verify --deep --strict --verbose=2 "$app" >/dev/null 2>&1 || fail "app or embedded widget signature is invalid"

case "$app_build" in *[!0-9]*|'') fail "bundle build number is not numeric" ;; esac
head_commit="$(git rev-parse HEAD)"
max_previous_build=0
for tag in $(git tag --list 'v*'); do
    tag_commit="$(git rev-parse "$tag^{commit}" 2>/dev/null || true)"
    [ "$tag_commit" = "$head_commit" ] && continue
    tag_build="$(git show "${tag}:CodexQuotaWidget.xcodeproj/project.pbxproj" 2>/dev/null | sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9][0-9]*\).*/\1/p' | sort -n | tail -1)"
    case "$tag_build" in *[!0-9]*|'') continue ;; esac
    [ "$tag_build" -gt "$max_previous_build" ] && max_previous_build="$tag_build"
done
[ "$app_build" -gt "$max_previous_build" ] || fail "build $app_build must be greater than released build $max_previous_build"

plutil -convert json -o "$tmp/app-intents.json" "$app_metadata"
plutil -convert json -o "$tmp/widget-intents.json" "$widget_metadata"
for token in AppearanceV3ConfigurationIntent useLightAppearance glassOpacity; do
    grep -Fq "$token" "$tmp/app-intents.json" || fail "app intent metadata lacks $token"
    grep -Fq "$token" "$tmp/widget-intents.json" || fail "widget intent metadata lacks $token"
done
strings "$widget_executable" > "$tmp/widget-strings.txt"
grep -Fq 'dev.codexquota.widget.small.v3' "$tmp/widget-strings.txt" || fail "small widget kind is absent from binary"
grep -Fq 'dev.codexquota.widget.large.v3' "$tmp/widget-strings.txt" || fail "large widget kind is absent from binary"
pass "signed, version-matched app and extension with both widget configurations"

section "Non-installed copies stay inert"
volume_name="Codex Quota Gate $$"
mkdir -p "$tmp/dmg-root"
/usr/bin/ditto "$app" "$tmp/dmg-root/Codex Quota.app"
hdiutil create -quiet -volname "$volume_name" -srcfolder "$tmp/dmg-root" -format UDZO "$tmp/translocation.dmg"
hdiutil attach -quiet -nobrowse -readonly "$tmp/translocation.dmg"
translocation_mount="/Volumes/$volume_name"
"$translocation_mount/Codex Quota.app/Contents/MacOS/Codex Quota" >"$tmp/translocated.log" 2>&1 &
translocated_pid=$!
sleep 2
if /usr/sbin/lsof -nP -iTCP:48193 -sTCP:LISTEN >/dev/null 2>&1; then
    fail "a DMG copy started the snapshot bridge"
fi
kill "$translocated_pid" 2>/dev/null || true
wait "$translocated_pid" 2>/dev/null || true
translocated_pid=""
/usr/bin/pluginkit -r "$translocation_mount/Codex Quota.app/Contents/PlugIns/CodexQuotaWidgetExtension.appex" >/dev/null 2>&1 || true
hdiutil detach "$translocation_mount" >/dev/null
translocation_mount=""
pass "DMG/build copies do not run registration repair or occupy the live snapshot port"

section "Widget gallery registration"
mkdir -p "$HOME/Applications"
runtime_app="$HOME/Applications/Codex Quota Release Gate $$.app"
[ ! -e "$runtime_app" ] || fail "temporary installed-app path already exists"
/usr/bin/ditto "$app" "$runtime_app"
runtime_widget="$runtime_app/Contents/PlugIns/CodexQuotaWidgetExtension.appex"
runtime_executable="$runtime_app/Contents/MacOS/Codex Quota"
/usr/bin/pluginkit -a "$runtime_widget" || fail "pluginkit rejected the widget extension"
registered_here=1
/usr/bin/pluginkit -e use -i "$widget_identifier" || fail "pluginkit could not enable the widget extension"
found=0
for _ in {1..20}; do
    /usr/bin/pluginkit -m -A -v -i "$widget_identifier" > "$tmp/pluginkit.txt"
    if grep -Fq "$runtime_widget" "$tmp/pluginkit.txt"; then found=1; break; fi
    sleep 0.25
done
[ "$found" -eq 1 ] || fail "registered extension is absent from the WidgetKit registry"
registration_count="$(awk -v id="$widget_identifier" 'index($0, id "(") { count++ } END { print count + 0 }' "$tmp/pluginkit.txt")"
[ "$registration_count" -eq 1 ] || fail "duplicate widget registrations detected ($registration_count); quarantine old app builds"
grep -E '^\+.*dev\.codexquota\.app\.widget' "$tmp/pluginkit.txt" | grep -Fq "$runtime_widget" || fail "current widget registration is not enabled"
pass "Apple plug-in registry exposes exactly one current Codex Quota widget extension"

section "Snapshot bridge recovery and freshness"
if /usr/sbin/lsof -nP -iTCP:48193 -sTCP:LISTEN >/dev/null 2>&1; then
    fail "port 48193 is already occupied; quit old Codex Quota copies before release testing"
fi

cat > "$tmp/fake-codex" <<'PY'
#!/usr/bin/env python3
import json
import sys

generation = 0
for line in sys.stdin:
    request = json.loads(line)
    method = request.get("method")
    request_id = request.get("id")
    response = None
    if method == "initialize":
        response = {"id": request_id, "result": {}}
    elif method == "account/read":
        response = {"id": request_id, "result": {"account": {"email": "gate@example.invalid", "planType": "test"}}}
    elif method == "account/rateLimits/read":
        generation += 1
        used = 11 if generation == 1 else 46
        response = {"id": request_id, "result": {"rateLimits": {
            "primary": {"usedPercent": used, "windowDurationMins": 300},
            "secondary": {"usedPercent": used, "windowDurationMins": 10080}
        }}}
    elif method == "account/usage/read":
        tokens = 1111 if generation == 1 else 4646
        response = {"id": request_id, "result": {"dailyUsageBuckets": [
            {"startDate": "2099-01-01", "tokens": tokens}
        ]}}
    if response is not None:
        print(json.dumps(response), flush=True)
PY
chmod +x "$tmp/fake-codex"

python3 -c 'import pathlib,socket,sys,time; s=socket.socket(); s.bind(("127.0.0.1",48193)); s.listen(); pathlib.Path(sys.argv[1]).touch(); time.sleep(30)' "$tmp/blocker-ready" &
blocker_pid=$!
for _ in {1..40}; do
    [ -f "$tmp/blocker-ready" ] && break
    sleep 0.1
done
[ -f "$tmp/blocker-ready" ] || fail "could not reserve the snapshot port for the recovery test"

CODEX_BINARY="$tmp/fake-codex" "$runtime_executable" >"$tmp/app.log" 2>&1 &
app_pid=$!
sleep 2
kill "$blocker_pid" 2>/dev/null || true
wait "$blocker_pid" 2>/dev/null || true
blocker_pid=""

first_snapshot=0
for _ in {1..12}; do
    if curl --silent --show-error --fail --max-time 2 \
        -D "$tmp/headers.txt" \
        http://127.0.0.1:48193/snapshot \
        -o "$tmp/snapshot.json"; then
        if python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); raise SystemExit(0 if s.get("weekly",{}).get("usedPercent")==11 and s.get("dailyUsage",[{}])[-1].get("tokens")==1111 else 1)' "$tmp/snapshot.json"; then
            first_snapshot=1
            break
        fi
    fi
    sleep 1
done
[ "$first_snapshot" -eq 1 ] || fail "snapshot bridge did not recover with the first synchronized quota snapshot"
grep -Eiq '^Content-Type: *application/json' "$tmp/headers.txt" || fail "snapshot response is not JSON"
grep -Eiq '^Cache-Control: *no-store' "$tmp/headers.txt" || fail "snapshot response can be cached"
first_updated_at="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["updatedAt"])' "$tmp/snapshot.json")"

python3 - "$tmp/snapshot.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    snapshot = json.load(handle)

required = {"appearance", "dailyUsage", "updatedAt"}
missing = sorted(required.difference(snapshot))
if missing:
    raise SystemExit(f"snapshot missing fields: {', '.join(missing)}")
if "email" in snapshot or "plan" in snapshot:
    raise SystemExit("snapshot leaks account identity")
if not isinstance(snapshot["dailyUsage"], list):
    raise SystemExit("dailyUsage is not a list")
PY

second_snapshot=0
for _ in {1..22}; do
    curl --silent --show-error --fail --max-time 2 \
        http://127.0.0.1:48193/snapshot \
        -o "$tmp/snapshot.json" || true
    if python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); ok=s.get("weekly",{}).get("usedPercent")==46 and s.get("dailyUsage",[{}])[-1].get("tokens")==4646 and float(s.get("updatedAt",0))>float(sys.argv[2]); raise SystemExit(0 if ok else 1)' "$tmp/snapshot.json" "$first_updated_at"; then
        second_snapshot=1
        break
    fi
    sleep 1
done
[ "$second_snapshot" -eq 1 ] || fail "15-second polling did not replace snapshot A with snapshot B"
pass "port recovery, Codex protocol, 15-second polling, A-to-B refresh, and privacy checks"

if [ -n "$dmg_input" ]; then
    section "DMG payload"
    hdiutil verify "$dmg_input" >/dev/null || fail "DMG verification failed"
    payload_mount="$tmp/payload-mount"
    mkdir -p "$payload_mount"
    hdiutil attach -quiet -nobrowse -readonly -mountpoint "$payload_mount" "$dmg_input"
    payload_app="$payload_mount/Codex Quota.app"
    [ -d "$payload_app" ] || fail "DMG does not contain Codex Quota.app"
    [ "$(plist_value "$payload_app/Contents/Info.plist" CFBundleShortVersionString)" = "$app_version" ] || fail "DMG app version differs from checked app"
    [ "$(plist_value "$payload_app/Contents/Info.plist" CFBundleVersion)" = "$app_build" ] || fail "DMG app build differs from checked app"
    codesign --verify --deep --strict --verbose=2 "$payload_app" >/dev/null 2>&1 || fail "DMG contains an invalid app signature"
    hdiutil detach "$payload_mount" >/dev/null
    payload_mount=""
    pass "verified DMG contains the exact signed app version and build"
fi

printf '\nRelease gate passed for Codex Quota %s (%s).\n' "$app_version" "$app_build"
