# Meeting Guard

A native, MIT-licensed macOS menu-bar app for meeting reminders that are hard to miss. Written independently in Swift and SwiftUI, using Apple's EventKit calendar API. macOS 14+, Xcode 16+ / Swift 6. No third-party packages.

## Run

```sh
swift test
./scripts/build-app.sh
open "dist/Meeting Guard.app"
```

The build produces an app bundle with its own identifier, original icon, calendar usage description, signed calendar-access entitlement and local ad-hoc signature. The build verifies the entitlement as well as the signature: hardened-runtime apps need both the usage description and the entitlement for macOS to show the permission prompt. Move it to Applications before enabling launch at login. Use the app bundle for calendar access; `swift run` doesn't provide the bundle's privacy metadata.

Click **Connect Calendars**, approve macOS's calendar prompt, then choose calendars in Settings. Accounts must be configured in **macOS Calendar / Internet Accounts**, including Google or Exchange if needed. Accounts connected only inside Outlook may need adding to macOS first. Calendar access is optional for personal reminders.

Closing the agenda window leaves the app running in the menu bar. Quit from its menu to stop it. To explore with fictional data, without reading or modifying saved data:

```sh
"dist/Meeting Guard.app/Contents/MacOS/MeetingGuard" --demo
```

Quit an existing instance before switching to demo mode. Other launch arguments: `--background` starts without the agenda window; `--diagnostics` prints version and bundle metadata without opening the interface or accessing calendars. Opening another bundled instance activates the existing process.

## Included

- Full-screen alerts over normal apps and full-screen Spaces; all displays or the display under the pointer.
- Agenda window and menu-bar popover, with today's events or the next seven days and an optional menu-bar countdown.
- One or multiple configurable alert times, from event start to 24 hours beforehand.
- Join supported video meetings from the agenda, event details or an alert.
- Dismiss, skip one event occurrence, snooze for 1 or 5 minutes, or snooze until the event starts. Simultaneous events queue independently.
- Personal reminders with notes, editing, enable/disable and daily, weekday or weekly repetition. Recurrence uses local calendar time across daylight-saving changes.
- Per-calendar selection, accepted-only / video-only / alarm-only filters, skip-free, all-day alert time and case-insensitive exclusion phrases.
- Work hours and weekday selection, including overnight shifts; temporary pause with automatic expiry.
- Three original alert palettes, palette import/export, privacy mode, original Foghorn, Air Raid Siren, Pulse Horn and Deep Bass Pulse tones, system sounds and volume control.
- Sound playback choices: play once, repeat until answered, or repeat for a configurable duration (1 second to 24 hours). New settings default to a foghorn repeating for 2 minutes.
- Launch at login through macOS's supported ServiceManagement API.
- Local automation URL: `meetingguard://alert?title=Take%20a%20break&notes=Stand%20up`.

Meeting links currently include Google Meet, Zoom and Zoom Government, Teams, Webex, GoTo, Whereby, Jitsi, FaceTime, Chime, RingCentral, 8x8, join.me, Discord, Slack, Zoho, Doxy.me, Cal.com and Proton Meet. Links use HTTP(S) and open through the default handler. The app rejects executable URL schemes, embedded credentials and lookalike domain suffixes. Meeting Guard never opens a call automatically.

## Delivery behaviour

Keep Meeting Guard running. It checks the scheduler every second, reloads local events every minute, and responds to EventKit changes, clock changes and wake notifications. The agenda fetches an eight-day rolling window, including recurring calendar occurrences.

On wake or restart, an alert can catch up within **10 minutes of its scheduled time**, provided the event hasn't ended. Older alerts are skipped. This also means a meeting synced late can still alert within that window. The app cannot wake a sleeping Mac or alert while shut down. Calendar account refresh is controlled by macOS, independently of Meeting Guard's local refresh.

Delivery history, dismissed occurrences and snoozes persist across restarts. Multiple overdue alert times for the same occurrence collapse into one interruption. Dismiss suppresses the remaining alerts for that occurrence; later recurrences are independent. Snoozing suppresses other alerts while the snooze is pending. Calendar changes or disabling a reminder cancel a pending snooze when the event becomes ineligible.

Sound always stops when you dismiss, snooze or join the meeting. A timed sound stops at the chosen duration while the visual alert stays available until answered. Repeating foghorn playback uses a 5.5-second low two-tone blast followed by a short quiet gap. Moving between displays or queuing another meeting does not restart the current sound or extend its deadline. Existing settings retain their old sound choice until changed under Settings → Alerts.

Air Raid Siren provides a continuous mechanical-style wail that rises from 200 to 900 Hz and falls again over eight seconds. Pulse Horn gives four steady "DAAA" blasts, each 0.7 seconds long followed by a 0.3-second gap. Deep Bass Pulse gives four slower pulses blending a low body with clearer upper horn notes. All four tones are synthesised from original waveforms within the app.

Pause and work hours apply to personal reminders too. Alerts that become due while the app is running but suppressed are consumed, so resuming doesn't replay them. Calendar-specific filters don't apply to personal reminders. All-day alerts use the chosen hour on the first day, minus the configured lead time. Timed event details remain in the agenda after dismissing their alerts.

## Privacy

Calendar events are read locally through EventKit. The OS grants full calendar access because that is the permission Apple provides for reading; this app does not create, edit or delete calendar events. No analytics, ads, accounts, servers or network synchronisation are implemented. Only clicking a meeting link opens an external service.

Settings and personal reminders are stored in `~/Library/Application Support/MeetingGuard/state.json`. Pending snoozes include the event details needed to restore the alert. Delivery and dismissal records contain occurrence identifiers and timestamps; records expire after eight days. The state directory and file are created with owner-only permissions. Data is not separately encrypted; normal macOS account and disk protections apply. An unreadable or future-version state file is preserved and writes are disabled for that run.

Privacy mode hides event titles, locations and notes in the agenda, alerts and menu-bar tooltip. Calendar names, times and saved personal reminder titles remain visible in management views. It doesn't prevent screen recording.

## Current scope

Google and Microsoft calendars work when available through macOS Calendar. Direct Google/Microsoft OAuth, desktop widgets, Apple Reminders integration, travel time, shortcuts on join, arbitrary theme editing and other platforms are not implemented.

## Development and distribution

`MeetingGuardCore` contains deterministic, clock-injected scheduling, filtering, recurrence, meeting-link parsing, deep-link validation and JSON storage. `MeetingGuard` contains EventKit, AppKit window management, SwiftUI views and login-item integration. Tests cover delivery/restart, snoozes, simultaneous events, DST, recurrence, filters, unsafe links and storage failures.

```sh
swift build
swift test
./scripts/build-app.sh
"dist/Meeting Guard.app/Contents/MacOS/MeetingGuard" --diagnostics
```

The script builds for the current Mac's architecture. Set `CONFIGURATION=debug` for a development bundle. `SIGNING_IDENTITY` can specify your own Developer ID certificate. Public binary distribution additionally needs your own Developer ID signing and notarisation; the default local signature is not notarised. A stable Developer ID signature also avoids calendar approval being tied to changing ad-hoc builds. CI builds and tests on macOS but does not publish binaries.

Manual acceptance steps are in [docs/TESTING.md](docs/TESTING.md). Licensed under [MIT](LICENSE).
