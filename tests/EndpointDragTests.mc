import Toybox.Lang;
import Toybox.Test;

(:test)
function emptyEndpointAcceptsBothSidesWithoutHourJump(logger as Test.Logger) as Boolean {
    var starts = [342.0, 348.0, 354.0, 359.5, 0.0, 6.0, 18.0];
    for (var i = 0; i < starts.size(); i++) {
        var platform = new FakeTimerPlatform();
        var session = new TimerSession(platform);
        Test.assert(session.beginDrag(starts[i]));
        Test.assertEqual(session.model.remainingMs(session.modelTime), 0);
        var next = starts[i] + 6.0;
        session.moveDrag(next >= 360.0 ? next - 360.0 : next);
        Test.assertEqual(session.model.remainingMs(session.modelTime), 60000);
        session.endDrag();
        Test.assertEqual(platform.saved.durationMs, 60000);
        Test.assert(platform.armed == platform.epoch + 60);
    }
    return true;
}

(:test)
function emptyEndpointRejectsUnrelatedStartingPositions(logger as Test.Logger) as Boolean {
    var starts = [18.1, 90.0, 180.0, 270.0, 341.9];
    for (var i = 0; i < starts.size(); i++) {
        var platform = new FakeTimerPlatform();
        var session = new TimerSession(platform);
        Test.assertEqual(session.beginDrag(starts[i]), false);
        session.moveDrag(0.0);
        session.moveDrag(90.0);
        session.endDrag();
        Test.assertEqual(session.model.state, TimerState.IDLE);
        Test.assertEqual(platform.writes, 0);
        Test.assert(platform.armed == null);
    }
    return true;
}

(:test)
function rejectedAdjustmentLeavesRunningTimerAndAlarmUntouched(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 5400000, platform.epoch + 5400, 7);
    platform.armed = platform.saved.deadline;
    var session = new TimerSession(platform);
    Test.assertEqual(session.beginDrag(0.0), false);
    session.moveDrag(180.0);
    session.endDrag();
    Test.assertEqual(platform.writes, 0);
    Test.assertEqual(platform.saved.generation, 7);
    Test.assert(platform.armed == platform.saved.deadline);
    Test.assertEqual(session.model.state, TimerState.RUNNING);
    platform.epoch += 60;
    session.tick();
    Test.assertEqual(session.model.remainingMs(session.modelTime), 5340000);
    Test.assert(session.beginDrag(174.0));
    session.moveDrag(180.0);
    session.endDrag();
    Test.assertEqual(platform.saved.durationMs, 5400000);
    return true;
}

(:test)
function multiHourHandleTracksActiveLayerWithoutDroppingLaps(logger as Test.Logger) as Boolean {
    var durations = [5400000, 9000000];
    for (var i = 0; i < durations.size(); i++) {
        var model = new TimerModel();
        model.restore(TimerState.PAUSED, durations[i], 0);
        Test.assertEqual(Dial.endpointAngle(durations[i]), 180.0);
        Test.assertEqual(model.beginAdjustment(0.0, 0), false);
        Test.assertEqual(model.state, TimerState.PAUSED);
        Test.assert(model.beginAdjustment(168.0, 0));
        Test.assertEqual(model.remainingMs(0), durations[i]);
        model.moveDrag(174.0);
        Test.assertEqual(model.remainingMs(0), durations[i] + 60000);
    }
    Test.assertEqual(Dial.endpointAngle(0), 0.0);
    Test.assertEqual(Dial.endpointAngle(3600000), 0.0);
    Test.assertEqual(Dial.endpointAngle(7200000), 0.0);
    Test.assertEqual(Dial.endpointAngle(TimerState.MAX_MS), 0.0);
    return true;
}

(:test)
function grabbingWithoutMovementDoesNotStartAnEmptyTimer(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    Test.assert(session.beginDrag(354.0));
    session.moveDrag(354.0);
    session.endDrag();
    Test.assertEqual(platform.saved.state, TimerState.IDLE);
    Test.assert(platform.armed == null);
    return true;
}

(:test)
function clockwiseDragFromEmptyHandleCannotUnderflowToAnHour(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    Test.assert(model.beginAdjustment(6.0, 0));
    model.moveDrag(354.0);
    Test.assertEqual(model.remainingMs(0), 0);
    model.moveDrag(0.0);
    Test.assertEqual(model.remainingMs(0), 60000);
    return true;
}

(:test)
function endpointGateAppliesOnlyWhenStartingTheDrag(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    Test.assert(model.beginAdjustment(0.0, 0));
    for (var angle = 6; angle <= 900; angle += 6) {
        model.moveDrag((angle % 360).toFloat());
    }
    Test.assertEqual(model.remainingMs(0), 9000000);
    model.endDrag(1000);
    Test.assertEqual(model.state, TimerState.RUNNING);
    return true;
}

(:test)
function viewAcceptsEndpointButNotCentreOrOppositeSide(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    var session = new TimerSession(platform);
    var view = new TimerView(session, null);
    Test.assertEqual(view.beginDrag(195, 195), false);
    Test.assertEqual(view.beginDrag(195, 5), true);
    session.abortDrag();
    Test.assertEqual(view.beginDrag(195, 390), false);
    Test.assertEqual(view.beginDrag(195, 355), false);
    Test.assert(view.beginDrag(212, 33));
    Test.assertEqual(session.model.remainingMs(session.modelTime), 0);
    session.moveDrag(6.0);
    session.endDrag();
    Test.assertEqual(platform.saved.durationMs, 120000);
    view.stop();
    return true;
}
