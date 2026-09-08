import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;
import Toybox.Time;

(:background)
class TimerPlatform {
    private var _diagnostics as TimerDiagnostics? = null;

    function initialize() {
    }

    function setDiagnostics(diagnostics as TimerDiagnostics) as Void {
        _diagnostics = diagnostics;
    }

    function trace(event as String) as Void {
        if (_diagnostics != null) {
            _diagnostics.append(now(), event);
        }
    }

    function now() as Number {
        return Time.now().value();
    }

    function uptime() as Number {
        return System.getTimer();
    }

    function load() as TimerRecord {
        return TimerRecords.decode(Storage.getValue("timer-v1"));
    }

    function save(record as TimerRecord) as Void {
        Storage.setValue("timer-v1", record.toValue());
        trace("saved g=" + record.generation + " state=" + record.state + " due=" + record.deadline);
    }

    function registeredDeadline() as Number? {
        var registered = Background.getTemporalEventRegisteredTime();
        return registered instanceof Time.Moment ? registered.value() : null;
    }

    function registerDeadline(deadline as Number) as Void {
        Background.registerForTemporalEvent(new Time.Moment(deadline));
    }

    function arm(deadline as Number) as Boolean {
        try {
            registerDeadline(deadline);
        } catch (error instanceof Background.InvalidBackgroundTimeException) {
            trace("arm rejected due=" + deadline + " " + error.getErrorMessage());
            return false;
        }
        var registered = registeredDeadline();
        trace("arm due=" + deadline + " readback=" + registered);
        return registered != null && registered == deadline;
    }

    function disarm() as Void {
        Background.deleteTemporalEvent();
        trace("disarmed");
    }

    function notifyExpired(record as TimerRecord) as Void {
        Notifications.showNotification(Rez.Strings.AppName, Rez.Strings.TimerFinished, {
            :body => Rez.Strings.OpenTimer,
            :data => record.generation,
            :dismissPrevious => true
        });
    }

    function notifySchedulingFailure() as Void {
        Notifications.showNotification(Rez.Strings.AppName, Rez.Strings.AlarmProblem, {
            :body => Rez.Strings.BackgroundAlarmPaused,
            :dismissPrevious => true
        });
        trace("scheduling failure notification returned");
    }
}

(:background)
module TimerExpiry {
    function handleTemporalEvent(platform as TimerPlatform) as Boolean {
        var current = platform.load();
        platform.trace("fired g=" + current.generation + " state=" + current.state +
            " due=" + current.deadline + " registered=" + platform.registeredDeadline());
        if (current.state == TimerState.RUNNING && !current.isDue(platform.now())) {
            // A consumed early callback must not leave a running timer without its event.
            if (platform.registeredDeadline() != current.deadline && !platform.arm(current.deadline)) {
                var latest = platform.load();
                if (latest.generation == current.generation && latest.state == TimerState.RUNNING) {
                    var remaining = latest.remainingAt(platform.now());
                    if (remaining > 0) {
                        platform.save(new TimerRecord(TimerState.PAUSED, remaining, 0, latest.nextGeneration()));
                        platform.disarm();
                        platform.trace("early rearm failed; timer paused");
                        platform.notifySchedulingFailure();
                    }
                }
            }
            if (current.isDue(platform.now())) {
                return notifyIfDue(platform);
            }
            platform.trace("skipped early g=" + current.generation + " due=" + current.deadline);
            return false;
        }
        return notifyIfDue(platform);
    }

    function notifyIfDue(platform as TimerPlatform) as Boolean {
        var current = platform.load();
        if (!current.isDue(platform.now())) {
            platform.trace("skipped not due g=" + current.generation + " state=" + current.state);
            return false;
        }
        platform.trace("notify begin g=" + current.generation + " due=" + current.deadline);
        // Do not durably suppress recovery before the notification API has returned.
        // A crash after posting but before saving can still cause a duplicate.
        platform.notifyExpired(current);
        platform.trace("notify returned g=" + current.generation + " (not delivery confirmation)");
        claim(platform, current.generation);
        return true;
    }

    // Foreground and background both claim completion in the same saved record.
    function claim(platform as TimerPlatform, generation as Number?) as TimerRecord? {
        var current = platform.load();
        if ((generation != null && current.generation != generation) || !current.isDue(platform.now())) {
            return null;
        }
        var finished = new TimerRecord(TimerState.FINISHED, 0, 0, current.generation);
        platform.save(finished);
        platform.disarm();
        return finished;
    }
}
