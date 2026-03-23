using Toybox.WatchUi;
using Toybox.Graphics;

class SummaryView extends WatchUi.View {
    hidden var _model;

    function initialize(model) {
        View.initialize();
        _model = model;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;

        // Title
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 10, Graphics.FONT_MEDIUM, "SESSION", Graphics.TEXT_JUSTIFY_CENTER);

        var y = 50;
        var lineH = 24;

        // Duration and rounds
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            _model.formatTime(_model.getTotalDuration()) + "  |  " +
            _model.rounds.size() + " rounds",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH + 5;

        // HR: min / avg / max
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, "HR min / avg / max", Graphics.TEXT_JUSTIFY_CENTER);
        y += 18;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var hrMinDisplay = _model.sessionHrMin;
        if (hrMinDisplay == 999) { hrMinDisplay = 0; }
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            hrMinDisplay + " / " + _model.getSessionHrAvg() + " / " + _model.sessionHrMax,
            Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;

        // Calories
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            "Calories: " + _model.totalCalories.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;

        // HR Recovery avg
        var avgRec = _model.getAvgHrRecovery();
        dc.setColor(0x00FF7F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            "HR Recovery: " + (avgRec > 0 ? avgRec.toString() : "--"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += lineH;

        // Body Battery
        if (_model.bodyBatteryBefore > 0) {
            dc.setColor(0x00BFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_TINY,
                "BB: " + _model.bodyBatteryBefore + " -> " + _model.bodyBatteryAfter,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 20;
        }

        // Stress
        if (_model.stressBefore > 0) {
            dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_TINY,
                "Stress: " + _model.stressBefore + " -> " + _model.stressAfter,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 20;
        }

        // Actions
        y = dc.getHeight() - 45;
        dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, "SAVE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFF4444, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 20, Graphics.FONT_TINY, "BACK: Discard", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    // START/SELECT = save
    function onSelect() {
        _model.saveActivity();
        _exitToStart();
        return true;
    }

    // BACK = discard
    function onBack() {
        _model.discardActivity();
        _exitToStart();
        return true;
    }

    hidden function _exitToStart() {
        var model = new SessionModel();
        WatchUi.switchToView(new StartView(model), new StartDelegate(model), WatchUi.SLIDE_RIGHT);
    }
}
