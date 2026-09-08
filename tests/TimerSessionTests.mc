import Toybox.Lang;
import Toybox.Test;

(:background)
class FakeTimerPlatform extends TimerPlatform {
    var saved as TimerRecord = TimerRecords.empty();
    var epoch as Number = 100000;
    var ticks as Number = 1000;
    var armed as Number? = null;
    var allowAlarm as Boolean = true;
    var notifications as Number = 0;
    var writes as Number = 0;

    function initialize() {
        TimerPlatform.initialize();
    }

    function now() as Number { return epoch; }
    function uptime() as Number { return ticks; }
    function load() as TimerRecord { return TimerRecords.decode(saved.toValue()); }

    function save(record as TimerRecord) as Void {
        saved = TimerRecords.decode(record.toValue());
        writes++;
    }

    function arm(deadline as Number) as Boolean {
        if (!allowAlarm) {
            return false;
        }
        armed = deadline;
        return true;
    }

    function disarm() as Void { armed = null; }
    function notifyExpired(record as TimerRecord) as Void { notifications++; }
}

(:test)
function backgroundSessionStartsOnRelease(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    Test.assertEqual(session.open(), false);
    Test.assert(session.beginDrag(0.0));
    session.moveDrag(6.0);
    Test.assertEqual(platform.saved.state, TimerState.IDLE);
    Test.assert(platform.armed == null);
    session.endDrag();
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(platform.saved.durationMs, 60000);
    Test.assertEqual(platform.saved.deadline, 100060);
    Test.assert(platform.armed == 100060);
    Test.assertEqual(session.model.state, TimerModel.RUNNING);
    return true;
}

(:test)
function backgroundLeaveAndReopenKeepsDeadline(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(90.0);
    session.endDrag();
    var deadline = platform.armed;
    platform.epoch += 20;
    session.leave();
    platform.epoch += 30;
    platform.ticks = 0;
    var reopened = new TimerSession(platform);
    Test.assertEqual(reopened.open(), false);
    Test.assert(platform.armed == deadline);
    Test.assertEqual(reopened.model.remainingMs(reopened.modelTime), 850000);
    Test.assertEqual(reopened.model.state, TimerModel.RUNNING);
    return true;
}

(:test)
function backgroundPauseReopenAndResume(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    platform.epoch += 15;
    session.tick();
    session.toggle();
    Test.assertEqual(platform.saved.state, TimerState.PAUSED);
    Test.assertEqual(platform.saved.durationMs, 45000);
    Test.assert(platform.armed == null);
    session.leave();
    platform.epoch += 1000;
    var reopened = new TimerSession(platform);
    Test.assertEqual(reopened.open(), false);
    Test.assertEqual(reopened.model.remainingMs(reopened.modelTime), 45000);
    reopened.toggle();
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assert(platform.armed == platform.epoch + 45);
    return true;
}

(:test)
function backgroundNotificationClaimsExpiryOnce(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    platform.epoch += 60;
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), true);
    Test.assertEqual(platform.notifications, 1);
    Test.assertEqual(platform.saved.state, TimerState.FINISHED);
    Test.assert(platform.armed == null);
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    Test.assertEqual(session.tick(), false);
    Test.assertEqual(session.model.state, TimerModel.FINISHED);
    var reopened = new TimerSession(platform);
    Test.assertEqual(reopened.open(), false);
    Test.assertEqual(platform.notifications, 1);
    reopened.toggle();
    Test.assertEqual(platform.saved.state, TimerState.IDLE);
    return true;
}

(:test)
function foregroundExpirySuppressesBackgroundDuplicate(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    platform.epoch += 60;
    Test.assertEqual(session.tick(), true);
    Test.assertEqual(session.tick(), false);
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    Test.assertEqual(platform.notifications, 0);
    Test.assertEqual(platform.saved.state, TimerState.FINISHED);
    return true;
}

(:test)
function overdueTimerRecoversOnStartup(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 60000, 99999, 7);
    var session = new TimerSession(platform);
    Test.assertEqual(session.open(), true);
    Test.assertEqual(session.model.state, TimerModel.FINISHED);
    Test.assertEqual(platform.saved.generation, 7);
    Test.assertEqual(session.tick(), false);
    return true;
}

(:test)
function earlyAndStaleCallbacksDoNotConsumeCurrentTimer(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    var oldGeneration = platform.saved.generation;
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    Test.assert(platform.armed == 100060);
    session.beginDrag(12.0);
    session.moveDrag(18.0);
    session.endDrag();
    platform.epoch += 60;
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    Test.assert(platform.armed == 100120);
    platform.epoch += 60;
    Test.assert(TimerExpiry.claim(platform, oldGeneration) == null);
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), true);
    Test.assertEqual(platform.notifications, 1);
    return true;
}

(:test)
function cancellingAndZeroSelectionRemoveAlarm(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    session.cancel();
    Test.assertEqual(platform.saved.state, TimerState.IDLE);
    Test.assert(platform.armed == null);
    platform.epoch += 60;
    Test.assertEqual(TimerExpiry.notifyIfDue(platform), false);
    session.beginDrag(0.0);
    session.moveDrag(90.0);
    session.endDrag();
    Test.assert(session.beginDrag(90.0));
    session.moveDrag(0.0);
    session.endDrag();
    Test.assertEqual(platform.saved.state, TimerState.IDLE);
    Test.assert(platform.armed == null);
    return true;
}

(:test)
function interruptedDragKeepsCommittedTimer(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    var writes = platform.writes;
    Test.assert(session.beginDrag(6.0));
    session.moveDrag(90.0);
    platform.epoch += 20;
    session.tick();
    Test.assertEqual(session.model.state, TimerModel.SETTING);
    Test.assertEqual(platform.saved.deadline, 100060);
    session.leave();
    Test.assertEqual(platform.writes, writes);
    Test.assertEqual(session.model.remainingMs(session.modelTime), 40000);
    Test.assertEqual(session.model.state, TimerModel.RUNNING);
    return true;
}

(:test)
function originalTimerCanExpireDuringReplacementPreview(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    Test.assert(session.beginDrag(6.0));
    session.moveDrag(180.0);
    platform.epoch += 60;
    Test.assertEqual(session.tick(), true);
    Test.assertEqual(session.model.state, TimerModel.SETTING);
    Test.assertEqual(platform.saved.state, TimerState.FINISHED);
    session.endDrag();
    Test.assertEqual(platform.saved.durationMs, 1800000);
    Test.assertEqual(platform.saved.deadline, 101860);
    return true;
}

(:test)
function rejectedAlarmIsSavedPausedAndReported(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.allowAlarm = false;
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    Test.assertEqual(session.error, true);
    Test.assertEqual(platform.saved.state, TimerState.PAUSED);
    Test.assertEqual(platform.saved.durationMs, 60000);
    Test.assert(platform.armed == null);
    Test.assertEqual(session.model.state, TimerModel.PAUSED);
    platform.allowAlarm = true;
    session.toggle();
    Test.assertEqual(session.error, false);
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assert(platform.armed == 100060);
    return true;
}

(:test)
function startupRearmsLostEventAndReportsFailure(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 120000, 100120, 9);
    var session = new TimerSession(platform);
    Test.assertEqual(session.open(), false);
    Test.assert(platform.armed == 100120);
    platform.allowAlarm = false;
    var rejected = new TimerSession(platform);
    Test.assertEqual(rejected.open(), false);
    Test.assertEqual(rejected.error, true);
    Test.assertEqual(platform.saved.state, TimerState.PAUSED);
    Test.assert(platform.armed == null);
    return true;
}
