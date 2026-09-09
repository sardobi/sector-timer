import Toybox.Lang;
import Toybox.Test;

(:background)
class AlertTestPlatform extends FakeTimerPlatform {
    var events as Array<String> = [];

    function initialize() {
        FakeTimerPlatform.initialize();
    }

    function trace(event as String) as Void {
        events.add(event);
    }
}

class FakeTimerEnvironment extends TimerEnvironment {
    var current as TimerAlertSettings;
    var reportedActivity as Number? = null;
    var reads as Number = 0;

    function initialize(session as TimerSession) {
        TimerEnvironment.initialize(session);
        current = new TimerAlertSettings(false, true);
    }

    function readSettings() as TimerAlertSettings {
        reads++;
        return current;
    }

    function readActivityState() as Number? {
        return reportedActivity;
    }
}

(:test)
function alertWarningsDistinguishDndVibrationAndUnknown(logger as Test.Logger) as Boolean {
    Test.assertEqual(new TimerAlertSettings(false, true).warningCode(), 0);
    Test.assertEqual(new TimerAlertSettings(true, true).warningCode(), AlertSettings.DND);
    Test.assertEqual(new TimerAlertSettings(false, false).warningCode(), AlertSettings.VIBRATION_OFF);
    Test.assertEqual(new TimerAlertSettings(true, false).warningCode(),
        AlertSettings.DND | AlertSettings.VIBRATION_OFF);
    Test.assertEqual(new TimerAlertSettings(null, null).warningCode(), 0);
    Test.assertEqual(new TimerAlertSettings(null, false).warningCode(), AlertSettings.VIBRATION_OFF);
    Test.assertEqual(new TimerAlertSettings(true, null).warningCode(), AlertSettings.DND);
    return true;
}

(:test)
function alertExplanationMatchesEachDetectedReason(logger as Test.Logger) as Boolean {
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(true, true)), Rez.Strings.AlertDnd);
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(false, false)), Rez.Strings.AlertVibration);
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(true, false)), Rez.Strings.AlertBoth);
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(false, true)), Rez.Strings.AlertNoWarning);
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(null, true)), Rez.Strings.AlertUnknown);
    Test.assertEqual(AlertExplanation.resource(new TimerAlertSettings(false, null)), Rez.Strings.AlertUnknown);
    return true;
}

(:test)
function environmentLogsOnlyChangesWithoutTreatingActivityAsWarning(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    var environment = new FakeTimerEnvironment(session);
    Test.assertEqual(environment.refresh(), false);
    Test.assertEqual(platform.events.size(), 1);
    environment.refresh();
    Test.assertEqual(platform.events.size(), 1);
    environment.reportedActivity = 3;
    Test.assert(environment.refresh());
    Test.assert(environment.showsActivityIndicator());
    Test.assertEqual(environment.settings.warningCode(), 0);
    Test.assertEqual(platform.events.size(), 2);
    Test.assertEqual(platform.events[1], "settings dnd=false vibration=true activityProbe=3");
    environment.reportedActivity = 1;
    Test.assertEqual(environment.refresh(), false);
    Test.assert(environment.showsActivityIndicator());
    environment.reportedActivity = 2;
    Test.assertEqual(environment.refresh(), false);
    Test.assert(environment.showsActivityIndicator());
    environment.reportedActivity = 0;
    Test.assert(environment.refresh());
    Test.assertEqual(environment.showsActivityIndicator(), false);
    environment.reportedActivity = null;
    environment.refresh();
    Test.assert(environment.activityState == null);
    Test.assertEqual(platform.events.size(), 6);
    Test.assertEqual(platform.writes, 0);
    return true;
}

(:test)
function environmentWarningChangesDoNotPauseOrRescheduleTimer(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    session.beginDrag(0.0);
    session.moveDrag(6.0);
    session.endDrag();
    var writes = platform.writes;
    var environment = new FakeTimerEnvironment(session);
    environment.refresh();
    environment.current = new TimerAlertSettings(true, false);
    Test.assert(environment.refresh());
    Test.assertEqual(environment.refresh(), false);
    environment.current = new TimerAlertSettings(false, true);
    Test.assert(environment.refresh());
    environment.reportedActivity = 3;
    Test.assert(environment.refresh());
    environment.reportedActivity = 1;
    environment.refresh();
    environment.reportedActivity = 0;
    Test.assert(environment.refresh());
    Test.assertEqual(platform.saved.state, TimerState.RUNNING);
    Test.assertEqual(platform.writes, writes);
    Test.assert(platform.armed == 100060);
    return true;
}

(:test)
function warningTouchTargetDoesNotStealCentreOrEndpoint(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    var environment = new FakeTimerEnvironment(session);
    var view = new TimerView(session, environment);
    Test.assertEqual(view.isEnvironmentIcon(195, 314), false);
    environment.current = new TimerAlertSettings(true, true);
    environment.refresh();
    Test.assert(view.isEnvironmentIcon(195, 314));
    Test.assertEqual(view.isEnvironmentIcon(195, 195), false);
    Test.assertEqual(view.isEnvironmentIcon(195, 366), false);
    Test.assertEqual(view.beginDrag(195, 314), false);
    Test.assertEqual(session.model.state, TimerState.IDLE);
    Test.assert(view.beginDrag(195, 24));
    session.moveDrag(90.0);
    session.moveDrag(180.0);
    session.endDrag();
    Test.assert(view.beginDrag(195, 366));
    session.abortDrag();
    view.stop();
    return true;
}

(:test)
function visibleTimerRefreshesSettingsWhileIdle(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    var environment = new FakeTimerEnvironment(session);
    var view = new TimerView(session, environment);
    view.onShow();
    var reads = environment.reads;
    view.onTick();
    Test.assertEqual(environment.reads, reads);
    environment.current = new TimerAlertSettings(true, true);
    platform.ticks += 1000;
    view.onTick();
    Test.assertEqual(environment.reads, reads + 1);
    Test.assert(view.isEnvironmentIcon(195, 314));
    view.onHide();
    environment.current = new TimerAlertSettings(false, true);
    platform.ticks += 1000;
    view.onTick();
    Test.assertEqual(environment.reads, reads + 1);
    view.onShow();
    Test.assertEqual(view.isEnvironmentIcon(195, 314), false);
    view.stop();
    return true;
}

(:test)
function activityIndicatorRejectsUnknownStatesAndYieldsToWarnings(logger as Test.Logger) as Boolean {
    var environment = new FakeTimerEnvironment(new TimerSession(new AlertTestPlatform()));
    var inactiveStates = [null, 0, 99];
    for (var i = 0; i < inactiveStates.size(); i++) {
        environment.reportedActivity = inactiveStates[i];
        environment.refresh();
        Test.assertEqual(environment.hasActivity(), false);
        Test.assertEqual(environment.showsActivityIndicator(), false);
    }
    var warnings = [
        new TimerAlertSettings(true, true),
        new TimerAlertSettings(false, false),
        new TimerAlertSettings(true, false)
    ];
    for (var state = 1; state <= 3; state++) {
        environment.reportedActivity = state;
        environment.current = new TimerAlertSettings(false, true);
        environment.refresh();
        Test.assert(environment.hasActivity());
        Test.assert(environment.showsActivityIndicator());
        for (var i = 0; i < warnings.size(); i++) {
            environment.current = warnings[i];
            environment.refresh();
            Test.assert(environment.hasActivity());
            Test.assertEqual(environment.showsActivityIndicator(), false);
        }
    }
    return true;
}

(:test)
function activityStatusExplainsRunningPausedEndedAndUnknown(logger as Test.Logger) as Boolean {
    Test.assertEqual(AlertExplanation.activityStatus(3), Rez.Strings.ActivityRunning);
    Test.assertEqual(AlertExplanation.activityStatus(1), Rez.Strings.ActivityStopped);
    Test.assertEqual(AlertExplanation.activityStatus(2), Rez.Strings.ActivityAutoPaused);
    Test.assertEqual(AlertExplanation.activityStatus(0), Rez.Strings.ActivityNone);
    Test.assertEqual(AlertExplanation.activityStatus(null), Rez.Strings.ActivityUnknown);
    Test.assertEqual(AlertExplanation.activityStatus(99), Rez.Strings.ActivityUnknown);
    return true;
}

(:test)
function activityIndicatorRefreshesAndKeepsCentreAndHandleAccessible(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    var environment = new FakeTimerEnvironment(session);
    var view = new TimerView(session, environment);
    view.onShow();
    environment.reportedActivity = 3;
    platform.ticks += 1000;
    view.onTick();
    Test.assert(view.isEnvironmentIcon(195, 314));
    Test.assertEqual(view.isEnvironmentIcon(195, 195), false);
    Test.assertEqual(view.isEnvironmentIcon(195, 366), false);
    Test.assertEqual(view.beginDrag(195, 314), false);
    Test.assertEqual(session.model.state, TimerState.IDLE);
    Test.assert(view.beginDrag(195, 24));
    session.moveDrag(90.0);
    session.moveDrag(180.0);
    session.endDrag();
    Test.assert(view.beginDrag(195, 366));
    session.abortDrag();
    view.toggle();
    Test.assertEqual(session.model.state, TimerState.PAUSED);
    environment.reportedActivity = 1;
    platform.ticks += 1000;
    view.onTick();
    Test.assert(view.isEnvironmentIcon(195, 314));
    environment.reportedActivity = 0;
    platform.ticks += 1000;
    view.onTick();
    Test.assertEqual(view.isEnvironmentIcon(195, 314), false);
    Test.assertEqual(session.model.state, TimerState.PAUSED);
    view.stop();
    return true;
}

(:test)
function dragRefreshesDoNotPollDeviceSettings(logger as Test.Logger) as Boolean {
    var platform = new AlertTestPlatform();
    var session = new TimerSession(platform);
    var environment = new FakeTimerEnvironment(session);
    var view = new TimerView(session, environment);
    view.onShow();
    var reads = environment.reads;
    Test.assert(view.beginDrag(195, 24));
    environment.reportedActivity = 3;
    for (var i = 1; i <= 180; i++) {
        session.moveDrag(i.toFloat());
        platform.ticks += 40;
        view.refresh();
        view.onTick();
    }
    Test.assertEqual(environment.reads, reads);
    session.endDrag();
    view.refresh();
    Test.assertEqual(environment.reads, reads + 1);
    Test.assert(environment.showsActivityIndicator());
    for (var i = 0; i < 10; i++) {
        view.refresh();
    }
    Test.assertEqual(environment.reads, reads + 1);
    view.stop();
    return true;
}

(:test)
function enlargedSymbolTargetsProtectCentreAndRim(logger as Test.Logger) as Boolean {
    var session = new TimerSession(new AlertTestPlatform());
    var environment = new FakeTimerEnvironment(session);
    var view = new TimerView(session, environment);
    environment.reportedActivity = 3;
    for (var warning = 0; warning < 2; warning++) {
        environment.current = new TimerAlertSettings(warning == 1, true);
        environment.refresh();
        Test.assert(view.isEnvironmentIcon(157, 314));
        Test.assert(view.isEnvironmentIcon(233, 314));
        Test.assert(view.isEnvironmentIcon(195, 286));
        Test.assert(view.isEnvironmentIcon(195, 345));
        Test.assertEqual(view.beginDrag(233, 314), false);
        Test.assertEqual(view.isEnvironmentIcon(150, 314), false);
        Test.assertEqual(view.isEnvironmentIcon(195, 284), false);
        Test.assertEqual(view.isEnvironmentIcon(195, 350), false);
        for (var angle = 0; angle < 360; angle += 5) {
            var centreEdge = Dial.pointAt(angle.toFloat(), 89, 195, 195);
            var rim = Dial.pointAt(angle.toFloat(), 160, 195, 195);
            Test.assertEqual(view.isEnvironmentIcon(centreEdge[0], centreEdge[1]), false);
            Test.assertEqual(view.isEnvironmentIcon(rim[0], rim[1]), false);
        }
    }
    Test.assert(view.beginDrag(195, 24));
    session.moveDrag(90.0);
    session.moveDrag(180.0);
    session.endDrag();
    Test.assert(view.beginDrag(195, 350));
    session.abortDrag();
    environment.current = new TimerAlertSettings(false, true);
    environment.reportedActivity = 0;
    environment.refresh();
    Test.assertEqual(view.isEnvironmentIcon(233, 314), false);
    view.stop();
    return true;
}
