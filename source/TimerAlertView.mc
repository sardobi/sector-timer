import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module AlertExplanation {
    function resource(settings as TimerAlertSettings) as ResourceId {
        var code = settings.warningCode();
        if (code == (AlertSettings.DND | AlertSettings.VIBRATION_OFF)) {
            return Rez.Strings.AlertBoth;
        }
        if (code == AlertSettings.DND) {
            return Rez.Strings.AlertDnd;
        }
        if (code == AlertSettings.VIBRATION_OFF) {
            return Rez.Strings.AlertVibration;
        }
        if (settings.doNotDisturb == null || settings.vibrateOn == null) {
            return Rez.Strings.AlertUnknown;
        }
        return Rez.Strings.AlertNoWarning;
    }

    function activityStatus(state as Number?) as ResourceId {
        if (state == Activity.TIMER_STATE_ON) {
            return Rez.Strings.ActivityRunning;
        }
        if (state == Activity.TIMER_STATE_STOPPED) {
            return Rez.Strings.ActivityStopped;
        }
        if (state == Activity.TIMER_STATE_PAUSED) {
            return Rez.Strings.ActivityAutoPaused;
        }
        if (state == Activity.TIMER_STATE_OFF) {
            return Rez.Strings.ActivityNone;
        }
        return Rez.Strings.ActivityUnknown;
    }
}

class TimerAlertView extends WatchUi.View {
    private var _environment as TimerEnvironment;
    private var _activityPage as Boolean = false;

    function initialize(environment as TimerEnvironment) {
        View.initialize();
        _environment = environment;
        _environment.refresh();
        _activityPage = _environment.showsActivityIndicator();
    }

    function nextPage() as Void {
        _activityPage = !_activityPage;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        _environment.refresh();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        dc.drawText(cx, 38, Graphics.FONT_XTINY,
            WatchUi.loadResource(_activityPage ? Rez.Strings.ActivitySettingsTitle : Rez.Strings.AlertSettingsTitle),
            Graphics.TEXT_JUSTIFY_CENTER);
        if (_activityPage) {
            dc.drawText(cx, 95, Graphics.FONT_XTINY,
                WatchUi.loadResource(AlertExplanation.activityStatus(_environment.activityState)),
                Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx, 135, Graphics.FONT_XTINY,
                WatchUi.loadResource(Rez.Strings.ActivityAlertInfo),
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, 95, Graphics.FONT_XTINY,
                WatchUi.loadResource(AlertExplanation.resource(_environment.settings)),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(cx, dc.getHeight() - 85, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.AlertNavigation), Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class TimerAlertDelegate extends WatchUi.InputDelegate {
    private var _view as TimerAlertView;

    function initialize(view as TimerAlertView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        _view.nextPage();
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        _view.nextPage();
        return true;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _view.nextPage();
            return true;
        }
        return false;
    }
}
