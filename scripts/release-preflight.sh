#!/bin/bash
set -euo pipefail

app="${1:?Usage: $0 <Codex Quota.app>}"
widget="$app/Contents/PlugIns/CodexQuotaWidgetExtension.appex"
app_metadata="$app/Contents/Resources/Metadata.appintents/extract.actionsdata"
widget_metadata="$widget/Contents/Resources/Metadata.appintents/extract.actionsdata"

echo 'Checking widget gallery registration…'
test -d "$widget"
test -x "$widget/Contents/MacOS/CodexQuotaWidgetExtension"
test "$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$widget/Contents/Info.plist")" = 'com.apple.widgetkit-extension'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$widget/Contents/Info.plist")" = 'dev.codexquota.app.widget'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")" = "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$widget/Contents/Info.plist")"
plutil -convert json -o - "$app_metadata" | grep 'AppearanceV3ConfigurationIntent'
plutil -convert json -o - "$widget_metadata" | grep 'AppearanceV3ConfigurationIntent'
plutil -convert json -o - "$widget_metadata" | grep 'useLightAppearance'
plutil -convert json -o - "$widget_metadata" | grep 'glassOpacity'
strings "$widget/Contents/MacOS/CodexQuotaWidgetExtension" | grep 'dev.codexquota.widget.small.v3'
strings "$widget/Contents/MacOS/CodexQuotaWidgetExtension" | grep 'dev.codexquota.widget.large.v3'
grep 'WidgetRepairService.repair()' App/CodexQuotaApp.swift
grep 'CodexQuotaWidgetExtension' App/WidgetRepairService.swift
grep 'lsregister' App/WidgetRepairService.swift
grep 'pluginkit' App/WidgetRepairService.swift
grep 'reloadAllTimelines' App/WidgetRepairService.swift
grep 'requiresInstalledCopy' App/WidgetRepairService.swift
grep 'AppTranslocation' App/WidgetRepairService.swift
grep 'isCurrentWidgetRegistered' App/WidgetRepairService.swift
grep 'InstallLocationView' App/CodexQuotaApp.swift

echo 'Checking no-black-screen rendering contract…'
grep 'return .black.opacity(resolvedOpacity)' Shared/QuotaWidgetView.swift
! grep 'Color(red: 0.04' Shared/QuotaWidgetView.swift
grep 'containerBackground(for: .widget)' Widget/CodexQuotaWidget.swift
! grep 'Color.clear' Widget/CodexQuotaWidget.swift

echo 'Checking widget synchronization contract…'
grep 'private struct PendingRefresh' App/CodexAppServer.swift
grep 'withTimeInterval: 15' App/CodexAppServer.swift
grep 'reloadTimelines(ofKind: SnapshotStore.smallWidgetKind)' App/CodexAppServer.swift
grep 'reloadTimelines(ofKind: SnapshotStore.largeWidgetKind)' App/CodexAppServer.swift
grep 'reloadIgnoringLocalCacheData' Widget/CodexQuotaWidget.swift
grep 'addingTimeInterval(60)' Widget/CodexQuotaWidget.swift

echo 'Checking live local snapshot bridge…'
"$app/Contents/MacOS/Codex Quota" >/tmp/codex-quota.log 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT
curl --fail --retry 10 --retry-delay 1 --retry-connrefused \
  http://127.0.0.1:48193/snapshot -o /tmp/snapshot.json
grep '"dailyUsage"' /tmp/snapshot.json
grep '"appearance":"dark"' /tmp/snapshot.json
! grep -E '"email"|"plan"' /tmp/snapshot.json

echo 'Release preflight passed.'
