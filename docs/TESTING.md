# Acceptance checks

## Automated

Run `swift test`, then `scripts/build-app.sh`. Verify the bundled executable with `--diagnostics`, and verify the signature with `codesign --verify --deep --strict "dist/Meeting Guard.app"`.

Core tests exercise stable delivery across restart, overdue catch-up and expiry, simultaneous meetings, multiple offsets, dismissing one recurrence, persisted snooze, event edits, deleted events, pause, filters, all-day timing, overnight work hours, unsafe meeting URLs, weekday/weekly recurrence, daylight-saving transitions, state permissions/corruption and automation URL validation.

## Interface without real data

1. Launch the bundled executable with `--demo`. Check agenda cards, today/seven-day selection, sample event details and Settings. Demo mode does not read or write saved settings or request calendar access.
2. Preview an alert, inspect every visible action, then press Esc. The prior app should regain focus. Repeat and dismiss with the button.
3. Open a reminder editor, add a future reminder, edit it, toggle it and delete it. Demo changes stay in memory.
4. Change alert palettes and preview each. Check dark/light appearance, keyboard navigation and reduced window size.
5. Open the menu-bar popover, agenda window and settings window. Closing an agenda window should leave the menu item running. Quit from the menu.

## Real-calendar checks requiring user permission

1. Launch normally and choose Connect Calendars. Approve the OS request yourself. Check the allowed and denied states.
2. Create a short test event in Calendar at least three minutes ahead; check it appears, then test a two-minute alert, call join, dismiss and snooze. Use your own test meeting link.
3. Change its time and notes; remove it; decline an invitation. Verify changes and disabled calendars remove pending alerts.
4. Create two simultaneous events and check both can be handled in turn. Quit/relaunch after snoozing and verify delivery once.
5. Sleep briefly across an alert time. Wake within ten minutes and before the event ends. It should appear once. Repeat outside the catch-up window; it should be skipped.
6. Test full-screen Spaces, display under pointer and every attached monitor. Verify display disconnection doesn't leave an invisible panel or prevent dismissal.
7. Move the app to Applications and enable launch at login. Confirm status in macOS Login Items and test after login.
8. Test privacy mode with real titles/notes on all views, including menu-bar hover. Management views intentionally retain saved reminder titles and calendar names.

Calendar permission, a real video service join, login/reboot, sleeping the user's computer and multiple-monitor hardware behaviour are manual acceptance checks, not covered by the pure core test suite.

## Local verification — 19 October 2026

- Swift 6.4, Apple Silicon, macOS 27.0.1: debug and release builds succeeded; all 22 automated tests passed.
- App bundle privacy metadata, property list and local code signature verified successfully.
- Native interface inspected: onboarding, agenda, calendar/alert settings, reminder creation and editing.
- Sample full-screen alert rendered and dismissed with Esc.
- A temporary personal reminder fired automatically at its scheduled time. Snooze dismissed the alert; its pending state was restored after quitting and reopening the app, then the alert fired again at the snoozed time. Button dismissal and removal of the test reminder were verified.
- Calendar permission was left for the user. Real-calendar integration, actual video join, sleep/reboot, additional monitors and earlier supported macOS versions have not been exercised locally.

### Calendar connection fix

The first bundle was missing the calendar resource-access entitlement required by hardened runtime. macOS's TCC log confirmed that it blocked the permission prompt. The build now signs with `Resources/MeetingGuard.entitlements` and runs `scripts/verify-app.sh` to check the actual signed entitlement and usage description. The check was verified to reject the old bundle and accept the fixed bundle.

The connection flow now reports unsuccessful requests, prevents duplicate requests, and shows errors in both the agenda and Calendar settings. All 22 tests passed after the fix. The rebuilt app was reopened, the Connect Calendars button triggered a macOS calendar permission request, and calendar events appeared in the agenda after the user approved access. A real-calendar alert and external meeting join remain untested.

### Foghorn and sound repetition

Playback now supports Play once, Repeat until answered, and Repeat for a set time. Timed playback uses a monotonic clock independently of window redraws. Added tests cover the two-minute deadline, custom duration, indefinite playback, immediate stop, disabled sound, unavailable audio, compatibility with old saved settings, and saving the new modes. The original foghorn waveform is also decoded with Apple's audio API and checked for duration, low frequencies, a quiet gap and unclipped samples. Air Raid Siren is decoded and tested for rising/falling pitch and unclipped samples; Pulse Horn is decoded and tested for four steady blasts with quiet gaps. Deep Bass Pulse is decoded and tested for low-frequency energy and four slower blasts. The suite now contains 34 tests.

### Public-release hardening

The Swift suite now has 41 tests, adding disabled-by-default automation, malformed and oversized links, prompt rate limiting, HTTPS-only meeting links, bounded imports, private state-directory permissions and symlink rejection. Three Python tests validate the repository policy, including that it cannot publish the repository or add collaborators. Local Actionlint, Gitleaks source/history scans, release compilation and signed-bundle verification passed. GitHub CI separately checks the older supported Swift toolchain.

To check automation manually, leave automation links disabled and open a test URL; no full-screen alert should appear. Enable the option in General settings, open a fictional reminder URL and verify Cancel leaves the screen alone. Show Reminder should display the alert. Repeated requests within ten seconds and further requests while confirmation is open should not create more dialogs.
