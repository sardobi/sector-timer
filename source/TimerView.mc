import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class TimerView extends WatchUi.View {
    var model as TimerModel;
    var centerX as Number = 195;
    var centerY as Number = 195;
    var radius as Number = 171;
    private var _timer as Timer.Timer;
    private var _lastSecond as Number = -1;
    private var _lastState as Number = -1;
    private var _visible as Boolean = false;
    private var _timerRunning as Boolean = false;

    function initialize(timerModel as TimerModel) {
        View.initialize();
        model = timerModel;
        _timer = new Timer.Timer();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        centerX = dc.getWidth() / 2;
        centerY = dc.getHeight() / 2;
        radius = (dc.getWidth() * 0.44).toNumber();
    }

    function onShow() as Void {
        _visible = true;
        refresh();
        if (!_timerRunning) {
            _timer.start(method(:onTick), 250, true);
            _timerRunning = true;
        }
    }

    function onHide() as Void {
        _visible = false;
    }

    function stop() as Void {
        _timer.stop();
        _timerRunning = false;
    }

    function onTick() as Void {
        var now = System.getTimer();
        if (model.tick(now)) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0, 250),
                new Attention.VibeProfile(100, 500),
                new Attention.VibeProfile(0, 250),
                new Attention.VibeProfile(100, 750)
            ]);
        }
        var second = model.remainingMs(now) / 1000;
        if (_visible && (second != _lastSecond || model.state != _lastState)) {
            WatchUi.requestUpdate();
        }
    }

    function refresh() as Void {
        _lastState = -1;
        onTick();
    }

    function toggle() as Void {
        onTick();
        model.tap(System.getTimer());
        refresh();
    }

    function isDial(x as Number, y as Number) as Boolean {
        var dx = x - centerX;
        var dy = y - centerY;
        var distanceSquared = dx * dx + dy * dy;
        return distanceSquared >= 90 * 90 && distanceSquared <= (radius + 20) * (radius + 20);
    }

    function isCenter(x as Number, y as Number) as Boolean {
        var dx = x - centerX;
        var dy = y - centerY;
        return dx * dx + dy * dy < 90 * 90;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var now = System.getTimer();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, radius);

        dc.setColor(0xEF3038, Graphics.COLOR_TRANSPARENT);
        drawSector(dc, model.sectorAngle(now), radius);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        drawSector(dc, model.innerSectorAngle(now), (radius * 0.67).toNumber());

        if (model.state == TimerModel.IDLE || model.state == TimerModel.SETTING) {
            drawTicks(dc);
        }
        if (model.state == TimerModel.SETTING) {
            var angle = model.remainingMs(now) * 2.0 * Math.PI / Dial.LAP_MS;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX - Math.sin(angle) * (radius - 8),
                centerY - Math.cos(angle) * (radius - 8), 5);
        } else if (model.state == TimerModel.PAUSED) {
            dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, 29);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(centerX - 13, centerY - 15, 8, 30);
            dc.fillRectangle(centerX + 5, centerY - 15, 8, 30);
        } else if (model.state == TimerModel.FINISHED) {
            drawBell(dc);
        }
        _lastSecond = model.remainingMs(now) / 1000;
        _lastState = model.state;
    }

    private function drawTicks(dc as Graphics.Dc) as Void {
        for (var minute = 0; minute < 60; minute++) {
            var radians = minute * Math.PI / 30.0;
            var inner = radius + (minute % 5 == 0 ? 3 : 8);
            var outer = radius + 13;
            dc.setColor(minute % 5 == 0 ? Graphics.COLOR_WHITE : 0x888888, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(minute % 5 == 0 ? 2 : 1);
            dc.drawLine(
                centerX - Math.sin(radians) * inner, centerY - Math.cos(radians) * inner,
                centerX - Math.sin(radians) * outer, centerY - Math.cos(radians) * outer
            );
        }
        dc.setPenWidth(1);
    }

    private function drawBell(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY - 7, 15);
        dc.fillRectangle(centerX - 15, centerY - 7, 30, 20);
        dc.fillRectangle(centerX - 19, centerY + 12, 38, 5);
        dc.fillCircle(centerX, centerY + 24, 4);
    }

    private function drawSector(dc as Graphics.Dc, angle as Float, sectorRadius as Number) as Void {
        if (angle <= 0.0) {
            return;
        }
        if (angle >= 360.0) {
            dc.fillCircle(centerX, centerY, sectorRadius);
            return;
        }
        // Small triangles respect the 64-point polygon limit, even for sectors >180 degrees.
        for (var start = 0.0; start < angle; start += 4.0) {
            var end = start + 4.0 < angle ? start + 4.0 : angle;
            var a = start * Math.PI / 180.0;
            var b = end * Math.PI / 180.0;
            dc.fillPolygon([
                [centerX, centerY],
                [centerX - Math.sin(a) * sectorRadius, centerY - Math.cos(a) * sectorRadius],
                [centerX - Math.sin(b) * sectorRadius, centerY - Math.cos(b) * sectorRadius]
            ]);
        }
    }
}
