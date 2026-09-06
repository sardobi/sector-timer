# Visual Timer

A standalone Garmin Connect IQ timer prototype for the **vivoactive 5**.
An original visual countdown implementation; not affiliated with Time Timer.

## Controls

- Drag the outer dial anticlockwise from twelve o'clock, or start at any position.
  The selection snaps to whole minutes. Keep dragging past twelve to select a
  second revolution, up to **120 minutes**. Drag clockwise to reduce the selection.
- Release to start immediately. A zero-minute selection cancels instead.
- At or below 60 minutes, the red sector shows the remainder on a fixed
  60-minute scale: 15 minutes fills the upper-left quarter of the dial.
- Above 60 minutes, the outer red circle stays full. A **smaller black sector**
  inside it shows the excess time on the same scale: at 90 minutes the black
  sector is a half-circle; at 120 minutes it is a full inner circle. The black
  sector shrinks first, disappears at 60 minutes, then the red sector shrinks.
- There is **no on-screen text or numeric countdown**. Running shows only the
  sectors against the dial face. Unnumbered minute ticks and a small selection
  marker help when dragging; they disappear when the countdown starts.
- Tap the centre or press the top/select button to pause or resume. A white
  **pause icon** stays visible for the entire pause, disappearing on resume.
- Drag again to replace the current timer, including while paused or running.
- Press Back once to reset/cancel. Press Back on the empty dial to exit.
- At zero, the screen shows a **bell icon** and gives a three-pulse vibration.
  Tap the centre or press Select/Back to dismiss.

Crossing twelve o'clock adds or subtracts time without resetting the selection.
The prototype clamps at zero and 120 minutes; it does not silently wrap.
Starting within half a minute to the right of twelve is treated as starting at
zero, so a slightly imprecise initial touch still permits an anticlockwise drag.
Only a drag that starts in the dial's outer area sets the timer; each new drag
starts a replacement selection in the first revolution. Taps on the outer dial
do nothing. On the simulator, use a mouse press, move, and release.

## Prototype limitations

**Keep the app open for the alarm.** This version does not schedule background
alarms or save a countdown when the app exits or the watch restarts. Back resets
before exiting so a running timer is not inadvertently abandoned by one press.
It is not a replacement for the watch's native timer if you need an alarm while
using another app or recording an activity.

The app respects AMOLED sleep/brightness settings and never forces the screen
to stay on. Display sleep is distinct from leaving the app. The countdown uses
the watch's monotonic uptime clock rather than counting UI callbacks, and catches
up if callbacks are delayed. Battery usage, touch feel, display-sleep behaviour
and physical vibration still require testing on the watch. Vibration is a finite
pattern, not an indefinitely repeating alarm.

No phone companion, network access, GPS, activity recording, or permissions are
needed. The only build target is `vivoactive5` (390 x 390 pixels). The minimum API
is 3.3.0 for drag input; the SDK's device profile controls target compatibility.

## Background behavior: research, not implemented

Garmin provides a feasible background design, but a system notification is not
the same thing as an unconditional native timer alarm. The current PRG still
has the foreground-only limitations above.

### Keeping time after exit

Persist the timer's absolute expiry time and running/paused state using
[`Application.Storage`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html).
On launch or a background callback, calculate `remaining = deadline - now`.
No continuously running background countdown is necessary. Save changes when
starting, pausing, resuming, replacing, or cancelling, rather than depending
solely on `onStop()`.

`System.getTimer()` is device uptime: the clock itself does not reset merely
because the app exits, but this app's in-memory start/duration variables are
lost. Uptime alone cannot recover safely across device reboots.
[`Time`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time.html) provides
epoch timestamps. Its default clock may be user-adjusted; `CURRENT_TIME_RTC`
ignores manual settings but can be updated by trusted sources and can throw
`RealTimeClockNotValidException` if not valid. A persistent implementation must
choose a consistent clock basis for both remaining time and scheduling, handle
invalid clocks explicitly, and exercise clock changes and reboots on hardware.

### Alerting without reopening the app

Schedule a one-shot
[`Background.registerForTemporalEvent(Time.Moment)`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function)
at the deadline. A `System.ServiceDelegate.onTemporalEvent()` callback can read
the saved timer, confirm it is still running and due, and post a
[`Notifications.showNotification()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html#showNotification-instance_function).
The user can see that system notification without first reopening this app.

The Notifications API starts at **5.1.0**, explicitly supports the vivoactive 5,
and Garmin's [notification guide](https://developer.garmin.com/connect-iq/core-topics/notifications/)
documents use from background services. The installed device profile supports
API 5.2.0; that does not establish the firmware version on the physical watch.
Using it would require the `Notifications` and `Background` permissions and a
compatible minimum API or an explicit older-firmware fallback.

[`Attention.vibrate()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html)
and `Timer.Timer` are not available in background context. The custom three-pulse
vibration therefore stays in the foreground; background alert presentation is
controlled by the notification system. `Background.requestApplicationWake()`
is an older alternative that asks the user to launch the app. It is not an
automatic launch, and Garmin says the system can suppress the request if there
are insufficient resources. Do not issue both mechanisms indiscriminately.

### Scheduling restrictions and reliability

The five-minute rule is **not a blanket ban on timers shorter than five minutes**.
Garmin specifies that temporal events cannot occur less than five minutes after
the **last temporal event**. A repeating `Time.Duration` must be at least five
minutes; a one-shot `Time.Moment` is different. For watch apps, the restriction
is cleared on application startup if the event was specified using a Moment.
The docs do not require this call to occur inside a particular startup method.
Short first timers and consecutive short timers must be tested separately.

Only one temporal event can be registered per app; registering another replaces
it. Pause/reset must invalidate the saved running timer and delete its event.
Resume/replacement must update the saved deadline and registration. Re-check
the current timer generation/state in the callback to avoid stale alerts, and
coordinate foreground and background completion so one expiry is not announced
twice. Registration failures must be surfaced rather than silently suggesting
that an alarm is armed. The current Back control cancels before exiting; a
background-enabled version must separate "leave the app" from "cancel timer".

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
survives a reboot. Check/reconcile it on app startup and test reboot-without-
reopening separately. No app can alert while the watch is powered off.

Before claiming background alarm reliability on hardware, measure expiry timing
with the app open and screen off, after exit to the watch face, during another
activity, for consecutive one-minute timers, for 90/120-minute timers, around
pause/cancel near expiry, with DND/sleep enabled, after manual clock changes,
and after reboot without reopening the app. Accurate elapsed time is achievable;
an unconditional native-alarm guarantee is not established by these APIs.

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

`Build` creates the signed release **`bin\VisualTimer.prg`**.
`Test` compiles and runs Monkey C's native Run No Evil tests on the vivoactive 5
simulator. `Run` builds a debug app and leaves it running in the simulator until
you exit it. Simulator logs and all generated files are ignored by Git.
SDK 9.2.0 has a runner exit-code bug: it can return 1 despite reporting every
test as passed. The script warns about this specific case and accepts it only
for SDK 9.2.0 with an explicit non-empty, zero-failure test summary.

In VS Code, open this folder and use **Run Build Task** or **Run timer tests**.
These tasks read the existing `monkeyC.developerKeyPath` user setting.
F5 uses the Monkey C debugger. No private key path is stored in this repository.

## Install on your watch

1. Build the release PRG with the command above.
2. Connect the vivoactive 5 to the PC using a USB data cable. Close Garmin Express
   if it interferes with file access.
3. In File Explorer, open the watch's storage and its **`GARMIN\APPS`** directory
   (sometimes under **Internal Storage**).
4. Copy **`bin\VisualTimer.prg`** into that directory. Do not copy the debug XML,
   test PRG, or signing key. Replace the same PRG when updating.
5. Safely disconnect the watch, then find **Visual Timer** in its apps list.
   If needed, add it through the watch's app list customization.

Sideloading is for personal development and does not require Store publication.
For public distribution, use **Monkey C: Export Project** to produce an `.iq`
package and submit that package to the Connect IQ Store.

## Tests

`tests\TimerTests.mc` covers cardinal touch angles, duration rounding and limits,
release-to-start, delayed callbacks, fixed-scale sector shrinkage, zero expiry,
one-shot completion, pause/resume, cancellation, replacement, the twelve-o'clock
boundary, multiple anticlockwise revolutions, the 120-minute limit, nested-sector
angles and the transition through 60 minutes, both uptime rollover boundaries,
and single-tap pause/resume and dismissal.
Tests run inside Garmin's simulator and are excluded from the release build.

On hardware, first try a one-minute countdown and check:

- Dragging clockwise/counterclockwise, across twelve, and releasing near the centre.
- Tap to pause and resume, with a persistent pause icon; direct pause/resume
  with Select; Back reset, then Back exit.
- Continue dragging through twelve into the second revolution. At 90 minutes
  expect a full red circle with a black half-circle inside; at 120 minutes,
  expect a full black inner circle inside a red ring.
- Screen dimming, wrist wake, notification overlays, and expiry with the screen off.
- The three-pulse vibration, dismiss behaviour, and an uninterrupted longer timer.

## Structure

`source\TimerModel.mc` owns dial math and the clock-injected state machine.
`TimerDelegate.mc` maps input, and `TimerView.mc` draws and delivers the alarm.
The timer callback runs four times per second, but the display is refreshed only
once per elapsed second or when the interaction state changes.
