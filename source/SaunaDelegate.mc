using Toybox.WatchUi;

// Controls:
// START (select) = stop session
// BACK/LAP = toggle sauna <-> rest
// UP/DOWN or swipe = switch data pages
class SaunaDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    // START = stop session
    function onSelect() {
        var dialog = new WatchUi.Confirmation("End session?");
        WatchUi.pushView(dialog, new StopConfirmDelegate(_model), WatchUi.SLIDE_UP);
        return true;
    }

    // BACK/LAP = toggle sauna <-> rest
    function onBack() {
        if (_model.state == STATE_ACTIVE) {
            _model.toggleLap();
            WatchUi.requestUpdate();
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

class StopConfirmDelegate extends WatchUi.ConfirmationDelegate {
    hidden var _model;

    function initialize(model) {
        ConfirmationDelegate.initialize();
        _model = model;
    }

    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            _model.finishSession();
            var view = new SummaryView(_model);
            WatchUi.switchToView(view, new SummaryDelegate(_model), WatchUi.SLIDE_UP);
        }
        return true;
    }
}
