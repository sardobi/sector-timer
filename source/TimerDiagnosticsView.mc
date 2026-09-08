import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TimerDiagnosticsView extends WatchUi.View {
    private var _entries as Array<String>;
    private var _index as Number;
    var centerX as Number = 195;

    function initialize(entries as Array<String>) {
        View.initialize();
        _entries = entries;
        _index = entries.size() - 1;
    }

    function older() as Void {
        if (_index > 0) {
            _index--;
            WatchUi.requestUpdate();
        }
    }

    function newer() as Void {
        if (_index < _entries.size() - 1) {
            _index++;
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        centerX = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var title = WatchUi.loadResource(Rez.Strings.AlarmLog) as String;
        if (_entries.size() > 0) {
            title += " " + (_entries.size() - _index) + "/" + _entries.size();
        }
        dc.drawText(centerX, 38, Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        var text = _entries.size() == 0 ?
            WatchUi.loadResource(Rez.Strings.NoAlarmEvents) as String : _entries[_index];
        drawWrapped(dc, text, (dc.getWidth() * 0.74).toNumber(), 95);
        dc.drawText(centerX, dc.getHeight() - 95, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.AlarmLogNavigation),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWrapped(dc as Graphics.Dc, text as String, width as Number, top as Number) as Void {
        var line = "";
        var word = "";
        var y = top;
        var lineHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var characters = text.toCharArray();
        for (var i = 0; i <= characters.size(); i++) {
            var ch = i < characters.size() ? characters[i] : ' ';
            if (ch == ' ') {
                var next = line.length() == 0 ? word : line + " " + word;
                if (dc.getTextWidthInPixels(next, Graphics.FONT_XTINY) > width && line.length() > 0) {
                    dc.drawText(centerX, y, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
                    y += lineHeight;
                    line = word;
                } else {
                    line = next;
                }
                word = "";
            } else {
                word += ch.toString();
            }
        }
        if (line.length() > 0) {
            dc.drawText(centerX, y, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class TimerDiagnosticsDelegate extends WatchUi.InputDelegate {
    private var _view as TimerDiagnosticsView;

    function initialize(view as TimerDiagnosticsView) {
        InputDelegate.initialize();
        _view = view;
    }

    function onKey(event as WatchUi.KeyEvent) as Boolean {
        if (event.getKey() == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        if (event.getKey() == WatchUi.KEY_ENTER) {
            _view.older();
            return true;
        }
        return false;
    }

    function onTap(event as WatchUi.ClickEvent) as Boolean {
        if (event.getCoordinates()[0] < _view.centerX) {
            _view.newer();
        } else {
            _view.older();
        }
        return true;
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        var direction = event.getDirection();
        if (direction == WatchUi.SWIPE_UP || direction == WatchUi.SWIPE_LEFT) {
            _view.older();
        } else {
            _view.newer();
        }
        return true;
    }
}
