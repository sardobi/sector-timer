import Toybox.Lang;

class TimerSession {
    var model as TimerModel;
    var modelTime as Number = 0;
    var error as Boolean = false;
    private var _platform as TimerPlatform;
    private var _record as TimerRecord;

    function initialize(platform as TimerPlatform) {
        _platform = platform;
        _record = platform.load();
        model = new TimerModel();
        restoreModel();
    }

    function open() as Boolean {
        reload();
        var expired = tick();
        if (_record.state == TimerState.RUNNING) {
            armOrPause();
        } else {
            _platform.disarm();
        }
        return expired;
    }

    function reload() as Void {
        _record = _platform.load();
        if (model.state != TimerState.SETTING) {
            restoreModel();
        }
    }

    function beginDrag(angle as Float) as Void {
        reload();
        model.beginAdjustment(angle, modelTime);
    }

    function moveDrag(angle as Float) as Void {
        model.moveDrag(angle);
    }

    function endDrag() as Void {
        if (model.state != TimerState.SETTING) {
            return;
        }
        var duration = model.remainingMs(_platform.uptime());
        model.endDrag(_platform.uptime());
        if (duration == 0) {
            cancel();
        } else {
            start(duration);
        }
    }

    function toggle() as Void {
        if (model.state == TimerState.SETTING) {
            return;
        }
        if (_record.state == TimerState.RUNNING) {
            var remaining = _record.remainingAt(_platform.now());
            if (remaining > 0) {
                commit(new TimerRecord(TimerState.PAUSED, remaining, 0, _record.nextGeneration()));
            }
        } else if (_record.state == TimerState.PAUSED) {
            start(_record.durationMs);
        } else if (_record.state == TimerState.FINISHED) {
            cancel();
        }
    }

    function cancel() as Void {
        commit(new TimerRecord(TimerState.IDLE, 0, 0, _record.nextGeneration()));
    }

    function leave() as Void {
        // An unfinished drag is only a preview, not a replacement timer.
        abortDrag();
    }

    function recordForegroundAlarm() as Void {
        _platform.trace("foreground vibrate returned g=" + _record.generation);
    }

    function abortDrag() as Void {
        restoreModel();
    }

    function tick() as Boolean {
        var expired = false;
        if (_record.isDue(_platform.now())) {
            expired = TimerExpiry.claim(_platform, _record.generation) != null;
            reload();
        }
        if (model.state != TimerState.SETTING) {
            restoreModel();
        }
        return expired;
    }

    private function start(duration as Number) as Void {
        var deadline = _platform.now() + (duration + 999) / 1000;
        commit(new TimerRecord(TimerState.RUNNING, duration, deadline, _record.nextGeneration()));
    }

    private function commit(record as TimerRecord) as Void {
        _platform.save(record);
        _record = record;
        error = false;
        if (record.state == TimerState.RUNNING) {
            armOrPause();
        } else {
            _platform.disarm();
        }
        restoreModel();
    }

    private function armOrPause() as Void {
        if (!_platform.arm(_record.deadline)) {
            var remaining = _record.remainingAt(_platform.now());
            if (remaining == 0) {
                _platform.disarm();
                return;
            }
            // Keep a rejected alarm visibly paused rather than pretending it is armed.
            _record = new TimerRecord(TimerState.PAUSED, remaining, 0, _record.nextGeneration());
            _platform.save(_record);
            _platform.disarm();
            error = true;
            restoreModel();
        }
    }

    private function restoreModel() as Void {
        modelTime = _platform.uptime();
        model.restore(_record.state, _record.remainingAt(_platform.now()), modelTime);
    }
}
