import Toybox.Lang;
import Toybox.Math;

module Dial {
    const LAP_MS = 3600000;
    const MAX_MS = TimerState.MAX_MS;
    const MAX_ANGLE = MAX_MS * 360.0 / LAP_MS;
    const HANDLE_TOLERANCE_DEGREES = 18.0;

    function endpointAngle(remaining as Number) as Float {
        return ((remaining % LAP_MS) * 360.0 / LAP_MS).toFloat();
    }

    function pointAt(angle as Float, radius as Number, cx as Number, cy as Number) as [Number, Number] {
        var radians = angle * Math.PI / 180.0;
        return [
            Math.round(cx - Math.sin(radians) * radius).toNumber(),
            Math.round(cy - Math.cos(radians) * radius).toNumber()
        ];
    }

    function isNearEndpoint(angle as Float, endpoint as Float) as Boolean {
        var difference = angle - endpoint;
        if (difference < 0.0) {
            difference = -difference;
        }
        return difference <= HANDLE_TOLERANCE_DEGREES ||
            difference >= 360.0 - HANDLE_TOLERANCE_DEGREES;
    }

    function angleAt(x as Number, y as Number, cx as Number, cy as Number) as Float {
        var angle = Math.atan2((cx - x).toFloat(), (cy - y).toFloat()) * 180.0 / Math.PI;
        return (angle < 0 ? angle + 360.0 : angle).toFloat();
    }

    function clampAngle(angle as Float) as Float {
        return angle < 0.0 ? 0.0 : (angle > MAX_ANGLE ? MAX_ANGLE : angle);
    }

    function durationAt(angle as Float) as Number {
        return Math.round(clampAngle(angle) / 6.0).toNumber() * 60000;
    }

}

class TimerModel {
    static const IDLE = TimerState.IDLE;
    static const SETTING = TimerState.SETTING;
    static const RUNNING = TimerState.RUNNING;
    static const PAUSED = TimerState.PAUSED;
    static const FINISHED = TimerState.FINISHED;

    var state as Number = IDLE;
    private var _durationMs as Number = 0;
    private var _startedAt as Number = 0;
    private var _lastAngle as Float = 0.0;
    private var _dragAngle as Float = 0.0;

    function initialize() {
    }

    function restore(savedState as Number, remaining as Number, now as Number) as Void {
        state = savedState;
        _durationMs = remaining;
        _startedAt = now;
    }

    function beginDrag(angle as Float) as Void {
        state = SETTING;
        _lastAngle = angle;
        _dragAngle = Dial.clampAngle(angle);
        _durationMs = Dial.durationAt(_dragAngle);
    }

    function beginAdjustment(angle as Float, now as Number) as Boolean {
        var remaining = remainingMs(now);
        if (!Dial.isNearEndpoint(angle, Dial.endpointAngle(remaining))) {
            return false;
        }
        if (state == RUNNING || state == PAUSED) {
            _durationMs = remaining;
            _dragAngle = (_durationMs * 360.0 / Dial.LAP_MS).toFloat();
            _lastAngle = angle;
            state = SETTING;
        } else {
            // Grab the empty endpoint, not an absolute 59-minute dial position.
            beginDrag(0.0);
            _lastAngle = angle;
        }
        return true;
    }

    function moveDrag(angle as Float) as Void {
        if (state != SETTING) {
            return;
        }
        // Accumulate travel across twelve o'clock instead of wrapping to zero.
        var delta = angle - _lastAngle;
        if (delta == 0.0) {
            return;
        }
        if (delta > 180.0) {
            delta -= 360.0;
        } else if (delta < -180.0) {
            delta += 360.0;
        }
        _dragAngle = Dial.clampAngle(_dragAngle + delta);
        _lastAngle = angle;
        _durationMs = Dial.durationAt(_dragAngle);
    }

    function endDrag(now as Number) as Void {
        if (state != SETTING) {
            return;
        }
        if (_durationMs == 0) {
            reset();
        } else {
            _startedAt = now;
            state = RUNNING;
        }
    }

    function remainingMs(now as Number) as Number {
        if (state != RUNNING) {
            return _durationMs;
        }
        // System.getTimer is a signed 32-bit uptime clock. Long arithmetic handles
        // both signed rollover and the full wrap without relying on callback frequency.
        var elapsed = (now.toLong() - _startedAt.toLong() + 4294967296l) % 4294967296l;
        return elapsed >= _durationMs ? 0 : _durationMs - elapsed.toNumber();
    }

    function sectorAngle(now as Number) as Float {
        var remaining = remainingMs(now);
        return remaining >= Dial.LAP_MS ? 360.0 : (remaining * 360.0 / Dial.LAP_MS).toFloat();
    }

    function innerSectorAngle(now as Number) as Float {
        var extra = remainingMs(now) - Dial.LAP_MS;
        return extra <= 0 ? 0.0 : (extra >= Dial.LAP_MS ? 360.0 : (extra * 360.0 / Dial.LAP_MS).toFloat());
    }

    function innermostSectorAngle(now as Number) as Float {
        var extra = remainingMs(now) - 2 * Dial.LAP_MS;
        return extra <= 0 ? 0.0 : (extra >= Dial.LAP_MS ? 360.0 : (extra * 360.0 / Dial.LAP_MS).toFloat());
    }

    function tick(now as Number) as Boolean {
        if (state == RUNNING && remainingMs(now) == 0) {
            _durationMs = 0;
            state = FINISHED;
            return true;
        }
        return false;
    }

    function togglePause(now as Number) as Void {
        if (state == RUNNING) {
            _durationMs = remainingMs(now);
            state = _durationMs == 0 ? FINISHED : PAUSED;
        } else if (state == PAUSED) {
            _startedAt = now;
            state = RUNNING;
        }
    }

    function tap(now as Number) as Void {
        if (state == FINISHED) {
            reset();
        } else {
            togglePause(now);
        }
    }

    function reset() as Void {
        state = IDLE;
        _durationMs = 0;
        _startedAt = 0;
    }
}
