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

    // START = pause / resume
    function onSelect() {
        if (_model.state == STATE_ACTIVE) {
            _model.state = STATE_PAUSED;
        } else if (_model.state == STATE_PAUSED) {
            _model.state = STATE_ACTIVE;
        }
        WatchUi.requestUpdate();
        return true;
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
            // Show Save/Discard/Resume menu
            var menu = new WatchUi.Menu2({:title => "Session"});
            menu.addItem(new WatchUi.MenuItem("Save", null, :save, {}));
            menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, {}));
            menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, {}));
            WatchUi.pushView(menu, new SessionMenuDelegate(_model), WatchUi.SLIDE_UP);
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
            // Pop menu, then pop session view, push summary
            WatchUi.popView(WatchUi.SLIDE_DOWN); // pop menu
            // Replace session view with summary
            var view = new SummaryView(_model);
            WatchUi.switchToView(view, new SummaryDelegate(_model), WatchUi.SLIDE_UP);
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
