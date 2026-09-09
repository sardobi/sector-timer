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
