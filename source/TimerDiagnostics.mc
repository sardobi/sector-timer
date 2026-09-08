import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;

(:background)
class InvalidTimerDiagnosticsException extends Lang.Exception {
    function initialize() {
        Exception.initialize();
    }
}

(:background)
class TimerDiagnostics {
    static const LIMIT = 20;
    static const MAX_LENGTH = 180;

    function initialize() {
    }

    function readValue() as Object? {
        return Storage.getValue("alarm-log-v1");
    }

    function writeValue(entries as Array<String>) as Void {
        var values = [] as Array<Storage.ValueType>;
        for (var i = 0; i < entries.size(); i++) {
            values.add(entries[i]);
        }
        Storage.setValue("alarm-log-v1", values);
    }

    function readEntries() as Array<String> {
        var value = readValue();
        var entries = [] as Array<String>;
        if (value == null) {
            return entries;
        }
        if (!(value instanceof Array) || value.size() > LIMIT) {
            throw new InvalidTimerDiagnosticsException();
        }
        for (var i = 0; i < value.size(); i++) {
            var entry = value[i];
            if (!(entry instanceof String) || entry.length() > MAX_LENGTH) {
                throw new InvalidTimerDiagnosticsException();
            }
            entries.add(entry);
        }
        return entries;
    }

    function append(epoch as Number, event as String) as Void {
        var entry = epoch + " " + event;
        if (entry.length() > MAX_LENGTH) {
            entry = entry.substring(0, MAX_LENGTH) as String;
        }
        var entries = readEntries();
        if (entries.size() == LIMIT) {
            entries.remove(entries[0]);
        }
        entries.add(entry);
        writeValue(entries);
        System.println("Visual Timer: " + entry);
    }
}
