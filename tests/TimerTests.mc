import Toybox.Lang;
import Toybox.Test;

(:test)
function cardinalAngles(logger as Test.Logger) as Boolean {
    Test.assertEqual(Dial.angleAt(195, 45, 195, 195), 0.0);
    Test.assertEqual(Dial.angleAt(345, 195, 195, 195), 270.0);
    Test.assertEqual(Dial.angleAt(195, 345, 195, 195), 180.0);
    Test.assertEqual(Dial.angleAt(45, 195, 195, 195), 90.0);
    return true;
}

(:test)
function durationRoundingAndBounds(logger as Test.Logger) as Boolean {
    Test.assertEqual(Dial.durationAt(-5.0), 0);
    Test.assertEqual(Dial.durationAt(2.9), 0);
    Test.assertEqual(Dial.durationAt(3.1), 60000);
    Test.assertEqual(Dial.durationAt(90.0), 900000);
    Test.assertEqual(Dial.durationAt(180.0), 1800000);
    Test.assertEqual(Dial.durationAt(360.0), 3600000);
    Test.assertEqual(Dial.durationAt(450.0), 4500000);
    Test.assertEqual(Dial.durationAt(720.0), 7200000);
    Test.assertEqual(Dial.durationAt(900.0), 9000000);
    Test.assertEqual(Dial.durationAt(1080.0), 10800000);
    Test.assertEqual(Dial.durationAt(1200.0), 10800000);
    return true;
}

(:test)
function startsOnlyOnRelease(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(90.0);
    Test.assertEqual(model.state, TimerModel.SETTING);
    Test.assertEqual(model.remainingMs(123456), 900000);
    model.moveDrag(180.0);
    Test.assertEqual(model.remainingMs(999999), 1800000);
    model.endDrag(1000);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    Test.assertEqual(model.remainingMs(1000), 1800000);
    Test.assertEqual(model.remainingMs(2000), 1799000);
    return true;
}

(:test)
function countdownUsesElapsedTime(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(500);
    Test.assertEqual(model.remainingMs(15500), 45000);
    Test.assertEqual(model.sectorAngle(30500), 3.0);
    Test.assertEqual(model.tick(60499), false);
    Test.assertEqual(model.tick(90000), true);
    Test.assertEqual(model.state, TimerModel.FINISHED);
    Test.assertEqual(model.remainingMs(90000), 0);
    Test.assertEqual(model.sectorAngle(90000), 0.0);
    Test.assertEqual(model.tick(95000), false);
    return true;
}

(:test)
function pauseResumePreservesRemainder(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(1000);
    model.togglePause(11250);
    Test.assertEqual(model.state, TimerModel.PAUSED);
    Test.assertEqual(model.remainingMs(900000), 49750);
    model.togglePause(1000000);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    Test.assertEqual(model.remainingMs(1001000), 48750);
    Test.assertEqual(model.tick(1049750), true);
    return true;
}

(:test)
function crossingTwelveAddsAndSubtractsMinutes(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(354.0);
    model.moveDrag(6.0);
    Test.assertEqual(model.remainingMs(0), 3660000);
    model.moveDrag(354.0);
    Test.assertEqual(model.remainingMs(0), 3540000);
    model.beginDrag(6.0);
    model.moveDrag(358.0);
    Test.assertEqual(model.remainingMs(0), 0);
    model.endDrag(100);
    Test.assertEqual(model.state, TimerModel.IDLE);
    return true;
}

(:test)
function startingJustRightOfTwelve(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(359.5);
    model.moveDrag(2.0);
    model.moveDrag(45.0);
    model.moveDrag(90.0);
    model.endDrag(1000);
    Test.assertEqual(model.remainingMs(1000), 900000);
    return true;
}

(:test)
function completeAnticlockwiseRevolution(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(0.0);
    for (var angle = 6; angle <= 360; angle += 6) {
        model.moveDrag((angle % 360).toFloat());
    }
    model.endDrag(1234);
    Test.assertEqual(model.remainingMs(1234), Dial.LAP_MS);
    Test.assertEqual(model.sectorAngle(1234), 360.0);
    return true;
}

(:test)
function resettingAndReplacingTimer(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(90.0);
    model.endDrag(100);
    model.reset();
    Test.assertEqual(model.state, TimerModel.IDLE);
    Test.assertEqual(model.remainingMs(9999999), 0);
    Test.assertEqual(model.tick(9999999), false);
    model.endDrag(100);
    Test.assertEqual(model.state, TimerModel.IDLE);
    model.beginDrag(180.0);
    model.endDrag(200);
    model.beginDrag(6.0);
    Test.assertEqual(model.tick(9999999), false);
    model.endDrag(500);
    Test.assertEqual(model.remainingMs(1500), 59000);
    return true;
}

(:test)
function uptimeSignedRollover(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(2147483000);
    Test.assertEqual(model.remainingMs(-2147483296), 59000);
    Test.assertEqual(model.tick(-2147424296), true);
    return true;
}

(:test)
function uptimeFullWrap(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(-500);
    Test.assertEqual(model.remainingMs(500), 59000);
    Test.assertEqual(model.tick(59500), true);
    return true;
}

(:test)
function singleTapPausesAndResumes(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(90.0);
    model.endDrag(1000);
    model.tap(2000);
    Test.assertEqual(model.state, TimerModel.PAUSED);
    Test.assertEqual(model.remainingMs(20000), 899000);
    Test.assertEqual(model.tick(20000), false);
    model.tap(30000);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    Test.assertEqual(model.remainingMs(31000), 898000);
    return true;
}

(:test)
function tapsDoNotStartIdleOrSettingTimers(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.tap(1000);
    Test.assertEqual(model.state, TimerModel.IDLE);
    model.beginDrag(90.0);
    model.tap(2000);
    Test.assertEqual(model.state, TimerModel.SETTING);
    Test.assertEqual(model.remainingMs(2000), 900000);
    return true;
}

(:test)
function nestedSectorCountsDownThroughOneHour(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(0.0);
    for (var angle = 6; angle <= 540; angle += 6) {
        model.moveDrag((angle % 360).toFloat());
    }
    model.endDrag(1000);
    Test.assertEqual(model.remainingMs(1000), 5400000);
    Test.assertEqual(model.sectorAngle(1000), 360.0);
    Test.assertEqual(model.innerSectorAngle(1000), 180.0);
    Test.assertEqual(model.sectorAngle(901000), 360.0);
    Test.assertEqual(model.innerSectorAngle(901000), 90.0);
    Test.assertEqual(model.sectorAngle(1801000), 360.0);
    Test.assertEqual(model.innerSectorAngle(1801000), 0.0);
    Test.assertEqual(model.tick(1801000), false);
    Test.assertEqual(model.sectorAngle(2701000), 270.0);
    Test.assertEqual(model.innerSectorAngle(2701000), 0.0);
    Test.assertEqual(model.tick(5401000), true);
    Test.assertEqual(model.innerSectorAngle(5401000), 0.0);
    return true;
}

(:test)
function threeRevolutionsClampAtThreeHours(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(0.0);
    for (var angle = 6; angle <= 1260; angle += 6) {
        model.moveDrag((angle % 360).toFloat());
    }
    Test.assertEqual(model.remainingMs(0), Dial.MAX_MS);
    Test.assertEqual(model.sectorAngle(0), 360.0);
    Test.assertEqual(model.innerSectorAngle(0), 360.0);
    Test.assertEqual(model.innermostSectorAngle(0), 360.0);
    model.moveDrag(174.0);
    Test.assertEqual(model.remainingMs(0), Dial.MAX_MS - 60000);
    model.endDrag(1000);
    Test.assertEqual(model.state, TimerModel.RUNNING);
    return true;
}

(:test)
function pausingNestedSectorPreservesBothLayers(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(354.0);
    model.moveDrag(90.0);
    model.endDrag(1000);
    model.tap(601000);
    Test.assertEqual(model.state, TimerModel.PAUSED);
    Test.assertEqual(model.remainingMs(9999999), 3900000);
    Test.assertEqual(model.sectorAngle(9999999), 360.0);
    Test.assertEqual(model.innerSectorAngle(9999999), 30.0);
    model.tap(10000000);
    Test.assertEqual(model.innerSectorAngle(10060000), 24.0);
    return true;
}

(:test)
function countdownExpiresAndTapDismisses(logger as Test.Logger) as Boolean {
    var model = new TimerModel();
    model.beginDrag(6.0);
    model.endDrag(1000);
    Test.assertEqual(model.tick(61000), true);
    Test.assertEqual(model.state, TimerModel.FINISHED);
    Test.assertEqual(model.tick(62000), false);
    model.tap(63000);
    Test.assertEqual(model.state, TimerModel.IDLE);
    return true;
}
