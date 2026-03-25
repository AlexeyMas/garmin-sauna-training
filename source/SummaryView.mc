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

        var w = dc.getWidth();
        var cx = w / 2;

        // Title
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 20, Graphics.FONT_MEDIUM, "SESSION", Graphics.TEXT_JUSTIFY_CENTER);

        var y = 75;

        // Duration and rounds
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            _model.formatTime(_model.getTotalDuration()) + "  |  " +
            _model.rounds.size() + " rounds",
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 45;

        // HR: min / avg / max
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_TINY, "HR min / avg / max", Graphics.TEXT_JUSTIFY_CENTER);
        y += 30;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var hrMinDisplay = _model.sessionHrMin;
        if (hrMinDisplay == 999) { hrMinDisplay = 0; }
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            hrMinDisplay + " / " + _model.getSessionHrAvg() + " / " + _model.sessionHrMax,
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 40;

        // Calories
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            "Calories: " + _model.totalCalories.toNumber(), Graphics.TEXT_JUSTIFY_CENTER);
        y += 40;

        // HR Recovery avg
        var avgRec = _model.getAvgHrRecovery();
        dc.setColor(0x00FF7F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL,
            "HR Recovery: " + (avgRec > 0 ? avgRec.toString() : "--"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += 40;

        // Body Battery
        if (_model.bodyBatteryBefore > 0) {
            dc.setColor(0x00BFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_TINY,
                "BB: " + _model.bodyBatteryBefore + " -> " + _model.bodyBatteryAfter,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 30;
        }

        // Stress
        if (_model.stressBefore > 0) {
            dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_TINY,
                "Stress: " + _model.stressBefore + " -> " + _model.stressAfter,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += 30;
        }

        // Saved indicator
        dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dc.getHeight() - 50, Graphics.FONT_TINY, "Activity Saved", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, dc.getHeight() - 25, Graphics.FONT_XTINY, "BACK to exit", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class SummaryDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    // Any button from summary = exit
    function onSelect() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    hidden function _exitToStart() {
        var model = new SessionModel();
        WatchUi.switchToView(new StartView(model), new StartDelegate(model), WatchUi.SLIDE_RIGHT);
    }
}
