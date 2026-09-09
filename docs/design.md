# Sector Timer: design and development

[App overview](../README.md) | [Hardware testing](testing.md)

This guide covers interaction design, persistence, background alarms, diagnostics,
and development. Source paths and commands below are relative to the repository
root, not this documentation directory.

- [Controls](#controls)
- [Platform behavior and compatibility](#platform-behavior-and-compatibility)
- [Alert settings and warnings](#alert-settings-and-warnings)
- [Background behavior](#background-behavior)
- [Development and appearance settings](#development)
- [Install on your watch](#install-on-your-watch)
- [Automated tests and simulator](#tests)
- [Source structure](#structure)

## Controls

- Grab on or near the small white endpoint handle on the outer dial and drag
  anticlockwise. On an empty timer the handle is at twelve o'clock.
  The selection snaps to whole minutes. Keep dragging past twelve to select a
  second and third revolution, up to **180 minutes**. Drag clockwise to reduce
  the selection.
- Release to start immediately. A zero-minute selection cancels instead.
- At or below 60 minutes, the red sector shows the remainder on a fixed
  60-minute scale: 15 minutes fills the upper-left quarter of the dial.
- Above 60 minutes, the outer red circle stays full. A **smaller purple sector**
  shows the excess above one hour. Above 120 minutes, red and purple stay full
  and an **even smaller blue sector** shows the excess above two hours.
  At 150 minutes the blue sector is a half-circle; at 180 minutes all three
  circles are full. Blue shrinks first, then purple, then red.
- There is **no text or numeric countdown on the dial**. A small white centre
  hub and the minute pips remain visible during countdown. The large pause/bell
  icons replace the hub while paused/finished. The empty dial shows a curved
  anticlockwise arrow as a drag hint. The endpoint handle remains visible,
  including while running or paused. For multi-hour timers it follows the
  active purple/blue sector's angle, projected onto the outer dial.
- Tap the centre or press the top/select button to pause or resume. A white
  **pause icon** stays visible for the entire pause, disappearing on resume.
- Grab the endpoint again to adjust the current remaining time, including while paused or
  running. The starting touch does not change the selection or drop completed
  revolutions: dragging a 90-minute timer further starts at 90, not 30 minutes.
  Anticlockwise movement adds time; clockwise movement subtracts it. The previous
  timer remains committed until the adjusted selection is released.
- Press **Back once to leave the app**, without cancelling a running or paused
  timer. Reopening restores the countdown, accounting for time spent away.
- **Hold Back** to open the menu, then tap **Cancel timer** to stop and clear
  it. Releasing a zero-minute dial selection also cancels.
- The same menu has **Alarm log** for investigating missed alerts. It retains
  recent alarm events across app launches; swipe through them or press Select
  for older entries. Tap right for older, left for newer. Back returns.
- A small amber crossed-out bell near the bottom of the dial warns about DND
  or disabled watch vibration. Tap it for the reason and how to change the
  setting. **Hold Back > Alert settings** opens the same dialog at any time.
  When an activity is open and no warning is detected, a neutral grey activity
  symbol occupies the same spot. Tap it for the During Activity notification
  reminder. It remains while the activity is paused and disappears when it ends.
  Tap, swipe or Select switches between alert and activity settings; Back returns
  without changing the timer. Amber warnings take priority over the neutral symbol.
  Both symbols have a generous invisible touch target; the centre button and a
  20-pixel band inside the rim remain reserved for the timer's existing controls.
- At zero, the screen shows a **bell icon** and gives a three-pulse vibration.
  Tap the centre or press Select to dismiss. If the app is closed, a system
  notification announces completion instead; opening it returns to the timer.

Crossing twelve o'clock adds or subtracts time without resetting the selection.
The prototype clamps at zero and 180 minutes; it does not silently wrap.
Starts within 18 degrees either side of the endpoint are accepted in the dial's
outer touch area. Grabbing just right of twelve on an empty/finished dial starts
at zero, not 59 minutes. A swipe starting elsewhere is ignored for its entire
gesture, even if it subsequently crosses the handle. There is no separate tap
required: press near the handle, drag, and release. Once grabbed, movement is
unrestricted around the dial and relative to the remaining duration.
Unmoved selections retain their exact
remainder; movement snaps to whole minutes. Other taps on the outer dial do nothing.
On the simulator, use a mouse press, move, and release.

## Platform behavior and compatibility

**Background notifications are not equivalent to native watch alarms.** The app
now saves its countdown and schedules a background event, but notification
vibration, visibility under sleep/Do Not Disturb, and scheduling latency are
controlled by Garmin. Do not rely on this prototype for safety-critical alarms.

The app respects AMOLED sleep/brightness settings and never forces the screen
to stay on. Display sleep is distinct from leaving the app. The countdown uses a
saved absolute deadline rather than counting UI callbacks, so time passes even
when no app code is running. One-minute and longer background timers have
delivered notifications on the watch with GGlance open; see the
[hardware observations and remaining tests](testing.md). Battery usage and
display-sleep behaviour still need broader assessment. The custom foreground
vibration is a finite pattern, not an indefinitely repeating alarm.

No phone companion, network access, GPS, or activity recording is needed.
The app requires the **Background** and **Notifications** permissions.
The only build target is `vivoactive5` (390 x 390 pixels), with **Connect IQ API
5.1.0 or later** firmware for the Notifications API. Update the watch firmware
if the new PRG is rejected; the installed SDK profile alone does not establish
the firmware on the physical watch.

## Alert settings and warnings

`System.getDeviceSettings()` exposes `doNotDisturb` and `vibrateOn`; both are
guarded by `has` checks. A missing value is unknown, not a confirmed safe setting.
The indicator appears when DND is explicitly on, vibration is explicitly off, or
both. It does not pause the timer, override watch preferences or skip notification
attempts. Disabled vibration does not necessarily prevent a visible banner.

Settings are sampled on opening/returning to the dial and at most once per
second while it is visible, including when idle or paused. Device queries are
suspended while dragging and resume after release; drag redraws never force
settings polling. The dialog rereads settings when drawn. Changed readings
are logged, not every poll; background notification attempts also log the current
DND/vibration values. Foreground vibration behavior is otherwise unchanged.

The public API does **not** expose the watch's General Use / During Activity
app-notification preferences. No icon therefore means only that no supported
warning condition was detected, not that delivery is guaranteed. The dialog's
second page reminds users to allow app notifications during activities.
The user confirmed background notifications
during a native activity after enabling app notifications in During Activity.

`TimerEnvironment.readActivityState()` reads `Activity.getActivityInfo().timerState`
in the foreground. The user confirmed that the vivoactive 5 reports a native
recording as `3` while running, `1` while paused, and `0` before/after the activity.
States `1`, `2` (Auto-Pause), and `3` show a neutral grey activity symbol unless
an amber warning takes priority. Zero, unavailable, or unrecognized states do not.
An activity-state change never becomes an alert-disabled warning.

The neutral symbol opens the activity page directly; amber warnings open their
reason first, with the activity note on the next page. Activity settings explain
that timer alerts depend on allowing During Activity app notifications, a
preference the app cannot read. User-facing messages give plain-language guidance,
without raw state numbers or technical delivery disclaimers. Activity status is
shown as, for example, "Activity in progress" or "Activity paused"; raw values
remain in the `activityProbe` diagnostics. No activity recording, sensor access, or new permissions are
requested. See the [hardware activity checks](testing.md#native-activity-detection).

Sources: [Device settings](https://developer.garmin.com/connect-iq/api-docs/Toybox/System/DeviceSettings.html),
[Activity states](https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity.html).

## Background behavior

### Keeping time after exit

The app persists a versioned record containing state, duration, absolute expiry
time, and a generation number using
[`Application.Storage`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html).
Changes are saved when starting, pausing, resuming, replacing, cancelling, or
claiming completion, rather than depending solely on `onStop()`. No continuously
running background countdown is necessary.

Both the foreground display and background expiry use `deadline - Time.now()`.
The `Time.Moment` scheduled with Garmin uses that same epoch clock. This gives
one-second resolution and recovers independently of process uptime after an app
restart. A paused timer stores its remaining duration, so time away does not
deplete it. An interrupted drag does not save an unreleased replacement.

This version deliberately uses one consistent default clock, not a mixture of
RTC and user-clock timestamps. **Changing the watch's clock can shorten or
lengthen a running timer.** A backward change cannot display more than the saved
duration, but can delay expiry. See Garmin's
[`Time`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time.html) API.
Clock adjustment and reboot behavior still need hardware assessment.

### Alerting without reopening the app

The app schedules a one-shot
[`Background.registerForTemporalEvent(Time.Moment)`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function)
at the deadline on start/resume and reconciles the registration on app launch.
A `System.ServiceDelegate.onTemporalEvent()` callback reads the latest saved
timer, confirms it is still running and due, and posts a
[`Notifications.showNotification()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html#showNotification-instance_function).
The user can see that system notification without first reopening this app.

Garmin's [notification guide](https://developer.garmin.com/connect-iq/core-topics/notifications/)
documents use from background services. The notification uses the app icon and
the platform's default launch/dismiss actions, with the timer generation as its
associated data. An older notification cannot cancel or resume a newer timer;
opening a notification always displays the current saved state.

Background expiry now posts the notification **before** saving FINISHED and
removing the event. Previously, a service interruption or thrown notification
call after saving completion could permanently suppress recovery. A failed
notification now leaves the timer overdue, allowing recovery on reopening or a
later callback. The foreground and background still share the generation-aware
completion helper, so a delayed notification cannot finish a replacement timer.

Back/shutdown no longer claims an expiry and starts a vibration just before the
foreground process exits. It leaves the saved timer and event for the background
service. Reopening a completed timer shows the bell without another vibration;
opening an overdue timer recovers completion in the foreground.

There is no transactional exactly-once guarantee: a service interruption after
posting but before saving completion can cause a duplicate on recovery. Storage
has no documented compare-and-set operation or callback ordering guarantee.
These changes close code-level failure windows; they do not establish the cause
of every missed alert observed on hardware or guarantee delivery.

[`Attention.vibrate()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html)
and `Timer.Timer` are not available in background context. The custom three-pulse
vibration therefore stays in the foreground; background alert presentation is
controlled by the notification system. The app does not also issue
`Background.requestApplicationWake()`, avoiding duplicate launch prompts.

### Scheduling restrictions and reliability

The five-minute rule is **not a blanket ban on timers shorter than five minutes**.
Garmin specifies that temporal events cannot occur less than five minutes after
the **last temporal event**. A repeating `Time.Duration` must be at least five
minutes; a one-shot `Time.Moment` is different. For watch apps, the restriction
is cleared on application startup if the event was specified using a Moment.
The docs do not require this call to occur inside a particular startup method.
Short first timers and consecutive short timers must be assessed separately.

Only one temporal event can be registered per app; registering another replaces
it. Pause/cancel invalidate the saved running state and delete the event.
Resume/replacement update the saved deadline and registration. The app reads
back the registered `Time.Moment` and requires an exact match. If Garmin rejects
a registration with `InvalidBackgroundTimeException`, or readback differs,
the timer is saved as paused and an explicit **Alarm not scheduled / Timer paused**
notice is shown.
Dismiss the notice, then retry resuming once the restriction clears (or reopen the
app for the documented Moment/startup reset). The app never quietly substitutes
a different alarm time. Invalid stored records and unexpected storage/platform
errors propagate instead of being silently treated as an empty or armed timer.

An early callback checks that the saved future timer still has its registration;
if the event has been consumed or lost, it attempts to rearm the original
deadline. A rejected rearm pauses the timer and posts an **Alarm unavailable**
notification rather than silently leaving an unarmed running timer.

### Diagnosing a missed alert on the watch

Immediately after a miss, reopen the app and choose **hold Back > Alarm log**.
Photograph the relevant entries before starting lots of new timers. The log is
bounded to the latest 20 events, newest displayed first; each entry includes Unix
seconds, and events include the timer generation (`g`), state and deadline (`due`).
State numbers are 0 idle, 2 running, 3 paused and 4 finished. No credentials,
location or personal fitness data are recorded, and nothing is uploaded.

| Log event | Meaning |
| --- | --- |
| `arm ... readback=...` | Scheduling accepted and the registered deadline read back; both numbers should match |
| `foreground stopped ... registered=...` | Saved timer/event when leaving the app |
| `fired ... due=...` | Background callback actually entered; compare the leading timestamp to `due` for lateness |
| `skipped early` / `skipped not due` | Callback did not represent a currently due running timer |
| `notify begin` | Notification API about to be called |
| `notify returned` | API call returned, **not** confirmation of display, vibration or acknowledgement |
| `foreground vibrate returned` | Foreground vibration API returned |
| `arm rejected` / `early rearm failed` | Scheduling failure rather than an apparently successful alarm |

An `arm`/exit record with no subsequent `fired` suggests the callback was not
delivered, provided the relevant entries are still retained. `notify begin`
without `notify returned` points to interruption or an API error. `notify returned`
without a perceived alert points instead toward notification presentation/device
settings, not necessarily failed scheduling. Also record watch firmware, timer
duration, whether another activity was running, DND/sleep settings, and whether
the watch rebooted or its time changed.

The log survives app launches and is updated only on lifecycle/alarm operations,
not countdown ticks. It is a diagnostic aid, not an audit trail: rapid events
roll older entries out, and shared-storage writes are not transactional.

### Platform limits

Background services can run during an activity, but have a small memory budget
(64 KiB on this profile) and are terminated after 30 seconds if they do not exit.
That **30 seconds is an execution limit, not a promised alarm-delivery tolerance**.
Keep the service short and call `Background.exit()` after its work. See Garmin's
[background guide](https://developer.garmin.com/connect-iq/core-topics/backgrounding/)
and [`AppBase.getServiceDelegate()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#getServiceDelegate-instance_function).

The documented APIs do not promise exact alarm latency, custom vibration from
background, or a DND/sleep override. `showNotification()` has no vibration option.
Whether it vibrates or wakes the screen under those settings needs measurement;
do not assume CIQ notifications behave identically to phone notifications.
The documentation consulted also does not establish whether temporal registration
survives a reboot. The app reconciles it on startup, but reboot-without-reopening
still needs a separate hardware assessment. No app can alert while the watch is
powered off.

The [hardware test checklist](testing.md) distinguishes successful observations
from remaining lifecycle and device-setting scenarios. An unconditional
native-alarm guarantee is not established by these APIs.

## Development

Install Connect IQ SDK 9.2.0 (or a compatible newer SDK), its vivoactive 5 device
profile, Java 11+, and Garmin's Monkey C extension for VS Code. The prototype was
built with Microsoft OpenJDK 21. Use your own developer signing key; never commit
it. The build script uses the active SDK selected in SDK Manager.

From PowerShell in the repository:

```powershell
.\tools\build.ps1 -DeveloperKey D:\developer_key
.\tools\build.ps1 -Mode Test -DeveloperKey D:\developer_key
.\tools\build.ps1 -Mode Run -DeveloperKey D:\developer_key
```

Alternatively set `CIQ_DEVELOPER_KEY` to your key's path. If needed, pass
`-JavaHome 'C:\Program Files\Microsoft\your-jdk-folder'`. The script also reads
the machine-level `JAVA_HOME`, so it works from a terminal opened before Java
was installed.

`Build` creates the signed release **`bin\SectorTimer.prg`**.
`Test` compiles and runs Monkey C's native Run No Evil tests on the vivoactive 5
simulator. `Run` builds a debug app and leaves it running in the simulator until
you exit it. Simulator logs and all generated files are ignored by Git.
SDK 9.2.0 has a runner exit-code bug: it can return 1 despite reporting every
test as passed. The script warns about this specific case and accepts it only
for SDK 9.2.0 with an explicit non-empty, zero-failure test summary.

In VS Code, open this folder and use **Run Build Task** or **Run timer tests**.
These tasks read the existing `monkeyC.developerKeyPath` user setting.
F5 uses the Monkey C debugger. No private key path is stored in this repository.

### Tuning the appearance and notification

Edit the constants at the top of `source\TimerView.mc`:

```monkeyc
const STATUS_ICON_HEIGHT = 144;
const PAUSE_BACKDROP_PADDING = 16;
const HUB_RADIUS = 12;
const SECOND_HOUR_COLOR = 0xA050E8;
const THIRD_HOUR_COLOR = 0x3088FF;
const SECOND_HOUR_RADIUS_SCALE = 0.67;
const THIRD_HOUR_RADIUS_SCALE = 0.40;
const IDLE_ARROW_RADIUS_SCALE = 0.80;
const ALERT_ICON_HEIGHT = 24;
const ALERT_TOUCH_RADIUS = 44;
const ALERT_RIM_MARGIN = 20;
const ALERT_OFFSET_SCALE = 0.70;
```

`STATUS_ICON_HEIGHT` is the shared height in pixels of the white pause and bell
glyphs. Both have the same nominal width (76% of their height), and all their
parts scale together. The default is about 37% of the watch's 390-pixel screen
height. For example, use `120` for smaller icons or `168` for larger ones.
`PAUSE_BACKDROP_PADDING` controls the extra space around the pause icon's
dark circular background; it does not change either glyph's size.
The other constants control the white hub size, the purple/blue layers' colors
and radii, and the idle arrow's distance from the centre.
The `ALERT_*` constants control both environment glyphs' height, their touch radius,
the protected inner rim band, and their vertical offset below the centre as a
fraction of the dial radius. The touch target excludes the centre button and
the protected rim band, so enlarging it does not steal pause or endpoint gestures.
Apart from the touch radius and rim margin, these are drawing settings only; the
centre tap target and outer drag area remain unchanged. Rebuild and copy the new
`bin\SectorTimer.prg` to the watch
after editing; an already-installed app will not pick up source changes.

To make grabbing the endpoint more or less forgiving, edit
`Dial.HANDLE_TOLERANCE_DEGREES` in `source\TimerModel.mc` (default `18.0`,
on each side). This affects only where a drag may start, not its movement or
minute rounding.

The background notification is customisable: edit `TimerFinished` (subtitle)
and `OpenTimer` (body) in `resources\strings\strings.xml`. The defaults are
**Time's up!** and **Your countdown has finished.** Its title is `AppName`;
the default icon is the launcher icon. `TimerPlatform.notifyExpired()` is the
place to add a different icon or notification actions. Keep notification strings
in background scope. Garmin controls layout, display duration, vibration, and
the default launch/dismiss controls; those are not custom alarm controls.

### Back navigation

The vivoactive 5 manual describes Back as returning to the previous screen,
except during an activity. For this single-screen app, the intended
background-enabled behavior is to leave the app without cancelling the timer.
Cancellation should be a separate, deliberate action rather than a side effect
of navigating away. See Garmin's
[device overview](https://www8.garmin.com/manuals/webhelp/GUID-5D183A14-BB43-4A9B-B441-5F824214CE40/EN-US/GUID-E8D90973-F651-4F66-9A08-A8858C2CB98E.html).

Back now exits immediately. Hold Back for the cancellation menu. Leaving while
setting the dial abandons that unreleased selection, preserving any previously
committed timer.

## Install on your watch

1. Build the release PRG with the command above.
2. Connect the vivoactive 5 to the PC using a USB data cable. Close Garmin Express
   if it interferes with file access.
3. In File Explorer, open the watch's storage and its **`GARMIN\APPS`** directory
   (sometimes under **Internal Storage**).
4. Copy **`bin\SectorTimer.prg`** into that directory. Do not copy the debug XML,
   test PRG, or signing key. When updating an existing sideload, overwrite its
   existing PRG filename (including `VisualTimer.prg` for earlier builds) rather
   than leaving both files on the watch. The application ID and storage keys
   are unchanged by the rename.
5. Safely disconnect the watch, then find **Sector Timer** in its apps list.
   If needed, add it through the watch's app list customization.

Sideloading is for personal development and does not require Store publication.
For public distribution, use **Monkey C: Export Project** to produce an `.iq`
package and submit that package to the Connect IQ Store.

## Tests

`tests\TimerTests.mc` covers cardinal touch angles, duration rounding and limits,
release-to-start, delayed callbacks, fixed-scale sector shrinkage, zero expiry,
one-shot completion, pause/resume, cancellation, replacement, the twelve-o'clock
boundary, multiple anticlockwise revolutions, the 180-minute limit, nested-sector
angles and transitions through 60/120 minutes, both uptime rollover boundaries,
and single-tap pause/resume and dismissal. Additional native tests cover saved
record validation, restart recovery, background completion, stale callbacks,
pause/cancel/replacement, registration failure, and interrupted drags.
`DialRefinementTests.mc` covers relative adjustment from the current remainder,
near-endpoint starting touch positions, unchanged drags, hour-boundary crossings,
three-layer countdowns and recovery of timers longer than two hours.
`EndpointDragTests.mc` covers the tolerance on both sides of twelve, rejected
starts, untouched background registration, multi-hour handles, radial hit testing,
and unrestricted movement after grabbing the endpoint.
`DialGeometryTests.mc` covers shared rounded coordinates for the handle and sector
edge, cardinal positions, and handle placement through hour boundaries.
`AlertSettingsTests.mc` covers known/unknown warning states, reason text selection,
change-only logging, activity-state transitions, warning priority, touch-target
separation, visible settings refresh, and unchanged timer scheduling under warnings
or activity changes. Drag regressions ensure repeated redraws do not poll device
settings, including drags lasting several seconds.
`BackgroundReliabilityTests.mc` covers notification exceptions, replacement
during notification, early-callback rearming, exact registration readback,
bounded log persistence, and leaving at the deadline without consuming the alarm.
Tests run inside Garmin's simulator and are excluded from the release build.

The SDK 9.2.0 simulator exercises real temporal callbacks and notification API
calls after Back exits the foreground app. `Simulation > Background Events`
can also force a callback even when no event was registered, making it useful
for early/stale-event and registration-failure scenarios, but not by itself proof
that a deadline was armed. Runtime logs distinguish registration, foreground
alarms, temporal callbacks and posted expiry notifications.

For a clean process-restart scenario, use `File > Kill Device` before running
the PRG again; this preserves the timer's saved data. Do not use the simulator's
clear/reset-data commands when checking persistence. A long button press needs a
real held mouse button in the simulator; synthesized short clicks are not a
substitute. In the native cancellation menu, tap the item's label.

See [Hardware testing](testing.md) for the prioritized watch checklist and log
collection procedure.

## Structure

`source\TimerModel.mc` owns dial math and the clock-injected state machine.
`TimerDelegate.mc` maps input, and `TimerView.mc` draws and delivers the foreground
alarm. `TimerSession.mc` coordinates user actions, persistence and scheduling.
`TimerRecord.mc` defines the shared saved state; `TimerPlatform.mc` provides the
Garmin API adapter and completion helper; `TimerService.mc` is the short-lived
background entry point.
`TimerDiagnostics.mc` retains the bounded alarm log; `TimerDiagnosticsView.mc`
displays it from the watch's menu.
`TimerAlertSettings.mc` reads supported device settings; `TimerEnvironment.mc`
samples foreground settings and the activity state.
`TimerAlertView.mc` explains warning reasons and unreadable activity preferences.
The timer callback runs four times per second, but the display is refreshed only
once per elapsed second or when the interaction state changes.
