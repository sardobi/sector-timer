# Hardware testing

[App overview](../README.md) | [Design and development](design.md)

## Observed on vivoactive 5

On 9 September 2026, the user confirmed that both a one-minute timer and a longer
timer displayed their background notification while GGlance was open. The longer
test's duration was not recorded; this is not a claim that a full three-hour run
has been exercised. The endpoint-drag interaction and handle alignment have also
been confirmed by the user.

During an earlier overnight miss, the captured log showed the background
callback and notification API returning exactly at the scheduled 00:03:42
deadline (UTC+01:00). Reopening at 00:08:10 restored FINISHED. Sleep or Do Not
Disturb is a plausible explanation for the unseen notification, not a confirmed
cause. A foreground GGlance session does not categorically prevent delivery.

These results support normal background operation. The remaining tests target
state changes and device settings rather than repeating the same scenario.

Further user reports on 9 September:

- Three one-minute timers in quick succession each notified while backgrounded.
- A paused one-minute timer remained paused after three minutes away, with no
  notification. Resume after that pause was not explicitly reported.
- Extending a nearly expired timer to two minutes resulted in an alert about
  two minutes later. Cancellation near expiry is a separate remaining case.
- Native activities initially suppressed notifications even after returning to
  the watch face. Enabling app notifications in **During Activity** allowed Sector
  Timer to notify successfully during the activity. This is a watch-setting
  dependency, not evidence that native activities inherently prevent alerts.
- The watch did not sleep with the native activity screen foregrounded, so that
  exact screen-sleep combination has not been exercised.
- Native activity detection reported `0` with no activity, `3` while recording,
  `1` while paused, and returned to `0` after the activity ended. Auto-Pause (`2`)
  has not been separately confirmed on hardware.

## Highest-value checks before release

| Scenario | Procedure | Expected result |
| --- | --- | --- |
| Repeated short timers | Run three one-minute timers, reopening after each expiry and leaving again | Each alerts once, or a scheduling rejection is explicitly reported; never silently unarmed |
| Pause across exit | Pause partway through, leave longer than the original remainder, reopen and resume | No alert while paused; the saved remainder resumes correctly |
| Cancel or adjust near expiry | Shortly before expiry, cancel in one run and extend in another, then leave | No stale alert for a cancelled/replaced deadline; the extended timer alerts at its new deadline |
| Notification reopen | Open a completion notification, then leave and reopen again | Finished state is retained without a duplicate foreground vibration |
| Display sleep and another activity | Allow the screen to sleep, both in Sector Timer and while a built-in activity is recording | Countdown stays accurate; with notification-suppressing settings off, expiry alerts without wrist interaction |
| Sleep / Do Not Disturb | Compare the same short timer with each setting off and on; record automatic sleep schedules too | Establish which settings suppress the banner, vibration, or both; do not assume an override |

Use a separate clock to note expected and actual expiry. For each run, record
watch firmware, duration, foreground app/activity, sleep/DND state, whether the
screen was asleep, and whether a banner and vibration occurred. Only mark a row
as passed after that scenario has actually been exercised.

## Longer and recovery scenarios

- Run a 150-minute timer through the blue-to-purple and purple-to-red transitions,
  and exercise the 180-minute maximum. Adjusting from 90 or 150 minutes must
  preserve full hours; clockwise motion reduces the existing remainder.
- Reboot during a running timer without reopening Sector Timer. Record whether
  the background alert survives. Then reopen: the deadline should recover, or an
  overdue timer should finish. Registration survival across reboot is not yet
  established; the watch cannot alert while powered off.
- Assess manual clock changes separately if this use case matters. The current
  implementation uses `Time.now()`, so changing the clock can shift expiry; it
  is not an elapsed-time guarantee across clock adjustments.
- Once packaged for the store, repeat a short background timer and pause/resume
  using the store-installed app. Keep the application ID and signing key stable.

## Settings-warning checks

With no activity open, toggle DND explicitly with vibration enabled: the amber crossed-out bell should
appear on the dial. Tap it to see the DND explanation, then press Back. The timer
must keep counting down throughout. Turn DND off and the symbol should disappear.
Repeat with vibration off, then with DND on and vibration off, to check the distinct
explanations. Do this while idle, running and paused, and after leaving/reopening.
Tap slightly beside the symbol rather than precisely on it: the expanded target
should open its explanation. Centre taps must still pause/resume, and a handle
near six o'clock must remain draggable from the rim.

Changing During Activity app notifications alone cannot trigger an automatic
warning, because that preference is not exposed by the API. The dialog must not
claim notifications are guaranteed when the bell is absent.

## Native-activity detection

Install the new build while preserving the existing PRG filename and log setup.
Disconnect USB before testing. No activity permission or recording is created by
the activity-state reader.

1. With no native activity open, open Sector Timer and choose **hold Back >
   Alert settings**. Tap once for **Activity alerts**. Record the
   activity status shown in words.
2. Leave Sector Timer and start a built-in activity recording. Return to the watch
   face without stopping the recording, reopen Sector Timer, and record the same
   status again. With DND off and vibration on, a neutral grey activity symbol
   should appear. Tapping it should open the activity explanation directly,
   without pausing the countdown.
3. If practical, repeat with the native activity timer stopped/paused but not yet
   saved, then after saving or discarding it. Auto-Pause may produce a different
   state from manually stopping the timer. The symbol should remain while paused
   and disappear after the activity ends.
4. Record the native activity name and watch firmware. Reconnect and collect the
   app text log; `settings ... activityProbe=...` entries preserve changes and
   an initial reading for each app launch.

Also enable DND or disable vibration during an open activity: the amber bell
should replace the grey symbol and open the warning reason first. Tap to reach
the activity page. Clearing the warning should restore the neutral symbol if the
activity is still open. Exercise this with an idle, running and paused countdown.

The API defines `0` as no active recording, `1` as recording with timer stopped,
`2` as Auto-Pause, and `3` as recording with timer running. Unavailable/unrecognized
states show no activity symbol; the dialog gives general activity guidance.
Raw state numbers are kept in diagnostics rather than user-facing messages.
The user confirmed the native recording context on this vivoactive 5; other
devices or firmware should repeat these comparisons. Activity detection does
not reveal whether During Activity notifications are allowed and must never
claim the alarm is disabled on that basis.

## Collecting evidence

The on-watch **hold Back > Alarm log** retains the latest 20 events. Capture it
soon after a miss, before many restarts or timer changes replace older entries.
The [design guide](design.md#diagnosing-a-missed-alert-on-the-watch) explains each
event. A `notify returned` entry confirms the API returned, not that a notification
was displayed or perceived. The phone-notification glance is not a verified inbox
for these on-watch app notifications.

For persistent text capture:

1. Connect the watch by USB and open its storage in File Explorer.
2. In `GARMIN\APPS\LOGS`, create an empty `<installed-basename>.TXT` matching the
   app's installed PRG filename, without overwriting an existing log. Earlier
   sideloads use `VisualTimer.TXT`; a display-name change alone does not change
   this basename. If extensions are hidden, avoid accidentally creating `.TXT.txt`.
3. Disconnect and reproduce the behavior; USB is for file transfer, not a live
   debugger. Confirm that the text log receives output before relying on it.
4. Reconnect and copy the app's `.TXT` and matching `.BAK`, plus `CIQ_LOG.YAML` if
   present, into a dated folder under `bin\watch-logs`. This location is ignored
   by Git. Leave originals intact, and avoid publishing unrelated crash entries.

On Windows, the watch may be an MTP device rather than a drive letter; Explorer
can copy its files to a normal local directory. Text capture starts only after
the log file is created; it does not export older on-watch Alarm log entries.
Garmin rotates text logs at roughly 5 KB, so collect both the current file and
its backup promptly.

## Simulator coverage

The native test suite covers dial geometry and gesture rules, timing, saved-state
recovery, notification failure ordering, registration rejection and readback, and
bounded diagnostics. See [Tests](design.md#tests) for the suite breakdown and
[Development](design.md#development) for commands.

Simulator success does not establish physical-watch notification presentation,
vibration, firmware behavior, or battery impact.
