import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class VisualTimerApp extends Application.AppBase {
    private var _view as TimerView?;

    function initialize() {
        AppBase.initialize();
    }

    // AppBase is shared with the service, but this callback is foreground-only.
    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new TimerView(new TimerSession(new TimerPlatform()));
        _view = view;
        System.println("Visual Timer: foreground restored state " + view.model.state);
        return [view, new TimerDelegate(view)];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new TimerService()];
    }

    (:typecheck(disableBackgroundCheck))
    function onStorageChanged() as Void {
        if (_view != null) {
            _view.reloadSession();
        }
    }

    function onBackgroundData(data as PersistableType) as Void {
        onStorageChanged();
    }

    (:typecheck(disableBackgroundCheck))
    function onStop(state as Dictionary?) as Void {
        if (_view != null) {
            _view.stop();
            System.println("Visual Timer: foreground stopped");
        }
    }
}
