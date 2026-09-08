import Toybox.Application.Storage;
import Toybox.Lang;

(:background)
module TimerState {
    const IDLE = 0;
    const SETTING = 1;
    const RUNNING = 2;
    const PAUSED = 3;
    const FINISHED = 4;
    const MAX_MS = 7200000;
}

(:background)
class InvalidTimerRecordException extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }
}

(:background)
class TimerRecord {
    var state as Number;
    var durationMs as Number;
    var deadline as Number;
    var generation as Number;

    function initialize(timerState as Number, duration as Number, expires as Number, identity as Number) {
        state = timerState;
        durationMs = duration;
        deadline = expires;
        generation = identity;
    }

    function remainingAt(now as Number) as Number {
        if (state != TimerState.RUNNING) {
            return durationMs;
        }
        var remaining = (deadline.toLong() - now.toLong()) * 1000l;
        return remaining <= 0 ? 0 : (remaining >= durationMs ? durationMs : remaining.toNumber());
    }

    function isDue(now as Number) as Boolean {
        return state == TimerState.RUNNING && deadline <= now;
    }

    function nextGeneration() as Number {
        return generation == 2147483647 ? 0 : generation + 1;
    }

    function toValue() as Dictionary<Storage.KeyType, Storage.ValueType> {
        return {
            "version" => 1,
            "state" => state,
            "durationMs" => durationMs,
            "deadline" => deadline,
            "generation" => generation
        };
    }
}

(:background)
module TimerRecords {
    function empty() as TimerRecord {
        return new TimerRecord(TimerState.IDLE, 0, 0, 0);
    }

    function decode(value as Object?) as TimerRecord {
        if (value == null) {
            return empty();
        }
        if (!(value instanceof Dictionary)) {
            throw new InvalidTimerRecordException();
        }
        var version = value["version"];
        var state = value["state"];
        var duration = value["durationMs"];
        var deadline = value["deadline"];
        var generation = value["generation"];
        if (!(version instanceof Number) || version != 1 ||
            !(state instanceof Number) || !(duration instanceof Number) ||
            !(deadline instanceof Number) || !(generation instanceof Number)) {
            throw new InvalidTimerRecordException();
        }
        var active = state == TimerState.RUNNING || state == TimerState.PAUSED;
        if (generation < 0 || duration < 0 || duration > TimerState.MAX_MS ||
            (active && duration == 0) ||
            (state == TimerState.RUNNING && deadline <= 0) ||
            (state != TimerState.RUNNING && deadline != 0) ||
            (!active && (duration != 0 || (state != TimerState.IDLE && state != TimerState.FINISHED)))) {
            throw new InvalidTimerRecordException();
        }
        return new TimerRecord(state, duration, deadline, generation);
    }
}
