import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class VisualTimerApp extends Application.AppBase {
    private var _view as TimerView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new TimerView(new TimerModel());
        _view = view;
        return [view, new TimerDelegate(view)];
    }

    function onStop(state as Dictionary?) as Void {
        if (_view != null) {
            _view.stop();
        }
    }
}
