# Setup help

## Connect a calendar account

1. Open **Calendar** on your Mac and choose **Calendar → Add Account**.
2. Choose your provider. For a Microsoft 365 work or school account, choose **Microsoft Exchange**.
3. Sign in with your existing account and follow your organisation's sign-in prompts.
4. Check that **Calendars** is enabled for the account under **System Settings → Internet Accounts**.
5. Wait until your events appear in macOS Calendar. Meeting Guard can only read calendars available there; an account connected only in Outlook is not enough.
6. Open Meeting Guard, click **Connect Calendars** and allow full calendar access. Choose the calendars to watch under **Settings → Calendars**.

See [Apple's calendar account instructions](https://support.apple.com/guide/calendar/icl4308d6701/mac).

### Microsoft 365 work and school accounts

Use your organisation's existing account. Meeting Guard reads the calendars available on your Mac through Apple's EventKit API. It does not ask you to create an Azure tenant, register a Meeting Guard enterprise app, or supply a client ID or secret.

If Microsoft asks for administrator approval, contact your IT team. They may need to approve **Apple Internet Accounts** in your existing Microsoft Entra tenant, depending on the organisation's [app consent policies](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/manage-app-consent-policies). Meeting Guard cannot change those policies.

**Exchange sync changes from October 2026:** Apple reports that Exchange Online's EWS retirement can stop macOS Calendar from signing in or syncing. If this affects your account, ask your Exchange administrator to follow [Apple's current Exchange guidance](https://support.apple.com/en-us/149092) and its linked Microsoft instructions. Check that syncing works in macOS Calendar before setting up Meeting Guard.

## The build cannot find Swift 6 or the macOS SDK

Install the full Xcode app, open it once and complete its setup. The standalone Command Line Tools may point to an older toolchain.

If Xcode is installed at `/Applications/Xcode.app`, select it in Terminal:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Use your actual Xcode path if you installed it elsewhere. Then run `./scripts/build-app.sh` again from the repository folder.

## Start automatically at login

1. Quit Meeting Guard if it is running from the build folder.
2. Move **Meeting Guard.app** from `dist` into **Applications**, then open it from Applications.
3. In Meeting Guard, open **Settings → General** and switch on **Launch Meeting Guard at login**.
4. Check **System Settings → General → Login Items & Extensions**. Meeting Guard should appear under **Open at Login**. On older macOS versions, this page is called **Login Items**.

Meeting Guard starts when you sign in after a restart. You do not need to add it again using the **+** button in System Settings.

If it does not start, open the copy in Applications and turn its launch-at-login switch off and on again. Keep the app in Applications so the login item can find it.

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
