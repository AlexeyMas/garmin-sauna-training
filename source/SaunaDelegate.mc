using Toybox.WatchUi;
using Toybox.Attention;

// Standard Garmin activity controls:
// START = pause / resume
// BACK/LAP = toggle sauna <-> rest (during active)
// BACK from pause = Save/Discard/Resume menu
class SaunaDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    // START button = pause / resume
    function onSelect() {
        if (_model.state == STATE_ACTIVE) {
            _model.state = STATE_PAUSED;
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 300)]);
            }
        } else if (_model.state == STATE_PAUSED) {
            _model.state = STATE_ACTIVE;
        }
        WatchUi.requestUpdate();
        return true;
    }

    // BACK/LAP button
    function onBack() {
        if (_model.state == STATE_ACTIVE) {
            // During active session: toggle sauna <-> rest
            _model.toggleLap();
            WatchUi.requestUpdate();
            return true;
        }

        if (_model.state == STATE_PAUSED) {
            // From pause: show Save/Discard/Resume menu
            var menu = new WatchUi.Menu2({:title => "Session"});
            menu.addItem(new WatchUi.MenuItem("Save", null, :save, {}));
            menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, {}));
            menu.addItem(new WatchUi.MenuItem("Resume", null, :resume, {}));
            WatchUi.pushView(menu, new SessionMenuDelegate(_model), WatchUi.SLIDE_UP);
            return true;
        }

        return false;
    }

    // UP = previous page
    function onPreviousPage() {
        _model.prevPage();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN = next page
    function onNextPage() {
        _model.nextPage();
        WatchUi.requestUpdate();
        return true;
    }
}

// Menu handler for Save/Discard/Resume
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
            var view = new SummaryView(_model);
            WatchUi.switchToView(view, new SummaryDelegate(_model), WatchUi.SLIDE_UP);
        } else if (id == :discard) {
            _model.finishSession();
            _model.discardActivity();
            // Go back to start
            var model = new SessionModel();
            WatchUi.switchToView(new StartView(model), new StartDelegate(model), WatchUi.SLIDE_RIGHT);
        } else if (id == :resume) {
            _model.state = STATE_ACTIVE;
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }

    function onBack() {
        // Back from menu = resume
        _model.state = STATE_ACTIVE;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
