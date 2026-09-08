import Toybox.Lang;
import Toybox.Test;

(:background)
class SimulatedNotificationException extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }
}

(:background)
class ReliabilityTimerPlatform extends FakeTimerPlatform {
    var failNotification as Boolean = false;
    var replaceDuringNotification as Boolean = false;
    var observedRunningAtNotification as Boolean = false;
    var schedulingWarnings as Number = 0;
    var events as Array<String> = [];

    function initialize() {
        FakeTimerPlatform.initialize();
    }

    function trace(event as String) as Void {
        events.add(event);
    }

    function registeredDeadline() as Number? {
        return armed;
    }

    function notifySchedulingFailure() as Void {
        schedulingWarnings++;
    }

    function notifyExpired(record as TimerRecord) as Void {
        observedRunningAtNotification = saved.state == TimerState.RUNNING;
        if (failNotification) {
            throw new SimulatedNotificationException();
        }
        notifications++;
        if (replaceDuringNotification) {
            saved = new TimerRecord(TimerState.RUNNING, 60000, epoch + 60, record.nextGeneration());
            armed = saved.deadline;
        }
    }
}

(:background)
class ReadbackTimerPlatform extends TimerPlatform {
    var registered as Number? = null;
    var acceptRegistration as Boolean = true;

    function initialize() {
        TimerPlatform.initialize();
    }

    function registerDeadline(deadline as Number) as Void {
        if (acceptRegistration) {
            registered = deadline;
        }
    }

    function registeredDeadline() as Number? {
        return registered;
    }
}

(:background)
class MemoryTimerDiagnostics extends TimerDiagnostics {
    var value as Object? = null;
    var writes as Number = 0;

    function initialize() {
        TimerDiagnostics.initialize();
    }

    function readValue() as Object? {
        return value;
    }

    function writeValue(entries as Array<String>) as Void {
        value = entries;
        writes++;
    }
}

(:test)
function notificationFailureLeavesCompletionRecoverable(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, platform.epoch, 7);
    platform.armed = platform.epoch;
    platform.failNotification = true;
    var failed = false;
    try {
        TimerExpiry.handleTemporalEvent(platform);
    } catch (error instanceof SimulatedNotificationException) {
        failed = true;
    }
    Test.assert(failed);
    Test.assert(platform.observedRunningAtNotification);
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(platform.writes, 0);
    Test.assert(platform.armed == platform.epoch);
    platform.failNotification = false;
    Test.assert(TimerExpiry.notifyIfDue(platform));
    Test.assertEqual(platform.saved.state, TimerState.FINISHED);
    Test.assertEqual(platform.notifications, 1);
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    return true;
}

(:test)
function failedNotificationCanRecoverOnForegroundOpen(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, platform.epoch, 8);
    platform.failNotification = true;
    try {
        TimerExpiry.notifyIfDue(platform);
    } catch (error instanceof SimulatedNotificationException) {
        var session = new TimerSession(platform);
        Test.assert(session.open());
        Test.assertEqual(platform.saved.state, TimerState.FINISHED);
        Test.assertEqual(session.tick(), false);
        return true;
    }
    return false;
}

(:test)
function notificationCannotFinishReplacementTimer(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, platform.epoch, 9);
    platform.replaceDuringNotification = true;
    Test.assert(TimerExpiry.notifyIfDue(platform));
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(platform.saved.generation, 10);
    Test.assert(platform.armed == platform.epoch + 60);
    return true;
}

(:test)
function earlyConsumedEventRearmsOriginalDeadline(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 600000, platform.epoch + 600, 10);
    Test.assertEqual(TimerExpiry.handleTemporalEvent(platform), false);
    Test.assert(platform.armed == platform.saved.deadline);
    Test.assertEqual(platform.saved.generation, 10);
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(platform.notifications, 0);
    Test.assertEqual(platform.schedulingWarnings, 0);
    return true;
}

(:test)
function earlyEventKeepsExistingRegistrationDespiteCooldown(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, platform.epoch + 60, 11);
    platform.armed = platform.saved.deadline;
    platform.allowAlarm = false;
    Test.assertEqual(TimerExpiry.handleTemporalEvent(platform), false);
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assert(platform.armed == platform.saved.deadline);
    Test.assertEqual(platform.writes, 0);
    return true;
}

(:test)
function earlyConsumedEventRejectionIsNotSilentlyRunning(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, platform.epoch + 60, 12);
    platform.allowAlarm = false;
    Test.assertEqual(TimerExpiry.handleTemporalEvent(platform), false);
    Test.assertEqual(platform.saved.state, TimerState.PAUSED);
    Test.assertEqual(platform.saved.durationMs, 60000);
    Test.assertEqual(platform.saved.generation, 13);
    Test.assert(platform.armed == null);
    Test.assertEqual(platform.notifications, 0);
    Test.assertEqual(platform.schedulingWarnings, 1);
    return true;
}

(:test)
function registrationRequiresExactReadback(logger as Test.Logger) as Boolean {
    var platform = new ReadbackTimerPlatform();
    Test.assert(platform.arm(100060));
    platform.acceptRegistration = false;
    Test.assertEqual(platform.arm(100120), false);
    platform.registered = null;
    Test.assertEqual(platform.arm(100120), false);
    return true;
}

(:test)
function alarmDiagnosticsAreBoundedAndSurviveNewReader(logger as Test.Logger) as Boolean {
    var log = new MemoryTimerDiagnostics();
    for (var i = 0; i < 25; i++) {
        log.append(100000 + i, "event " + i);
    }

    Test.assertEqual(log.writes, 25);
    var reopened = new MemoryTimerDiagnostics();
    reopened.value = log.value;
    var entries = reopened.readEntries();
    Test.assertEqual(entries.size(), TimerDiagnostics.LIMIT);
    Test.assertEqual(entries[0], "100005 event 5");
    Test.assertEqual(entries[19], "100024 event 24");
    var longMessage = "";
    for (var n = 0; n < 200; n++) {
        longMessage += "x";
    }
    reopened.append(100025, longMessage);
    entries = reopened.readEntries();
    Test.assertEqual(entries[19].length(), TimerDiagnostics.MAX_LENGTH);
    return true;
}

(:test)
function leavingAtDeadlineDoesNotConsumeBackgroundAlarm(logger as Test.Logger) as Boolean {
    var platform = new ReliabilityTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(6.0);
    session.endDrag();
    platform.epoch += 60;
    session.leave();
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assert(platform.armed == platform.epoch);
    Test.assert(TimerExpiry.handleTemporalEvent(platform));
    Test.assertEqual(platform.notifications, 1);
    Test.assertEqual(platform.saved.state, TimerState.FINISHED);
    return true;
}
