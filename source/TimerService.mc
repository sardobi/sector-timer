import Toybox.Background;
import Toybox.System;

(:background)
class TimerService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var platform = new TimerPlatform();
        System.println("Visual Timer: temporal event at " + platform.now());
        TimerExpiry.notifyIfDue(platform);
        Background.exit(null);
    }
}
