using Toybox.WatchUi;
using Toybox.Attention;
using Toybox.System;

// Standard Garmin activity controls:
// START = pause / resume
// BACK/LAP (active) = toggle sauna <-> rest
// BACK (paused) = Save/Discard/Resume menu
// UP/DOWN = switch data pages
class SaunaDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    // START/STOP = pause + show menu immediately
    function onSelect() {
        if (_model.state == STATE_ACTIVE) {
            _model.state = STATE_PAUSED;
            _showSessionMenu();
        } else if (_model.state == STATE_PAUSED) {
            _showSessionMenu();
        }
        return true;
    }

    hidden function _showSessionMenu() {
        var menu = new WatchUi.Menu2({:title => "Session"});
        menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, {}));
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, {}));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, {}));
        WatchUi.pushView(menu, new SessionMenuDelegate(_model), WatchUi.SLIDE_UP);
    }

    // BACK/LAP
    function onBack() {
        if (_model.state == STATE_ACTIVE) {
            // LAP: toggle sauna <-> rest
            _model.toggleLap();
            WatchUi.requestUpdate();
            return true;
        }

        if (_model.state == STATE_PAUSED) {
            _showSessionMenu();
            return true;
        }

        return true; // consume all back presses during session
    }

    function onPreviousPage() {
        _model.prevPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _model.nextPage();
        WatchUi.requestUpdate();
        return true;
    }
}

// Save/Discard/Resume menu
class SessionMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _model;

    function initialize(model) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :save) {
            _model.finishSession();
            _model.saveActivity();
            System.exit();
        } else if (id == :discard) {
            _model.finishSession();
            _model.discardActivity();
            // Pop menu and session view — back to start
            WatchUi.popView(WatchUi.SLIDE_DOWN); // pop menu
            WatchUi.popView(WatchUi.SLIDE_RIGHT); // pop session — back to StartView
        } else if (id == :resume) {
            _model.state = STATE_ACTIVE;
            WatchUi.popView(WatchUi.SLIDE_DOWN); // pop menu
        }
    }

    function onBack() {
        // Back from menu = resume
        _model.state = STATE_ACTIVE;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
