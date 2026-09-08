import Toybox.Background;
import Toybox.System;

(:background)
class TimerService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var platform = new TimerPlatform();
        platform.setDiagnostics(new TimerDiagnostics());
        TimerExpiry.handleTemporalEvent(platform);
        Background.exit(null);
    }
}
