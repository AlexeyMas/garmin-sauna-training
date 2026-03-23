using Toybox.Application;
using Toybox.WatchUi;

class SaunaApp extends Application.AppBase {
    var model;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        model = new SessionModel();
        return [new StartView(model), new StartDelegate(model)];
    }
}
