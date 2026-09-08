import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;
import Toybox.Time;

(:background)
class TimerPlatform {
    function initialize() {
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
    }

    function arm(deadline as Number) as Boolean {
        try {
            Background.registerForTemporalEvent(new Time.Moment(deadline));
            System.println("Visual Timer: alarm registered for " + deadline);
            return true;
        } catch (error instanceof Background.InvalidBackgroundTimeException) {
            System.println("Visual Timer: background alarm registration failed: " + error.getErrorMessage());
            return false;
        }
    }

    function disarm() as Void {
        Background.deleteTemporalEvent();
    }

    function notifyExpired(record as TimerRecord) as Void {
        Notifications.showNotification(Rez.Strings.AppName, Rez.Strings.TimerFinished, {
            :body => Rez.Strings.OpenTimer,
            :data => record.generation,
            :dismissPrevious => true
        });
        System.println("Visual Timer: expiry notification posted for timer " + record.generation);
    }
}

(:background)
module TimerExpiry {
    function notifyIfDue(platform as TimerPlatform) as Boolean {
        var finished = claim(platform, null);
        if (finished == null) {
            return false;
        }
        platform.notifyExpired(finished);
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
