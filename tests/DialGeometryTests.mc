import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

(:test)
function dialPointsShareRoundedRimCoordinates(logger as Test.Logger) as Boolean {
    var top = Dial.pointAt(0.0, 171, 195, 195);
    Test.assertEqual(top[0], 195);
    Test.assertEqual(top[1], 24);
    var left = Dial.pointAt(90.0, 171, 195, 195);
    Test.assertEqual(left[0], 24);
    Test.assertEqual(left[1], 195);
    var bottom = Dial.pointAt(180.0, 171, 195, 195);
    Test.assertEqual(bottom[0], 195);
    Test.assertEqual(bottom[1], 366);
    var right = Dial.pointAt(270.0, 171, 195, 195);
    Test.assertEqual(right[0], 366);
    Test.assertEqual(right[1], 195);
    var threeMinutes = Dial.pointAt(18.0, 171, 195, 195);
    Test.assertEqual(threeMinutes[0], 142);
    Test.assertEqual(threeMinutes[1], 32);
    return true;
}

(:test)
function handleRemainsOnRimThroughHourBoundaries(logger as Test.Logger) as Boolean {
    var remaining = [0, 1000, 59000, 180000, 900000, 3599000, 3600000,
        3601000, 5400000, 7200000, 9000000, TimerState.MAX_MS];
    for (var i = 0; i < remaining.size(); i++) {
        var point = Dial.pointAt(Dial.endpointAngle(remaining[i]), 171, 195, 195);
        var dx = point[0] - 195;
        var dy = point[1] - 195;
        var distance = Math.sqrt(dx * dx + dy * dy);
        // Rounding each coordinate can move a point by at most sqrt(0.5).
        Test.assert(distance >= 170.29 && distance <= 171.71);
    }
    return true;
}

(:test)
function redSectorAndHandleUseTheSameEndpoint(logger as Test.Logger) as Boolean {
    var remaining = [1000, 59000, 180000, 899000, 1800000, 3599000];
    var model = new TimerModel();
    for (var i = 0; i < remaining.size(); i++) {
        model.restore(TimerState.PAUSED, remaining[i], 0);
        var sector = Dial.pointAt(model.sectorAngle(0), 171, 195, 195);
        var handle = Dial.pointAt(Dial.endpointAngle(model.remainingMs(0)), 171, 195, 195);
        Test.assertEqual(handle[0], sector[0]);
        Test.assertEqual(handle[1], sector[1]);
    }
    return true;
}
