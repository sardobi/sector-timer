import Toybox.Lang;
import Toybox.Test;

function assertInvalidTimerRecord(value as Object?) as Void {
    var rejected = false;
    try {
        TimerRecords.decode(value);
    } catch (e instanceof InvalidTimerRecordException) {
        rejected = true;
    }
    Test.assertEqual(rejected, true);
}

(:test)
function timerRecordNullDecodesToIdle(logger as Test.Logger) as Boolean {
    var record = TimerRecords.decode(null);
    Test.assertEqual(record.state, TimerState.IDLE);
    Test.assertEqual(record.durationMs, 0);
    Test.assertEqual(record.deadline, 0);
    Test.assertEqual(record.generation, 0);
    Test.assertEqual(record.remainingAt(123456), 0);
    Test.assertEqual(record.isDue(123456), false);
    return true;
}

(:test)
function timerRecordRunningRoundTrip(logger as Test.Logger) as Boolean {
    var original = new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 42);
    var value = original.toValue();
    var version = value["version"];
    Test.assert(version instanceof Number && version == 1);
    var record = TimerRecords.decode(value);
    Test.assertEqual(record.state, TimerState.RUNNING);
    Test.assertEqual(record.durationMs, 60000);
    Test.assertEqual(record.deadline, 1700000060);
    Test.assertEqual(record.generation, 42);
    Test.assertEqual(record.remainingAt(1700000030), 30000);
    return true;
}

(:test)
function timerRecordPausedRoundTrip(logger as Test.Logger) as Boolean {
    var original = new TimerRecord(TimerState.PAUSED, 49750, 0, 43);
    var record = TimerRecords.decode(original.toValue());
    Test.assertEqual(record.state, TimerState.PAUSED);
    Test.assertEqual(record.durationMs, 49750);
    Test.assertEqual(record.deadline, 0);
    Test.assertEqual(record.generation, 43);
    Test.assertEqual(record.remainingAt(1700000030), 49750);
    Test.assertEqual(record.isDue(1700000030), false);
    return true;
}

(:test)
function timerRecordFinishedRoundTrip(logger as Test.Logger) as Boolean {
    var original = new TimerRecord(TimerState.FINISHED, 0, 0, 44);
    var record = TimerRecords.decode(original.toValue());
    Test.assertEqual(record.state, TimerState.FINISHED);
    Test.assertEqual(record.durationMs, 0);
    Test.assertEqual(record.deadline, 0);
    Test.assertEqual(record.generation, 44);
    Test.assertEqual(record.remainingAt(1700000030), 0);
    Test.assertEqual(record.isDue(1700000030), false);
    return true;
}

(:test)
function timerRecordRejectsNonDictionaries(logger as Test.Logger) as Boolean {
    assertInvalidTimerRecord(1);
    assertInvalidTimerRecord("timer");
    assertInvalidTimerRecord(true);
    assertInvalidTimerRecord([]);
    return true;
}

(:test)
function timerRecordRejectsInvalidVersions(logger as Test.Logger) as Boolean {
    var value = new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 1).toValue();
    value["version"] = 0;
    assertInvalidTimerRecord(value);
    value["version"] = 2;
    assertInvalidTimerRecord(value);
    value["version"] = 1.0;
    assertInvalidTimerRecord(value);
    value["version"] = 1l;
    assertInvalidTimerRecord(value);
    return true;
}

(:test)
function timerRecordRejectsIncorrectFieldTypes(logger as Test.Logger) as Boolean {
    var fields = ["version", "state", "durationMs", "deadline", "generation"];
    for (var i = 0; i < fields.size(); i += 1) {
        var value = new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 1).toValue();
        value[fields[i]] = "1";
        assertInvalidTimerRecord(value);
        value[fields[i]] = true;
        assertInvalidTimerRecord(value);
        value[fields[i]] = 1.0;
        assertInvalidTimerRecord(value);
        value[fields[i]] = 1l;
        assertInvalidTimerRecord(value);
        value[fields[i]] = null;
        assertInvalidTimerRecord(value);
    }
    return true;
}

(:test)
function timerRecordRejectsMissingFields(logger as Test.Logger) as Boolean {
    assertInvalidTimerRecord({});
    var fields = ["version", "state", "durationMs", "deadline", "generation"];
    for (var i = 0; i < fields.size(); i += 1) {
        var value = new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 1).toValue();
        value.remove(fields[i]);
        assertInvalidTimerRecord(value);
    }
    return true;
}

(:test)
function timerRecordRejectsInvalidStates(logger as Test.Logger) as Boolean {
    assertInvalidTimerRecord(new TimerRecord(TimerState.SETTING, 0, 0, 0).toValue());
    assertInvalidTimerRecord(new TimerRecord(-1, 0, 0, 0).toValue());
    assertInvalidTimerRecord(new TimerRecord(5, 0, 0, 0).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.IDLE, 1, 0, 0).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.FINISHED, 1, 0, 0).toValue());
    return true;
}

(:test)
function timerRecordRejectsInvalidDeadlines(logger as Test.Logger) as Boolean {
    assertInvalidTimerRecord(new TimerRecord(TimerState.RUNNING, 60000, 0, 0).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.RUNNING, 60000, -1, 0).toValue());
    var states = [TimerState.IDLE, TimerState.PAUSED, TimerState.FINISHED];
    for (var i = 0; i < states.size(); i += 1) {
        var duration = states[i] == TimerState.PAUSED ? 60000 : 0;
        assertInvalidTimerRecord(new TimerRecord(states[i], duration, 1, 0).toValue());
        assertInvalidTimerRecord(new TimerRecord(states[i], duration, -1, 0).toValue());
    }
    return true;
}

(:test)
function timerRecordRejectsInvalidDurations(logger as Test.Logger) as Boolean {
    var states = [TimerState.RUNNING, TimerState.PAUSED];
    for (var i = 0; i < states.size(); i += 1) {
        var deadline = states[i] == TimerState.RUNNING ? 1700000060 : 0;
        assertInvalidTimerRecord(new TimerRecord(states[i], -1, deadline, 0).toValue());
        assertInvalidTimerRecord(new TimerRecord(states[i], 0, deadline, 0).toValue());
        assertInvalidTimerRecord(new TimerRecord(states[i], TimerState.MAX_MS + 1, deadline, 0).toValue());
    }
    return true;
}

(:test)
function timerRecordRejectsNegativeGeneration(logger as Test.Logger) as Boolean {
    assertInvalidTimerRecord(new TimerRecord(TimerState.RUNNING, 60000, 1700000060, -1).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.PAUSED, 60000, 0, -1).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.FINISHED, 0, 0, -1).toValue());
    assertInvalidTimerRecord(new TimerRecord(TimerState.IDLE, 0, 0, -1).toValue());
    return true;
}

(:test)
function timerRecordDeadlineBoundaries(logger as Test.Logger) as Boolean {
    var record = new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 0);
    Test.assertEqual(record.remainingAt(1699999999), 60000);
    Test.assertEqual(record.remainingAt(1700000000), 60000);
    Test.assertEqual(record.remainingAt(1700000059), 1000);
    Test.assertEqual(record.isDue(1700000059), false);
    Test.assertEqual(record.remainingAt(1700000060), 0);
    Test.assertEqual(record.isDue(1700000060), true);
    Test.assertEqual(record.remainingAt(1700000061), 0);
    Test.assertEqual(record.isDue(1700000061), true);
    return true;
}

(:test)
function timerRecordPausedIgnoresEpochChanges(logger as Test.Logger) as Boolean {
    var record = TimerRecords.decode(new TimerRecord(TimerState.PAUSED, 49750, 0, 0).toValue());
    var epochs = [-2147483647, -1, 0, 1700000000, 2147483647];
    for (var i = 0; i < epochs.size(); i += 1) {
        Test.assertEqual(record.remainingAt(epochs[i]), 49750);
        Test.assertEqual(record.isDue(epochs[i]), false);
    }
    return true;
}

(:test)
function timerRecordLargeEpochDeltasDoNotOverflow(logger as Test.Logger) as Boolean {
    var future = TimerRecords.decode(new TimerRecord(TimerState.RUNNING, TimerState.MAX_MS, 2147483647, 0).toValue());
    Test.assertEqual(future.remainingAt(-2147483647), TimerState.MAX_MS);
    Test.assertEqual(future.remainingAt(0), TimerState.MAX_MS);
    Test.assertEqual(future.isDue(-2147483647), false);
    var past = TimerRecords.decode(new TimerRecord(TimerState.RUNNING, TimerState.MAX_MS, 1, 0).toValue());
    Test.assertEqual(past.remainingAt(2147483647), 0);
    Test.assertEqual(past.isDue(2147483647), true);
    Test.assertEqual(past.remainingAt(-2147483647), TimerState.MAX_MS);
    Test.assertEqual(past.isDue(-2147483647), false);
    return true;
}

(:test)
function timerRecordAcceptsDurationBounds(logger as Test.Logger) as Boolean {
    Test.assertEqual(TimerState.MAX_MS, 7200000);
    var running = TimerRecords.decode(new TimerRecord(TimerState.RUNNING, TimerState.MAX_MS, 1700007200, 0).toValue());
    Test.assertEqual(running.remainingAt(1700000000), 7200000);
    Test.assertEqual(running.remainingAt(1700000001), 7199000);
    Test.assertEqual(running.remainingAt(1699999999), 7200000);
    var paused = TimerRecords.decode(new TimerRecord(TimerState.PAUSED, TimerState.MAX_MS, 0, 0).toValue());
    Test.assertEqual(paused.remainingAt(2147483647), 7200000);
    var minimum = TimerRecords.decode(new TimerRecord(TimerState.RUNNING, 1, 1700000001, 0).toValue());
    Test.assertEqual(minimum.remainingAt(1700000000), 1);
    Test.assertEqual(minimum.remainingAt(1700000001), 0);
    var minimumPaused = TimerRecords.decode(new TimerRecord(TimerState.PAUSED, 1, 0, 0).toValue());
    Test.assertEqual(minimumPaused.remainingAt(1700000000), 1);
    return true;
}

(:test)
function timerRecordGenerationIncrementsAndWraps(logger as Test.Logger) as Boolean {
    var first = TimerRecords.decode(null);
    Test.assertEqual(first.nextGeneration(), 1);
    Test.assertEqual(first.generation, 0);
    var penultimate = new TimerRecord(TimerState.IDLE, 0, 0, 2147483646);
    Test.assertEqual(penultimate.nextGeneration(), 2147483647);
    var last = TimerRecords.decode(new TimerRecord(TimerState.FINISHED, 0, 0, 2147483647).toValue());
    Test.assertEqual(last.nextGeneration(), 0);
    Test.assertEqual(last.generation, 2147483647);
    return true;
}

(:test)
function timerModelRestoresRunningWithFreshUptime(logger as Test.Logger) as Boolean {
    var record = TimerRecords.decode(new TimerRecord(TimerState.RUNNING, 60000, 1700000060, 7).toValue());
    var model = new TimerModel();
    model.beginDrag(90.0);
    model.endDrag(900000);
    model.restore(record.state, record.remainingAt(1700000030), 500);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    Test.assertEqual(model.remainingMs(500), 30000);
    Test.assertEqual(model.remainingMs(1500), 29000);
    Test.assertEqual(model.tick(30499), false);
    Test.assertEqual(model.tick(30500), true);
    Test.assertEqual(model.state, TimerModel.FINISHED);
    Test.assertEqual(model.tick(30501), false);
    return true;
}

(:test)
function timerModelRestoresPausedWithFreshUptime(logger as Test.Logger) as Boolean {
    var record = TimerRecords.decode(new TimerRecord(TimerState.PAUSED, 49750, 0, 8).toValue());
    var model = new TimerModel();
    model.restore(record.state, record.remainingAt(1700000000), 500);
    Test.assertEqual(model.state, TimerModel.PAUSED);
    Test.assertEqual(model.remainingMs(500), 49750);
    Test.assertEqual(model.remainingMs(1000000), 49750);
    Test.assertEqual(model.tick(1000000), false);
    model.togglePause(1000000);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    Test.assertEqual(model.remainingMs(1001000), 48750);
    Test.assertEqual(model.tick(1049749), false);
    Test.assertEqual(model.tick(1049750), true);
    return true;
}

(:test)
function timerModelRestoresFinishedWithoutDuplicateTick(logger as Test.Logger) as Boolean {
    var record = TimerRecords.decode(new TimerRecord(TimerState.FINISHED, 0, 0, 9).toValue());
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(900000);
    model.restore(record.state, record.remainingAt(1700000000), 500);
    Test.assertEqual(model.state, TimerModel.FINISHED);
    Test.assertEqual(model.remainingMs(500), 0);
    Test.assertEqual(model.tick(500), false);
    Test.assertEqual(model.tick(1000000), false);
    Test.assertEqual(model.state, TimerModel.FINISHED);
    model.tap(1000001);
    Test.assertEqual(model.state, TimerModel.IDLE);
    return true;
}
