using Toybox.WatchUi;
using Toybox.Graphics;

class StartView extends WatchUi.View {
    hidden var _model;

    function initialize(model) {
        View.initialize();
        _model = model;
    }

    function onLayout(dc) {
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(0xFF4500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 80, Graphics.FONT_LARGE, "SAUNA", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 10, Graphics.FONT_SMALL,
            "Multi-round tracker", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Graphics.FONT_XTINY,
            "Use at your own risk", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 80, Graphics.FONT_MEDIUM,
            "START", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, Graphics.FONT_XTINY,
            "v1.14", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// START = begin session, BACK = exit app
class StartDelegate extends WatchUi.BehaviorDelegate {
    hidden var _model;

    function initialize(model) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    function onSelect() {
        _model.startSession();
        var view = new SaunaView(_model);
        _model.onUpdate = view.method(:requestUpdate);
        // Push (not switch) so we can pop back cleanly
        WatchUi.pushView(view, new SaunaDelegate(_model), WatchUi.SLIDE_LEFT);
        return true;
    }

    function onBack() {
        // Exit app
        System.exit();
        return true;
    }
}
