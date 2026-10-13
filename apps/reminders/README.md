# RemindersSix

A native, functional recreation of the iPhone Reminders app from iOS 6, for iOS 17 and later. It uses original artwork and public Apple APIs.

## Run

Open `RemindersSix.xcodeproj`, select the shared `RemindersSix` scheme, and run on an iPhone simulator or device. The collection's `../../iOS6Apps.xcworkspace` also includes this project. Device builds require your own development team.

Ordinary launches create one empty local Reminders list. `--demo` creates isolated, in-memory sample lists in the selected language and suppresses notification scheduling and system account access. `--uitesting` uses isolated data; `--test-store <absolute-path>` enables an explicitly separate test archive for relaunch checks. These options never clear the production archive.

To mirror the selected simulator in the Codex in-app browser:

```sh
zsh scripts/serve_sim.sh <simulator-udid>
```

Open the exact localhost URL it prints and keep the serving terminal alive. The script cleans up only the named simulator's helper. If npm's default cache is unwritable, set `npm_config_cache` to an accessible temporary directory. Simulator access may require execution outside a restricted filesystem sandbox.

## Design and interactions

The [shared design language](../../docs/design-language.md) applies selectively. The active body material extends behind the real system status bar: main reminders, details, list editors, and accounts use the same unshaded paper texture with dark system time and icons; list management uses the charcoal color of its recessed list panel, with light system time and icons. The main paper page's double red margin also continues into the status area, aligned with the inset notebook, together with the notebook's fine dotted horizontal ruling at the same 52-point pitch. The route determines the material and system appearance, including the Accounts page opened from list management. The leather navigation bar remains an independent panel below the status area, with fine upper and lower edges. List management deepens that same leather texture with restrained shading to distinguish its navigation panel from the dark list body and leather surround. Visible irregular four-point leather grains surround the historical inset paper or list panel and continue behind the bottom safe area. Retaining this leather bottom follows the user's explicit review and overrides the guide's default top-and-bottom continuity rule for this app. The inset paper's small corners are part of the historical content panel. Details retain rectangular inset settings groups; list management retains the compact search field and seven individually beveled date cells. Plain date numbers avoid crowding the Chinese ribbon. This app does not use a modern page sheet or Liquid Glass toolbar.

- Swipe the red title to switch lists; VoiceOver exposes Previous list and Next list.
- Use the plus button to type directly into a new paper row, then Done to save. Its disclosure arrow opens Details immediately; canceling Details preserves the original quick-entry draft. Tap an entry to edit its title, date, recurrence, priority, list, and notes. Cancel preserves the original record.
- Tap the square checkbox to complete an entry. Its thin custom-drawn checkmark extends slightly above and to the right of the 16-point inset square, matching the supplied iOS 6 notebook reference. The row stays in its original list or date page with normal title text. Tap the checked box again to mark it incomplete. Lists → Completed also provides a consolidated history and undo; list counts represent unfinished items. A completed recurring local reminder stays visible and creates its next occurrence, retaining month-end and leap-day anchors. Undo removes only an untouched successor and preserves edited successors.
- Swipe a row left to reveal Delete. Edit enables drag ordering; context menus and accessibility actions offer movement without dragging.
- Each list has a full-row button covering its title, whitespace, count, and disclosure indicator; edit-mode deletion remains a separate button. Lists provides all-list search, Completed, Today, a seven-day date strip, list creation, renaming, deletion, and drag ordering. Account access and permission recovery live on a separate paper settings page opened from the small Accounts control. Deleting the last local list is prevented.
- The app follows Weather's language rule: the first preferred system/per-app language wins, all Chinese variants use Simplified Chinese, and unsupported languages fall back to English. UI text, dates, accessibility labels, permission descriptions, and the Home Screen name are covered. User-entered text is preserved verbatim.

## Data and system integrations

Local lists are stored atomically in `Application Support/RemindersSix/reminders.json` inside the app sandbox. A failed local write rolls back in-memory changes. An unreadable archive is preserved and write operations are blocked, preventing silent data loss. Demo content is never written into this archive.

Date alerts use UserNotifications. Completing, editing, moving, or deleting local records reconciles the app's pending alerts. System-owned reminders use EventKit alarms to avoid duplicate app notifications. Local recurrence advances on completion; an overdue unfinished reminder remains overdue. Notification permission is requested only when saving a local reminder with an alert. The app provides an Open Settings recovery path after denial.

Location selection supports an entered address through MapKit search and the current location through Core Location. Arrival/departure reminders use a circular region of 200 meters. UserNotifications requires When In Use location authorization; Always authorization is unnecessary because the OS monitors these notification regions. Region delivery is subject to system heuristics, permission, and hardware. Physical arrival/departure delivery needs a real-device field test.

Lists → Accounts → Connect System Reminders explicitly requests full reminder access. Connected lists and reminders can be read, added, edited, moved, completed, and deleted through EventKit. Account synchronization is handled by the system, including iCloud when configured there. The app refreshes on foregrounding, EventKit change notifications, and manual Refresh. Disconnect removes the app's cache and leaves system data intact. Read-only providers remain read-only. Advanced provider recurrence and existing alarms are preserved unless supported fields are deliberately changed; reminders with advanced repeat rules keep their date, repeat, and list locked. Local ordering of system records is an app preference and is not written to a provider's ordering metadata.

Keyboard, text selection, permission dialogs, notification banners, and confirmation alerts use the current OS appearance. Account setup, Siri, Spotlight indexing, shared-list invitations, and arbitrary provider-specific recurrence editing remain system features. This recreation does not use private iOS 6 frameworks. Save failures from public system services are surfaced; an external EventKit write and the local cache cannot form one atomic transaction.

iOS permits at most 64 pending local notifications per app and limits location regions. The app prioritizes upcoming dates, reserves up to 60 date requests and 20 location requests within that total, and reports overflow rather than implying that every alert was scheduled. Notifications are ordinary reminder alerts, not critical alarms.

## References and verification

- [Apple iPhone User Guide for iOS 6, page 88: interface and icon](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf)
- [iOS 6 Reminders screenshots and behavior](https://www.macstories.net/tutorials/ios-6-tips-tricks-hidden-features/)
- [Historical list-management reference](https://www.imore.com/how-reorder-lists-reminders-iphone-and-ipad)
- [Historical details reference](https://apple.stackexchange.com/questions/83423/how-to-move-a-reminder-from-one-list-to-another-in-ios)
- [Apple: scheduling local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple: location notification authorization and triggers](https://developer.apple.com/documentation/usernotifications/unlocationnotificationtrigger)
- [Apple: accessing the event store](https://developer.apple.com/documentation/eventkit/accessing-the-event-store)

Historical screenshots are visual references only. Paper and leather are original procedural artwork; the icon is original imagegen artwork following the iOS 6 three-checkmark composition. The [reviewed source and prompt](artwork/README.md) are retained in the project; no Apple screenshot or extracted UI asset is bundled. `scripts/create_project.py` regenerates the standalone project and scheme, while `scripts/generate_resources.py` regenerates the material tiles, packages the reviewed icon, and regenerates both matching localization tables.

See [the verification record](docs/verification.md) for actual test results, screenshots, and the boundary between simulator evidence and device-only behavior.
