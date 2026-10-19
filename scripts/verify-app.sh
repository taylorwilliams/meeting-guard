#!/bin/bash
set -euo pipefail
app_dir="${1:?Usage: verify-app.sh app-bundle}"
entitlements_file="$(mktemp)"
trap 'rm -f "$entitlements_file"' EXIT
codesign --verify --deep --strict "$app_dir"
codesign --display --entitlements :- "$app_dir" > "$entitlements_file" 2>/dev/null
calendar_access="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.personal-information.calendars' "$entitlements_file" 2>/dev/null || true)"
if [ "$calendar_access" != "true" ]; then
    printf 'Missing signed calendar entitlement. macOS will block the permission prompt.\n' >&2
    exit 1
fi
calendar_message="$(/usr/libexec/PlistBuddy -c 'Print :NSCalendarsFullAccessUsageDescription' "$app_dir/Contents/Info.plist" 2>/dev/null || true)"
if [ -z "$calendar_message" ]; then
    printf 'Missing calendar usage description in the app bundle.\n' >&2
    exit 1
fi
printf 'Verified signature, calendar entitlement and privacy metadata.\n'
