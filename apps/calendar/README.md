# CalendarSix

A native SwiftUI recreation of the **iPhone Calendar in iOS 6**, running on iOS 17 or later. Open `CalendarSix.xcodeproj` directly, or select the `CalendarSix` scheme in the collection's `iOS6Apps.xcworkspace`.

## Design

The interface retains the original blue-gray glossy navigation and bottom toolbar, beveled gray month cells, white embossed date numbers, blue selected date, event dots, List/Day/Month segmented control, and grouped pinstripe event forms. The selected-day agenda uses compact ruled rows with a glossy calendar dot, start time aligned to the title's first text baseline, and location below the title; the empty area continues the rules. App-owned date wheels use curved bold lettering, separate recessed drums, dark metal framing, and a rectangular blue-gray glass selection band. The Start & End page pins the picker to the bottom and highlights the active date row. Landscape shows the week timeline. Controls respect modern safe areas, use the real system status bar, and support VoiceOver and Reduce Motion.

This app follows the [shared design language](../../docs/design-language.md) selectively: calendar content keeps its historical layout; management, settings, and editor pages use continuous pinstripes behind both safe areas with independent navigation chrome. The project does not bundle historical Apple screenshots or extracted Apple artwork. The icon and chrome are original generated drawings.

Historical visual references:

- [iOS 6 month view and landscape week behavior](https://apprize.best/apple/edge/1.html).
- [Contemporary iOS 6 calendar review](https://www.gsmarena.com/apple_ios_6_review-review-821p9.php).
- [iOS 6 date/time picker reference](https://www.oreilly.com/library/view/ios-6-programming/9781449342746/ch02s06.html).

## Features

- Month browsing with weekday headings, adjacent-month dates, event markers, selected-day events, and Today.
- Searchable list of upcoming events. Search covers titles, locations, and notes from one year before to one year after the selected date.
- Scrollable 24-hour day timeline, all-day band, overlap columns, current-time line, and seven-day landscape timeline. Tap an empty hour to add an event.
- Create, edit, and delete events with title, location, start/end, all-day duration, time zone, calendar, daily/weekly/fortnightly/monthly/yearly repeat, optional repeat end, two alerts, availability, URL, and notes.
- Repeating local events support editing/deleting one occurrence, all future events, or the complete series. Missing month dates and leap days are skipped; daily times remain local across DST. All-day end dates are exclusive internally and inclusive in the editor.
- Create, rename, recolor, delete, and filter local calendars. Set the default calendar and choose Sunday/Monday week start.
- Optional system calendar connection through EventKit full access. Reads calendars already configured on the device, including iCloud, Exchange, and subscriptions. Edit writable events, preserve provider-specific recurrence/alarms unless explicitly changed, and display read-only calendars.
- Real pending invitations, participant display, Maps/location and URL links, and an Open in System Calendar action.
- Persistent, atomic local JSON storage. Unreadable data is preserved and writing is blocked. Event mutations roll back on save failure.
- Local notification alerts after permission is enabled in Calendar Settings. The nearest 60 local alerts within the next year are scheduled and refreshed when the app opens or events change. System events use their own calendar alerts.
- A date icon with a localized weekday header, using the device's current Gregorian date and time zone. It refreshes on launch, foreground return, and significant date/time changes while active. Calendar Settings can disable it, restore the original icon, or retry an update.

## Language

Language selection matches Weather: the first preferred language beginning with `zh` selects Simplified Chinese; otherwise English is used. System and per-app language settings work. UI text, dates, weekdays, time conventions, accessibility labels, permission descriptions, and the app name are localized. User-entered event/calendar text is preserved.

The date icon uses English weekday names or Simplified Chinese weekday labels under the same language rule. Its 434 registered variants cover every weekday and day number in both languages. Numerals retain the visible-glyph centering used by the original icon renderer.

Date/time wheels use a combined localized date drum, hour/minute drums, and an AM/PM drum in English. Chinese uses 24-hour time. Date-only wheels follow localized year/month/day order. Each drum supports VoiceOver adjustment, kinetic scrolling, and row snapping through public UIKit APIs. Month/year changes clamp missing days, date changes retain local time across DST, and repeat-end dates cannot precede the event start.

## Run and preview

```bash
xcodebuild -project apps/calendar/CalendarSix.xcodeproj \
  -scheme CalendarSix -destination 'platform=iOS Simulator,name=iPhone Air' \
  -derivedDataPath /tmp/CalendarSix-derived build
```

Use a DerivedData location outside any file-provider-managed checkout if codesigning reports Finder/resource-fork metadata.

Launch normally for empty Home and Work calendars. `--demo` uses an in-memory sample agenda on October 12, 2026 and does not read/write local calendar files or access system calendars/reminders. `--uitesting` uses a separate JSON file; `--reset` only resets that test file.

Ordinary demo, unit-test, and UI-test launches do not change the Home Screen icon. Add `--icon-preview` to `--demo` to opt into real icon updates using the current date. The dedicated icon UI test uses `--uitesting --icon-testing --icon-date <ISO-8601-date>`; the fake clock is Debug-only and does not alter system time. Neither mode persists the dynamic-icon preference.

To show the running simulator in Codex:

```bash
zsh apps/calendar/scripts/serve_sim.sh <simulator-udid>
```

Open the printed local URL in the in-app browser. Keep the terminal alive. The script uses an isolated npm cache and only cleans up the helper for the selected simulator. If the stream is live but input is unresponsive, use `npx --yes serve-sim@latest repair-input -d <simulator-udid>` in an environment with CoreSimulator access, then restart the scoped mirror.

## Verification

```bash
xcodebuild -project apps/calendar/CalendarSix.xcodeproj \
  -scheme CalendarSix -destination 'platform=iOS Simulator,name=iPhone Air' \
  -derivedDataPath /tmp/CalendarSix-derived -parallel-testing-enabled NO test
xcrun swift-format lint --strict --recursive \
  apps/calendar/CalendarSix apps/calendar/CalendarSixTests apps/calendar/CalendarSixUITests
```

See [verification.md](docs/verification.md) for executed checks and screenshots. Resource and project files can be regenerated with `python3 scripts/generate_resources.py` and `python3 scripts/create_project.py` from this app directory. Resource generation requires Pillow.

Run `python3 scripts/verify_resources.py` to check bilingual key/placeholder coverage, permission strings, assets, and workspace registration. The EventKit integration test requires calendar permission on a test simulator; without it the fixture test explicitly skips. With permission, it creates and removes its own temporary local system calendar, and verifies recurring event read/write/delete plus cleanup. It never runs that fixture on a physical device.

## Platform boundaries

This recreates the iPhone app, with modern-device adaptation; it does not reproduce the iPad's separate leather desktop calendar. It does not run on iOS 6.

EventKit's [attendees property is read-only](https://developer.apple.com/documentation/eventkit/ekcalendaritem/attendees). Third-party apps cannot add invitees or send invitation responses through EventKit; use the system calendar for those actions. System recurring edits expose Only This Event and All Future Events because those are EventKit's supported spans. Account setup and subscriptions remain in system Settings. Existing complex provider recurrence rules are displayed as Custom and preserved.

CalendarSix local calendars do not sync to iCloud automatically. Choose a connected system calendar when creating an event for account-backed synchronization. The app does not move existing events between its local store and system accounts. Local notifications have a rolling schedule and require periodically opening the app for continued renewal.

Date icons use Apple's public [alternate-icon API](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)). iOS displays a system notice when the icon changes. An app that is suspended or closed cannot guarantee an icon update at midnight; the date catches up when the app next becomes active. This differs from the system Calendar's privileged behavior. An unsuccessful update preserves the current icon and offers a retry in Calendar Settings.
