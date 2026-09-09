import Toybox.Activity;
import Toybox.Lang;

class TimerEnvironment {
    var settings as TimerAlertSettings;
    var activityState as Number? = null;
    private var _session as TimerSession;
    private var _lastSummary as String? = null;

    function initialize(session as TimerSession) {
        _session = session;
        settings = new TimerAlertSettings(null, null);
    }

    function readSettings() as TimerAlertSettings {
        return AlertSettings.read();
    }

    function readActivityState() as Number? {
        var info = Activity.getActivityInfo();
        return info has :timerState ? info.timerState : null;
    }

    function hasActivity() as Boolean {
        return activityState == Activity.TIMER_STATE_ON ||
            activityState == Activity.TIMER_STATE_STOPPED ||
            activityState == Activity.TIMER_STATE_PAUSED;
    }

    function showsActivityIndicator() as Boolean {
        return settings.warningCode() == 0 && hasActivity();
    }

    function refresh() as Boolean {
        var oldCode = settings.warningCode();
        var hadActivity = hasActivity();
        settings = readSettings();
        activityState = readActivityState();
        var summary = settings.summary() + " activityProbe=" + activityState;
        if (_lastSummary == null || !_lastSummary.equals(summary)) {
            _session.recordEnvironment(summary);
            _lastSummary = summary;
        }
        return oldCode != settings.warningCode() || hadActivity != hasActivity();
    }
}
