#!/bin/bash
set -euo pipefail
app_dir="${1:?Usage: verify-app.sh app-bundle}"
entitlements_file="$(mktemp)"
trap 'rm -f "$entitlements_file"' EXIT
codesign --verify --deep --strict "$app_dir"
codesign --display --entitlements :- "$app_dir" > "$entitlements_file" 2>/dev/null
python3 - "$entitlements_file" "$app_dir" <<'PY'
import plistlib
import subprocess
import sys
with open(sys.argv[1], 'rb') as source:
    entitlements = plistlib.load(source)
if entitlements != {'com.apple.security.personal-information.calendars': True}:
    raise SystemExit('Unexpected app entitlements; review any expansion of permissions.')
signature = subprocess.run(['codesign', '--display', '--verbose=4', sys.argv[2]], text=True, capture_output=True, check=True)
if not any('flags=' in line and 'runtime' in line for line in signature.stderr.splitlines()):
    raise SystemExit('The app must be signed with hardened runtime.')
PY
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
