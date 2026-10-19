#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$PWD/dist/Meeting Guard.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/MeetingGuard" "$app_dir/Contents/MacOS/MeetingGuard"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
swift scripts/make-icon.swift "$app_dir/Contents/Resources/MeetingGuard.icns"
codesign --force --options runtime --entitlements Resources/MeetingGuard.entitlements --sign "${SIGNING_IDENTITY:--}" "$app_dir"
scripts/verify-app.sh "$app_dir"
printf '\nBuilt %s\n' "$app_dir"
