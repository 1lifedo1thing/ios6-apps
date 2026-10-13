# RemindersSix verification

Verified on 13 October 2026 with the Build iOS Apps simulator tools, native XCTest UI automation, and a real serve-sim framebuffer in the Codex in-app browser.

## Darker list-management navigation leather

The user requested a more distinct dark leather navigation panel on list management. This page still uses the same leather texture as the main notebook, with additional black shading from 20% at the top to 38% at the bottom. The fine upper edge, lower contact edge, embossed title, and beveled buttons remain visible. The stronger shading is selected only by list management's header; the main notebook, editor, and account header retain their previous treatment. Status-area materials and the leather bottom are unchanged.

Build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T12-52-43-134Z_pid12132_4a70b2a5.log`). Existing focused UI checks passed with zero failures: English list creation/search/rename/move and Accounts Back on Air/iOS 26.2 (`test_sim_2026-10-13T12-54-15-911Z_pid12132_6eb74e95.xcresult`), and the Chinese list/accounts/return, completion, landscape, and large-text flow on SE/iOS 17.5 (`test_sim_2026-10-13T12-55-50-046Z_pid12132_e387e0ec.xcresult`), one selected test per device. Native [Air](screenshots/dark-list-navigation/iphone-air/) and [SE](screenshots/dark-list-navigation/iphone-se/) captures show legible labels and the darker textured panel. The final [live Chinese list preview](screenshots/dark-list-navigation/browser-lists.jpg) remains open. Strict swift-format lint passed for the two affected Swift files. No business logic or integrations changed.

## Checkbox proportions after reference review

The user supplied an original iOS 6 screenshot showing a thin check whose long arm rises beyond the square. Replaced the bold SF Symbol with a custom curved Shape using a 1.6-point rounded stroke. The square is now 16 rather than 18 points, with a lighter recessed fill and a 0.75-point border. The mark intentionally extends above and to the right of the square and is not clipped to it. Its shadow is limited to the box rather than thickening the ink. The larger row button's interaction area and completion behavior remain intact; the mark is decorative and does not intercept touches.

Build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T12-01-22-030Z_pid12132_52568ea2.log`). The existing Chinese ordinary/date completion-and-undo, landscape, and large-text UI flow passed once on each device, zero failures: Air/iOS 26.2 (`test_sim_2026-10-13T12-02-06-618Z_pid12132_f005e4e1.xcresult`) and SE/iOS 17.5 (`test_sim_2026-10-13T12-03-21-334Z_pid12132_f9f77fb0.xcresult`). Inspected the actual thinner line, smaller square, and unclipped tip in native [Air](screenshots/checkbox-refinement/iphone-air/) and [SE](screenshots/checkbox-refinement/iphone-se/) captures. Current browser proof is [the live checked row](screenshots/checkbox-refinement/browser-main.jpg). Strict swift-format lint passed. This was a visual refinement; no model or integration logic changed.

## Completed reminders stay in the notebook

The user's iOS 6 reference shows a checked square alongside an item that remains in its list. Previously, the model saved completion correctly, but ordinary list and date-page filters removed completed records immediately, hiding the checkmark. Both filters now retain matching completed items in their existing order. The Completed collection still filters for completed records. The existing checkbox renders the checkmark, and completed titles retain their normal ink without strikethrough, matching the supplied reference. List counters still show unfinished items. No archive migration is required.

Extended existing regressions to check completion and direct undo in an ordinary list, completion and undo of a recurring item on Today, cross-list filtering, completed-collection membership, and checked-row persistence across relaunch and a language change. Recurrence generation/undo, edited-successor preservation, and notification eligibility remain covered by the model tests. Final captures were inspected for actual checkmarks, retained rows, and normal title text in both English and Chinese.

| Device | Scope | Result | Result bundle |
| --- | --- | --- | --- |
| Air / iOS 26.2 | All 11 model tests; English completion/undo/history/delete; Chinese ordinary/date completion and existing layout checks; persisted completion after language change | 14 passed, 0 failed | `test_sim_2026-10-13T11-45-36-040Z_pid12132_1b9731f0.xcresult` |
| SE / iOS 17.5 | English completion/undo/history/delete; Chinese ordinary/date completion and existing layout checks | 2 passed, 0 failed | `test_sim_2026-10-13T11-47-16-259Z_pid12132_cc2e1966.xcresult` |

Build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T11-45-21-137Z_pid12132_5ab33f66.log`). Strict swift-format lint passed for the affected model, row, and test files. Proof: [live browser checkbox tap and retained row](screenshots/completion/browser-completed-in-place.jpg), native [Air](screenshots/completion/iphone-air/) / [SE](screenshots/completion/iphone-se/) captures, including [checked Chinese row](screenshots/completion/iphone-air/zh-completed-in-place.png), [checked English row](screenshots/completion/iphone-air/en-completed-in-place.png), and [persisted checked row](screenshots/completion/iphone-air/zh-persistent-user-text.png). Testing used isolated fixtures and a separate temporary archive. The Air mirror remains live in isolated Chinese demo mode.

## Visual refinement after user review

### Current status-area treatment: body paper and charcoal

The latest review requested the body material above the independent leather navigation panel. A subsequent clarification retained leather behind the bottom safe area and required both notebook margins and horizontal ruling at the top. The root now selects paper for reminders, details, list editors, and accounts, or the list panel's charcoal color for list management. Accounts visibility is owned by the root so entering and returning from that page changes the real system status appearance correctly. Paper pages use dark time/icons; the dark manager uses light time/icons. There is no simulated status bar or device mask.

The status area and paper cards share the same unshaded paper texture, removing the height-dependent gradient that gave them different tones. The reminder notebook's double red margin is aligned with the inset paper below; its fine dotted horizontal ruling also appears in the status area at the same 52-point pitch. Decorative layers do not intercept touches. The top-only extension follows the user's explicit preference; the original leather bottom is preserved as an exception to the shared guide's default top-and-bottom continuity rule. The leather navigation has its own constrained background and fine contact edges.

Final build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T11-37-33-574Z_pid12132_051e598b.log`). Strict swift-format lint passed for the four affected Swift files. Recorded native checks:

| Device | Scope | Result | Result bundle |
| --- | --- | --- | --- |
| Air / iOS 26.2 | Final paper/ruling, Chinese variant, details/accounts and return, landscape, large text | 1 passed, 0 failed | `test_sim_2026-10-13T11-38-12-953Z_pid12132_416b6829.xcresult` |
| SE / iOS 17.5 | Same final flow, compact status area | 1 passed, 0 failed | `test_sim_2026-10-13T11-38-52-143Z_pid12132_39a51574.xcresult` |
| Air / iOS 26.2 | Route-dependent material implementation before the final decorative adjustment; English accounts/create/search/rename/move plus Chinese flow | 2 passed, 0 failed | `test_sim_2026-10-13T11-31-55-063Z_pid12132_14ce2d29.xcresult` |

Current proof: [live reminder notebook](screenshots/body-safe-areas/browser-main.jpg), [live list manager](screenshots/body-safe-areas/browser-lists.jpg), and final native [Air](screenshots/body-safe-areas/iphone-air/) / [SE](screenshots/body-safe-areas/iphone-se/) captures. Inspected actual paper tones, both kinds of ruling, system text contrast, the leather bottom, account return, landscape, and large content sizing. The Air mirror remains live in isolated Chinese demo mode. Screenshots establish implementation and inspection, not user approval.

### Earlier status-area treatment: graphite satin (superseded)

The user requested a smooth top region and then rejected a plain-black trial. The final status area uses a restrained graphite satin gradient (`#383B3D` to approximately `#2B2E30`) and a fine contact shadow above the leather navigation. It contains no leather pattern. The real status bar, Dynamic Island, and device clipping remain system-owned. A noninteractive GeometryReader measures the top safe inset so this decorative surface follows the device and rotation; a zero top inset creates no extra strip. Leather starts below the top safe area and continues behind the home indicator. This explicit reviewed direction takes precedence over the shared guide's default material continuity.

Build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T11-16-04-761Z_pid12132_aebf4f29.log`). The affected Chinese variant/landscape/large-text flow passed separately on Air/iOS 26.2 (`test_sim_2026-10-13T11-17-24-390Z_pid12132_dab38846.xcresult`) and SE/iOS 17.5 (`test_sim_2026-10-13T11-17-48-509Z_pid12132_9a2c49ba.xcresult`), one selected test each with zero failures. It exercises main, details, lists, accounts and return, landscape, and large content sizing. Strict swift-format lint and diff checks passed.

Historical visual proof: [live browser main page](screenshots/satin-status/browser-main.jpg) and native [Air](screenshots/satin-status/iphone-air/) / [SE](screenshots/satin-status/iphone-se/) captures. This satin treatment has been superseded by the body-material extension above; no claim of user acceptance is inferred from screenshots.

### Follow-up: visible leather and full-row list taps

The next review reported that the fine grain disappeared at the browser's ordinary preview size and that list counts/disclosure arrows did not open their lists. The latter came from `listRow` placing those views outside the title Button; Completed and Today already used one full-width Button.

Moved each list's title, whitespace, count, disclosure or edit indicator, and padding into one rectangular button label. Edit-mode deletion is a separate sibling control. The accessibility label remains the list name and the value exposes its active count. Expanded the procedural leather cells from approximately 2.7 to 4 points and strengthened their directional light/shadow relief. The single continuous texture, smooth inset list panel, and icon composition remain in place.

- Air/iOS 26.2: existing search/create/rename/move/account flow passed (`test_sim_2026-10-13T11-03-32-849Z_pid12132_c1c69257.xcresult`). The initial new test incorrectly assumed edit mode survived leaving and returning through the root route; it was corrected to explicitly enter edit mode before checking its delete button.
- Air/iOS 26.2: final regression passed (`test_sim_2026-10-13T11-05-30-369Z_pid12132_3522b1d0.xcresult`). It taps both the count area and far-right disclosure area of all three demo lists in English and a Traditional Chinese preference mapped to Simplified Chinese, then checks rename entry and separate deletion/cancellation.
- SE/iOS 17.5: the same regression and the Chinese/landscape/large-text flow both passed, 2 tests and no failures (`test_sim_2026-10-13T11-07-38-494Z_pid12132_1c212d92.xcresult`).
- Browser pointer clicks on the Shopping list's right-hand count and Create New List's right-hand arrow reached their native destination screens. The creation draft was canceled without saving. The real mirror remained live at its normal 328-point width.
- Build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T11-01-31-573Z_pid12132_003e95f9.log`). Strict swift-format lint and diff whitespace checks passed.

Historical evidence: [browser list and visible leather](screenshots/leather-hit-target/browser-lists.jpg), [count opened Shopping](screenshots/leather-hit-target/browser-right-count-opened.jpg), [right arrow opened New List](screenshots/leather-hit-target/browser-right-new-list-opened.jpg), and native [Air](screenshots/leather-hit-target/iphone-air/) / [SE](screenshots/leather-hit-target/iphone-se/) screenshots. This adds a ninth distinct UI regression test; previous run counts below retain their historical scope.

### Earlier visual revision

The initial visual implementation was rejected for coarse all-over grain, weak list hierarchy, an abrupt status-area transition, and an inaccurate icon. The earlier screenshots below document that implementation and are not evidence of user approval. The current revision follows Apple's [iOS 6 user guide, page 88](https://cdsassets.apple.com/live/6GJYWVAV/user/ma1658_iphone_ios6_user_guide.pdf) and the historical list-manager reference linked in the README.

- Replaced large outlined leather cells with a fine, low-contrast, periodic two-pixel-per-point tile. One root surface owns the grain across the real status area, navigation, and bottom safe area; navigation no longer restarts that texture.
- Rebuilt list management as a smooth recessed charcoal panel with inset borders, separators, a shaded account header, and individually beveled date cells. Chinese day numbers contain no redundant day suffix. The search capsule retains its compact visual size with a 44-point focus target.
- Moved connection instructions, account actions, and Open Settings into an app-owned paper account page. Both languages retain all actions and a tested Back route. The list screen keeps a small Accounts control above its date ribbon.
- Replaced the schematic four-checkbox icon with original imagegen artwork: three large dark checks, three gray bars, double pink margin, rounded paper, and a leather rim. The versioned source and exact built-in-tool prompt are in [artwork](../artwork/README.md). Checked the installed icon on SpringBoard.
- Reworked the paper's subtle fibers, navigation bevels, and small recessed paper add button.

Current captures are in [visual-refinement](screenshots/visual-refinement/): [live main page](screenshots/visual-refinement/browser-main.jpg), [live lists](screenshots/visual-refinement/browser-lists.jpg), and [installed icon](screenshots/visual-refinement/browser-icon.jpg). Native screenshots cover [Air](screenshots/visual-refinement/iphone-air/) and [SE](screenshots/visual-refinement/iphone-se/), including English search/accounts, Simplified Chinese selected from a Traditional Chinese preference, landscape accounts, and large text. These are simulator inspection results; user acceptance remains a separate judgment.

| Device | Affected flows | Result | Result bundle |
| --- | --- | --- | --- |
| Air / iOS 26.2 | Chinese variant, landscape, large text, account Back; English lists/search/rename/move; quick entry/cancel | 3 passed | `test_sim_2026-10-13T10-42-50-549Z_pid12132_9ba9f175.xcresult` |
| SE / iOS 17.5 | Initial compact-device check | Chinese flow passed; search typing failed to obtain keyboard focus | `test_sim_2026-10-13T10-45-02-062Z_pid12132_0b31d1b9.xcresult` |
| SE / iOS 17.5 | Search focus target and transition-settled capture; same two flows | 2 passed, 0 failed | `test_sim_2026-10-13T10-47-15-024Z_pid12132_6353699f.xcresult` |
| Air / iOS 26.2 | Final search target, English accounts/lists/search/rename/move | 1 passed, 0 failed | `test_sim_2026-10-13T10-48-42-245Z_pid12132_308af7f6.xcresult` |

The artwork build/run succeeded without reported warnings or errors (`build_run_sim_2026-10-13T10-41-17-758Z_pid12132_5da480de.log`). The final search revision compiled in the successful test runs above and was relaunched on Air in isolated Chinese demo mode. Browser pointer interaction opened lists, opened and returned from the app, and verified the installed icon through the live mirror. The existing serving terminal and browser tab remain open at `http://localhost:3200/`.

Strict swift-format lint passed for affected Swift files. Both localization tables now contain 92 matching keys and format placeholders, including three account status additions. Asset references and the opaque 1024-by-1024 RGB icon were checked. Localization plist lint, text whitespace checks, and `git diff --check` passed. Existing model/integration behavior was retained; this refinement did not repeat unrelated notification or provider tests.

## Build and scope

- Standalone project: `apps/reminders/RemindersSix.xcodeproj`, shared scheme `RemindersSix`.
- Bundle identifier: `com.yinyueyang.reminderssix`; deployment target iOS 17.0.
- Registered in the collection workspace and root README.
- Initial Air build and launch succeeded with no reported compiler errors or warnings: `build_run_sim_2026-10-13T10-23-03-466Z_pid12132_438b5f3f.log`. Updated visual build and test evidence is recorded above.
- Test data used `--demo`, `--uitesting`, and separate temporary archives. Production reminders and personal system accounts were not modified.

## Recorded test evidence

Tests were run in an initial suite and focused repair/acceptance runs. Counts below describe each recorded run; they are not a claim that every historical result bundle was green.

| Device and runtime | Scope | Result | Result bundle |
| --- | --- | --- | --- |
| iPhone SE, iOS 17.5 | 11 unit tests and 5 primary UI flows | 16 passed, 0 failed, 0 skipped | `test_sim_2026-10-13T10-06-35-103Z_pid12132_f5699f73.xcresult` |
| iPhone SE, iOS 17.5 | Final date-wheel editing, quick-entry cancellation, title paging, drag ordering and swipe deletion | 3 passed, 0 failed, 0 skipped | `test_sim_2026-10-13T10-20-11-128Z_pid12132_c1795902.xcresult` |
| iPhone Air, iOS 26.2 | Completion/undo/delete and final paging/drag/swipe behavior | 2 passed, 0 failed, 0 skipped | `test_sim_2026-10-13T10-18-07-190Z_pid12132_68af5179.xcresult` |
| iPhone Air, iOS 26.2 | List creation, search, rename, moving between lists, cancellation | 1 passed, 0 failed, 0 skipped | `test_sim_2026-10-13T10-04-39-303Z_pid12132_16406d66.xcresult` |

Additional Air evidence: Chinese variant mapping, landscape, large text, persistence and unsupported-language fallback passed in `test_sim_2026-10-13T10-02-21-161Z_pid12132_f9170ea2.xcresult`. Quick-entry draft restoration passed in `test_sim_2026-10-13T10-10-16-884Z_pid12132_ff4deabe.xcresult`. The final date-wheel flow and live London address search with departure selection passed in `test_sim_2026-10-13T10-14-45-529Z_pid12132_37b8f4c2.xcresult`; that run's ordering/deletion failure was subsequently repaired and verified by the green final gesture runs above.

The 11 unit tests cover Weather-compatible language selection, localized placeholders, atomic persistence and user-written text across language changes, recurring completion and undo, preservation of edited successors, month-end/leap-year anchors, search/date/completed filtering, ordering, last-list protection, failed-write rollback, corrupt-file preservation, notification trigger construction and eligibility, and demo isolation.

The eight distinct UI tests cover quick paper-row input and draft restoration; creation/editing/completion/undo/deletion; lists/search/rename/move/cancel; date/repeat/priority/notes/location cancellation; Chinese variants, landscape, large text and Reduce Motion; unsupported-language fallback and persisted relaunch; title paging, actual drag ordering and swipe deletion; and actual MapKit address results plus departure selection.

## Initial visual inspection (superseded)

Saved native screenshots are in [iPhone Air](screenshots/iphone-air/) and [iPhone SE](screenshots/iphone-se/). Representative captures:

- [Chinese main paper list](screenshots/iphone-air/zh-main.png), [details](screenshots/iphone-air/zh-details.png), [list manager](screenshots/iphone-air/zh-lists.png).
- [Quick entry and keyboard](screenshots/iphone-air/en-quick-entry.png), [physical date-wheel framing](screenshots/iphone-air/en-date-wheel.png), [manual ordering](screenshots/iphone-air/en-reordered.png).
- [Live address results](screenshots/iphone-air/en-location-search.png), [departure selection](screenshots/iphone-air/en-departure.png).
- [Compact Chinese list](screenshots/iphone-se/zh-main.png), [landscape](screenshots/iphone-se/zh-landscape.png), [large text](screenshots/iphone-se/zh-large-text.png).

Inspected the leather continuation behind the real status bar and bottom edge, historical inset paper panel, red double margin extending through blank paper, square checkboxes, multiline reminders and notes, embossed controls, settings groups, and non-interactive date-wheel metal framing, selection band and column separators. Presented details and management remain full-screen app-owned surfaces. Screenshot capture waits for the short page transition to finish.

## Browser mirror

The mirror is scoped to Air simulator `E092AACD-B2F6-493E-8BAE-E9D7A704ABD8` at `http://localhost:3200/`. The Codex browser reported `live` and displayed the app's actual framebuffer. A browser pointer click on the menu opened native list management. The serving terminal is intentionally retained for the user's preview.

The mirror's canvas is visual evidence, while native XCTest provides semantic interaction evidence. XcodeBuildMCP's runtime accessibility snapshot returned no useful native targets on this host; that limitation did not prevent XCTest from exercising real controls. No claim is made that browser DOM selectors can target SwiftUI controls.

## Initial static checks

- Strict recursive `xcrun swift-format lint` passed for app, unit tests and UI tests.
- Info.plist and both Localizable.strings files passed `plutil -lint`.
- Both localization tables contain 89 identical keys with matching format placeholders; literal localization callsites are covered.
- Asset catalog JSON parsed successfully and original icon/material assets are included.
- `git diff --check` passed.

## Integration boundaries

Date/location notification requests, completion eligibility, localized content, and arrival/departure region configuration were tested without asking for production notification permission. Actual notification delivery, denied-permission recovery on a physical phone, and crossing a geofence were not field-tested. Location delivery depends on system permissions, region heuristics and hardware.

Optional EventKit account read/write integration compiled successfully. Personal iCloud or other provider accounts were not connected during automated testing, so cross-device synchronization, provider-specific restrictions and account CRUD are not claimed as live-verified. Advanced recurrence and unedited system alarm/priority metadata are preserved; unsupported advanced changes remain in Apple's Reminders. System keyboard, selection, dialogs, banners and the underlying native date-wheel renderer retain current OS behavior within the app's classic framing.

No physical-device installation, Git commit, or push was requested or performed.
