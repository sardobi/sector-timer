import Toybox.Lang;
import Toybox.Test;

(:test)
function thirdLayerShrinksBeforePurpleAndRed(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.RUNNING, 9000000, 1000);
    Test.assertEqual(model.sectorAngle(1000), 360.0);
    Test.assertEqual(model.innerSectorAngle(1000), 360.0);
    Test.assertEqual(model.innermostSectorAngle(1000), 180.0);
    Test.assertEqual(model.innermostSectorAngle(901000), 90.0);
    Test.assertEqual(model.innerSectorAngle(1801000), 360.0);
    Test.assertEqual(model.innermostSectorAngle(1801000), 0.0);
    Test.assertEqual(model.innerSectorAngle(2701000), 270.0);
    Test.assertEqual(model.sectorAngle(5401000), 360.0);
    Test.assertEqual(model.innerSectorAngle(5401000), 0.0);
    Test.assertEqual(model.innermostSectorAngle(5401000), 0.0);
    Test.assertEqual(model.sectorAngle(6301000), 270.0);
    Test.assertEqual(model.tick(9001000), true);
    Test.assertEqual(model.innermostSectorAngle(9001000), 0.0);
    return true;
}

(:test)
function adjustmentStartsAtNinetyMinutesNotThirty(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.RUNNING, 5400000, 1000);
    model.beginAdjustment(180.0, 1000);
    Test.assertEqual(model.remainingMs(1000), 5400000);
    model.moveDrag(210.0);
    Test.assertEqual(model.remainingMs(1000), 5700000);
    model.endDrag(5000);
    Test.assertEqual(model.remainingMs(5000), 5700000);
    return true;
}

(:test)
function adjustmentWorksAwayFromHandleAndAcrossTwelve(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.PAUSED, 5400000, 1000);
    model.beginAdjustment(354.0, 1000);
    model.moveDrag(6.0);
    Test.assertEqual(model.remainingMs(1000), 5520000);
    model.moveDrag(354.0);
    Test.assertEqual(model.remainingMs(1000), 5400000);
    model.moveDrag(324.0);
    Test.assertEqual(model.remainingMs(1000), 5100000);
    return true;
}

(:test)
function adjustmentUsesRemainingTimeNotOriginalDuration(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.RUNNING, 5400000, 1000);
    model.beginAdjustment(45.0, 601000);
    Test.assertEqual(model.remainingMs(601000), 4800000);
    model.moveDrag(51.0);
    model.endDrag(701000);
    Test.assertEqual(model.remainingMs(701000), 4860000);
    return true;
}

(:test)
function unchangedAdjustmentPreservesSubMinuteRemainder(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.PAUSED, 875000, 1000);
    model.beginAdjustment(90.0, 1000);
    model.moveDrag(90.0);
    Test.assertEqual(model.remainingMs(1000), 875000);
    model.endDrag(2000);
    Test.assertEqual(model.remainingMs(2000), 875000);
    return true;
}

(:test)
function adjustmentClampsAtBothEndsWithoutWrapping(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.restore(TimerState.PAUSED, TimerState.MAX_MS, 0);
    model.beginAdjustment(354.0, 0);
    model.moveDrag(6.0);
    Test.assertEqual(model.remainingMs(0), TimerState.MAX_MS);
    model.moveDrag(0.0);
    Test.assertEqual(model.remainingMs(0), TimerState.MAX_MS - 60000);
    model.restore(TimerState.PAUSED, 60000, 0);
    model.beginAdjustment(6.0, 0);
    model.moveDrag(354.0);
    Test.assertEqual(model.remainingMs(0), 0);
    model.endDrag(0);
    Test.assertEqual(model.state, TimerState.IDLE);
    return true;
}

(:test)
function idleAdjustmentStillSetsFromDialPosition(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginAdjustment(90.0, 1000);
    Test.assertEqual(model.remainingMs(1000), 900000);
    model.restore(TimerState.FINISHED, 0, 0);
    model.beginAdjustment(180.0, 1000);
    Test.assertEqual(model.remainingMs(1000), 1800000);
    return true;
}

(:test)
function sessionAdjustmentPersistsAllThreeHours(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 5400000, 105400, 7);
    var session = new TimerSession(platform);
    session.open();
    session.beginDrag(180.0);
    Test.assertEqual(session.model.remainingMs(session.modelTime), 5400000);
    session.moveDrag(270.0);
    session.moveDrag(0.0);
    session.moveDrag(90.0);
    session.moveDrag(180.0);
    session.endDrag();
    Test.assertEqual(platform.saved.durationMs, 9000000);
    Test.assertEqual(platform.saved.deadline, 109000);
    session.leave();
    platform.epoch += 60;
    var reopened = new TimerSession(platform);
    reopened.open();
    Test.assertEqual(reopened.model.remainingMs(reopened.modelTime), 8940000);
    Test.assertEqual(reopened.model.innerSectorAngle(reopened.modelTime), 360.0);
    Test.assertEqual(reopened.model.innermostSectorAngle(reopened.modelTime), 174.0);
    return true;
}

(:test)
function sessionAdjustmentRefreshesElapsedTimeBeforeDrag(logger as Test.Logger) as Boolean {
    var platform = new FakeTimerPlatform();
    platform.saved = new TimerRecord(TimerState.RUNNING, 5400000, 105400, 7);
    var session = new TimerSession(platform);
    platform.epoch += 600;
    session.beginDrag(0.0);
    Test.assertEqual(session.model.remainingMs(session.modelTime), 4800000);
    session.moveDrag(6.0);
    session.endDrag();
    Test.assertEqual(platform.saved.durationMs, 4860000);
    Test.assertEqual(platform.saved.deadline, 105460);
    return true;
}
