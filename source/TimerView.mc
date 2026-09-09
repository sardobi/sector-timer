import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class TimerView extends WatchUi.View {
    // Shared glyph height in pixels; both icons scale from this value.
    const STATUS_ICON_HEIGHT = 144;
    const PAUSE_BACKDROP_PADDING = 16;
    const HUB_RADIUS = 12;
    const SECOND_HOUR_COLOR = 0xA050E8;
    const THIRD_HOUR_COLOR = 0x3088FF;
    const SECOND_HOUR_RADIUS_SCALE = 0.67;
    const THIRD_HOUR_RADIUS_SCALE = 0.40;
    const IDLE_ARROW_RADIUS_SCALE = 0.80;
    const ALERT_ICON_HEIGHT = 24;
    const ALERT_TOUCH_RADIUS = 44;
    const ALERT_RIM_MARGIN = 20;
    const ALERT_OFFSET_SCALE = 0.70;

    var model as TimerModel;
    var session as TimerSession;
    var centerX as Number = 195;
    var centerY as Number = 195;
    var radius as Number = 171;
    var environment as TimerEnvironment;
    private var _lastEnvironmentSecond as Number = -1;
    private var _timer as Timer.Timer;
    private var _lastSecond as Number = -1;
    private var _lastState as Number = -1;
    private var _visible as Boolean = false;
    private var _timerRunning as Boolean = false;
    private var _pendingAlarm as Boolean = false;

    function initialize(timerSession as TimerSession, timerEnvironment as TimerEnvironment?) {
        View.initialize();
        session = timerSession;
        model = session.model;
        environment = timerEnvironment == null ? new TimerEnvironment(session) : timerEnvironment;
        _pendingAlarm = session.open();
        environment.refresh();
        _timer = new Timer.Timer();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        centerX = dc.getWidth() / 2;
        centerY = dc.getHeight() / 2;
        radius = (dc.getWidth() * 0.44).toNumber();
    }

    function onShow() as Void {
        _visible = true;
        _lastEnvironmentSecond = -1;
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
        _visible = false;
        _timer.stop();
        _timerRunning = false;
        // Shutdown must not consume an expiry then cut its foreground vibration short.
        session.leave();
    }

    function reloadSession() as Void {
        session.reload();
        refresh();
    }

    function onTick() as Void {
        if (session.tick() || _pendingAlarm) {
            playAlarm();
            _pendingAlarm = false;
        }
        var second = model.remainingMs(session.modelTime) / 1000;
        var environmentChanged = false;
        var environmentSecond = session.modelTime / 1000;
        // Device queries must not run in the high-frequency drag/redraw path.
        if (_visible && model.state != TimerModel.SETTING &&
            environmentSecond != _lastEnvironmentSecond) {
            environmentChanged = environment.refresh();
            _lastEnvironmentSecond = environmentSecond;
        }
        if (_visible && (environmentChanged || second != _lastSecond || model.state != _lastState)) {
            WatchUi.requestUpdate();
        }
        if (_visible && session.error) {
            session.error = false;
            WatchUi.pushView(new TimerNoticeView(), new TimerNoticeDelegate(), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    private function playAlarm() as Void {
        System.println("Sector Timer: foreground alarm");
        Attention.vibrate([
            new Attention.VibeProfile(100, 500),
            new Attention.VibeProfile(0, 250),
            new Attention.VibeProfile(100, 500),
            new Attention.VibeProfile(0, 250),
            new Attention.VibeProfile(100, 750)
        ]);
        session.recordForegroundAlarm();
    }

    function refresh() as Void {
        _lastState = -1;
        onTick();
    }

    function toggle() as Void {
        onTick();
        session.toggle();
        refresh();
    }

    function cancelTimer() as Void {
        session.cancel();
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

    function beginDrag(x as Number, y as Number) as Boolean {
        return !isEnvironmentIcon(x, y) && isDial(x, y) &&
            session.beginDrag(Dial.angleAt(x, y, centerX, centerY));
    }

    function isEnvironmentIcon(x as Number, y as Number) as Boolean {
        if ((environment.settings.warningCode() == 0 && !environment.hasActivity()) ||
            isCenter(x, y)) {
            return false;
        }
        var dx = x - centerX;
        var dy = y - centerY;
        var innerRim = radius - ALERT_RIM_MARGIN;
        // Keep the rim available for grabbing the sector, even beside the symbol.
        if (dx * dx + dy * dy >= innerRim * innerRim) {
            return false;
        }
        dy -= (radius * ALERT_OFFSET_SCALE).toNumber();
        return dx * dx + dy * dy <= ALERT_TOUCH_RADIUS * ALERT_TOUCH_RADIUS;
    }

    function showAlertSettings() as Void {
        var view = new TimerAlertView(environment);
        WatchUi.pushView(view, new TimerAlertDelegate(view), WatchUi.SLIDE_UP);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var now = session.modelTime;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, radius);

        dc.setColor(0xEF3038, Graphics.COLOR_TRANSPARENT);
        drawSector(dc, model.sectorAngle(now), radius);
        dc.setColor(SECOND_HOUR_COLOR, Graphics.COLOR_TRANSPARENT);
        drawSector(dc, model.innerSectorAngle(now), (radius * SECOND_HOUR_RADIUS_SCALE).toNumber());
        dc.setColor(THIRD_HOUR_COLOR, Graphics.COLOR_TRANSPARENT);
        drawSector(dc, model.innermostSectorAngle(now), (radius * THIRD_HOUR_RADIUS_SCALE).toNumber());

        drawTicks(dc);
        if (model.state == TimerModel.IDLE) {
            drawIdleArrow(dc);
        }
        if (model.state != TimerModel.PAUSED && model.state != TimerModel.FINISHED) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY, HUB_RADIUS);
        }
        var handle = Dial.pointAt(Dial.endpointAngle(model.remainingMs(now)), radius, centerX, centerY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(handle[0], handle[1], 5);
        if (model.state == TimerModel.PAUSED) {
            drawPause(dc);
        } else if (model.state == TimerModel.FINISHED) {
            drawBell(dc);
        }
        if (environment.settings.warningCode() != 0) {
            drawAlertIcon(dc);
        } else if (environment.showsActivityIndicator()) {
            drawActivityIcon(dc);
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

    private function drawAlertIcon(dc as Graphics.Dc) as Void {
        var y = centerY + (radius * ALERT_OFFSET_SCALE).toNumber();
        var half = ALERT_ICON_HEIGHT / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, y, half + 5);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, y - half / 3, half / 2);
        dc.fillRectangle(centerX - half / 2, y - half / 3, half, half);
        dc.fillRectangle(centerX - half * 3 / 4, y + half / 2, half * 3 / 2, 2);
        dc.fillCircle(centerX, y + half - 1, 2);
        dc.setPenWidth(5);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - half, y + half, centerX + half, y - half);
        dc.setPenWidth(2);
        dc.setColor(0xFFCC44, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - half, y + half, centerX + half, y - half);
        dc.setPenWidth(1);
    }

    private function drawActivityIcon(dc as Graphics.Dc) as Void {
        var y = centerY + (radius * ALERT_OFFSET_SCALE).toNumber();
        var half = ALERT_ICON_HEIGHT / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, y, half + 5);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX + half / 3, y - half * 3 / 4, half / 4);
        dc.setPenWidth(2);
        dc.drawLine(centerX + half / 6, y - half / 3, centerX - half / 6, y + half / 3);
        dc.drawLine(centerX, y - half / 6, centerX - half / 2, y - half / 3);
        dc.drawLine(centerX - half / 2, y - half / 3, centerX - half * 3 / 4, y + half / 6);
        dc.drawLine(centerX, y - half / 6, centerX + half / 2, y + half / 6);
        dc.drawLine(centerX + half / 2, y + half / 6, centerX + half * 3 / 4, y - half / 6);
        dc.drawLine(centerX - half / 6, y + half / 3, centerX + half / 3, y + half / 2);
        dc.drawLine(centerX + half / 3, y + half / 2, centerX + half / 2, y + half);
        dc.drawLine(centerX - half / 6, y + half / 3, centerX - half / 2, y + half * 3 / 4);
        dc.drawLine(centerX - half / 2, y + half * 3 / 4, centerX - half, y + half / 2);
        dc.setPenWidth(1);
    }

    private function drawIdleArrow(dc as Graphics.Dc) as Void {
        var arcRadius = radius * IDLE_ARROW_RADIUS_SCALE;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        for (var degrees = 12; degrees < 92; degrees += 4) {
            var a = degrees * Math.PI / 180.0;
            var b = (degrees + 4) * Math.PI / 180.0;
            dc.drawLine(centerX - Math.sin(a) * arcRadius, centerY - Math.cos(a) * arcRadius,
                centerX - Math.sin(b) * arcRadius, centerY - Math.cos(b) * arcRadius);
        }
        var end = 92 * Math.PI / 180.0;
        var x = centerX - Math.sin(end) * arcRadius;
        var y = centerY - Math.cos(end) * arcRadius;
        var tangentX = -Math.cos(end);
        var tangentY = Math.sin(end);
        dc.fillPolygon([
            [x, y],
            [x - tangentX * 19 - tangentY * 10, y - tangentY * 19 + tangentX * 10],
            [x - tangentX * 19 + tangentY * 10, y - tangentY * 19 - tangentX * 10]
        ]);
        dc.setPenWidth(1);
    }

    private function drawPause(dc as Graphics.Dc) as Void {
        var height = STATUS_ICON_HEIGHT;
        var width = (height * 0.76).toNumber();
        var barWidth = (height * 0.23).toNumber();
        var left = centerX - width / 2;
        var top = centerY - height / 2;
        var backdropRadius = Math.sqrt(width * width + height * height) / 2;
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, centerY, backdropRadius + PAUSE_BACKDROP_PADDING);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, top, barWidth, height);
        dc.fillRectangle(left + width - barWidth, top, barWidth, height);
    }

    private function drawBell(dc as Graphics.Dc) as Void {
        var height = STATUS_ICON_HEIGHT;
        var top = centerY - height / 2;
        var domeRadius = (height * 0.30).toNumber();
        var domeY = top + domeRadius;
        var rimWidth = (height * 0.76).toNumber();
        var rimY = top + (height * 0.68).toNumber();
        var rimHeight = (height * 0.10).toNumber();
        var clapperRadius = (height * 0.08).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(centerX, domeY, domeRadius);
        dc.fillRectangle(centerX - domeRadius, domeY, domeRadius * 2, rimY - domeY);
        dc.fillRectangle(centerX - rimWidth / 2, rimY, rimWidth, rimHeight);
        dc.fillCircle(centerX, top + height - clapperRadius, clapperRadius);
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
            dc.fillPolygon([
                [centerX, centerY],
                Dial.pointAt(start, sectorRadius, centerX, centerY),
                Dial.pointAt(end, sectorRadius, centerX, centerY)
            ]);
        }
    }
}
