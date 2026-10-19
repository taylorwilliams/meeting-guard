# Setup help

## The build cannot find Swift 6 or the macOS SDK

Install the full Xcode app, open it once and complete its setup. The standalone Command Line Tools may point to an older toolchain.

If Xcode is installed at `/Applications/Xcode.app`, select it in Terminal:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Use your actual Xcode path if you installed it elsewhere. Then run `./scripts/build-app.sh` again from the repository folder.

## Calendar access is off

Open **System Settings → Privacy & Security → Calendars** and allow full access for Meeting Guard. Reopen the app from Applications.

If you built a new version, macOS may ask for access again. Use the app bundle; launching the bare executable with `swift run` does not include the calendar permission metadata.

## An account or event is missing

Check that the account and event appear in macOS Calendar first. An account connected only in Outlook may need adding under **System Settings → Internet Accounts**.

Then check **Settings → Calendars** in Meeting Guard and click **Refresh now**. Calendar account synchronisation is managed by macOS. Filters and working hours can suppress alerts.

## Explore with sample events

Quit Meeting Guard, then run:

```sh
"/Applications/Meeting Guard.app/Contents/MacOS/MeetingGuard" --demo
```

Demo mode uses fictional events and does not read calendars or change saved settings. Quit and reopen the app normally to return to your own events.

## An alert did not appear

Keep the app running and the Mac awake. Check that alerts are not paused and that your calendar, filters and working hours allow the event.

After waking or restarting, alerts can catch up within ten minutes of their scheduled time if the event has not ended. Older alerts are skipped.
