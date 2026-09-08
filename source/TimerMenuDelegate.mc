import Toybox.Lang;
import Toybox.WatchUi;

class TimerMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _view as TimerView;

    function initialize(view as TimerView) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :cancel) {
            _view.cancelTimer();
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item.getId() == :alarmLog) {
            var logView = new TimerDiagnosticsView(new TimerDiagnostics().readEntries());
            WatchUi.pushView(logView, new TimerDiagnosticsDelegate(logView), WatchUi.SLIDE_UP);
        }
    }
}
