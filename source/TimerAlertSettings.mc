import Toybox.Lang;
import Toybox.System;

(:background)
module AlertSettings {
    const DND = 1;
    const VIBRATION_OFF = 2;

    function read() as TimerAlertSettings {
        var settings = System.getDeviceSettings();
        return new TimerAlertSettings(
            settings has :doNotDisturb ? settings.doNotDisturb : null,
            settings has :vibrateOn ? settings.vibrateOn : null
        );
    }
}

(:background)
class TimerAlertSettings {
    var doNotDisturb as Boolean?;
    var vibrateOn as Boolean?;

    function initialize(dnd as Boolean?, vibration as Boolean?) {
        doNotDisturb = dnd;
        vibrateOn = vibration;
    }

    function warningCode() as Number {
        var code = 0;
        if (doNotDisturb == true) {
            code |= AlertSettings.DND;
        }
        if (vibrateOn == false) {
            code |= AlertSettings.VIBRATION_OFF;
        }
        return code;
    }

    function summary() as String {
        return "dnd=" + doNotDisturb + " vibration=" + vibrateOn;
    }
}
