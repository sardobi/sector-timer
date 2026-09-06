import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class TimerDelegate extends WatchUi.InputDelegate {
    private var _view as TimerView;
    private var _dragging as Boolean = false;

    function initialize(view as TimerView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onDrag(event as WatchUi.DragEvent) as Boolean {
        var coordinates = event.getCoordinates();
        var x = coordinates[0];
        var y = coordinates[1];
        var type = event.getType();
        if (type == WatchUi.DRAG_TYPE_START) {
            _dragging = _view.isDial(x, y);
            if (_dragging) {
                _view.model.beginDrag(Dial.angleAt(x, y, _view.centerX, _view.centerY));
            }
        } else if (_dragging) {
            // Ignore unstable angles near the centre, but still accept release there.
            if (_view.isDial(x, y)) {
                _view.model.moveDrag(Dial.angleAt(x, y, _view.centerX, _view.centerY));
            }
            if (type == WatchUi.DRAG_TYPE_STOP) {
                _view.model.endDrag(System.getTimer());
                _dragging = false;
            }
        }
        _view.refresh();
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coordinates = event.getCoordinates();
        if (!_dragging && _view.isCenter(coordinates[0], coordinates[1])) {
            _view.toggle();
        }
        return true;
    }

    function onSelect() as Boolean {
        if (!_dragging) {
            _view.toggle();
        }

        return true;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        var key = event.getKey();
        if (key == WatchUi.KEY_ENTER) {
            return onSelect();
        }
        if (key == WatchUi.KEY_ESC) {
            return onBack();
        }
        return key == WatchUi.KEY_MENU;
    }

    function onBack() as Boolean {
        _dragging = false;
        if (_view.model.state == TimerModel.IDLE) {
            System.exit();
        } else {
            _view.model.reset();
            _view.refresh();
        }
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        return true;
    }
}
