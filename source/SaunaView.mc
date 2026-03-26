using Toybox.WatchUi;
using Toybox.Graphics;

class SaunaView extends WatchUi.View {
    hidden var _model;

    function initialize(model) {
        View.initialize();
        _model = model;
    }

    function requestUpdate() {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_model.state == STATE_PAUSED) {
            _drawPausedScreen(dc);
            return;
        }

        switch (_model.currentPage) {
            case 0:
                _drawMainPage(dc);
                break;
            case 1:
                _drawHrDetailPage(dc);
                break;
            case 2:
                _drawBodyPage(dc);
                break;
        }

        _drawPageDots(dc);
    }

    // ===== PAGE 0: MAIN =====
    hidden function _drawMainPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var phaseColor = _model.getPhaseColor();

        // Phase bar top
        dc.setColor(phaseColor, phaseColor);
        dc.fillRectangle(0, 0, w, 8);

        // Phase + round - centered
        dc.setColor(phaseColor, Graphics.COLOR_TRANSPARENT);
        var roundText = _model.currentRound > 0 ? ("  R" + _model.currentRound) : "";
        dc.drawText(cx, cy - h * 40 / 100, Graphics.FONT_MEDIUM,
            _model.getPhaseName() + roundText, Graphics.TEXT_JUSTIFY_CENTER);

        // Phase timer large - centered
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 25 / 100, Graphics.FONT_NUMBER_HOT,
            _model.formatTime(_model.phaseElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // HR big - center of screen
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, cy + h * 2 / 100, Graphics.FONT_NUMBER_MEDIUM, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // bpm + zone
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var zoneText = "bpm";
        if (hrZone > 0) {
            zoneText = "bpm  Z" + hrZone;
        }
        dc.drawText(cx, cy + h * 18 / 100, Graphics.FONT_SMALL, zoneText, Graphics.TEXT_JUSTIFY_CENTER);

        // Calories and total time
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - w * 12 / 100, cy + h * 28 / 100, Graphics.FONT_SMALL,
            _model.totalCalories.toNumber().toString() + " cal", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + w * 15 / 100, cy + h * 28 / 100, Graphics.FONT_SMALL,
            _model.formatTime(_model.sessionElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // Hint
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        if (_model.phase == PHASE_SAUNA) {
            dc.drawText(cx, cy + h * 38 / 100, Graphics.FONT_XTINY, "LAP: End Set", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_model.currentRound == 0) {
            dc.drawText(cx, cy + h * 38 / 100, Graphics.FONT_XTINY, "LAP: Start Sauna", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, cy + h * 38 / 100, Graphics.FONT_XTINY, "LAP: Next Set", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ===== PAGE 1: HR DETAIL =====
    hidden function _drawHrDetailPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(0xFF4500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_SMALL, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);

        // Current HR
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, cy - h * 32 / 100, Graphics.FONT_NUMBER_MEDIUM, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // Session stats
        var y = cy - h * 12 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "SESSION min/avg/max", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var hrMinD = _model.sessionHrMin == 999 ? 0 : _model.sessionHrMin;
        dc.drawText(cx, y + h * 5 / 100, Graphics.FONT_MEDIUM,
            hrMinD + "/" + _model.getSessionHrAvg() + "/" + _model.sessionHrMax,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Round stats
        y = cy + h * 5 / 100;
        if (_model.currentRound > 0 && _model.phase == PHASE_SAUNA) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "ROUND " + _model.currentRound, Graphics.TEXT_JUSTIFY_CENTER);

            var rd = _model.currentRoundData;
            var rdMin = rd.hrMin == 999 ? 0 : rd.hrMin;
            dc.setColor(0xFF8C00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + h * 5 / 100, Graphics.FONT_MEDIUM,
                rdMin + "/" + rd.getHrAvg() + "/" + rd.hrMax,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 17 / 100;
        } else {
            y += h * 5 / 100;
        }

        // HR Recovery
        if (_model.rounds.size() > 0) {
            var lastRound = _model.rounds[_model.rounds.size() - 1];
            var recovery = lastRound.getHrRecoveryScore();
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "HR RECOVERY", Graphics.TEXT_JUSTIFY_CENTER);

            var recColor;
            if (recovery >= 30) { recColor = 0x00FF00; }
            else if (recovery >= 15) { recColor = 0xFFA500; }
            else { recColor = 0xFF0000; }
            dc.setColor(recColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + h * 5 / 100, Graphics.FONT_MEDIUM,
                (recovery > 0 ? recovery.toString() : "--") + " bpm",
                Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 15 / 100;
        }

        // Respiration
        if (_model.currentRespRate > 0) {
            dc.setColor(0x87CEEB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_SMALL,
                "Resp " + _model.currentRespRate, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ===== PAGE 2: BODY =====
    hidden function _drawBodyPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(0x00BFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_SMALL, "BODY", Graphics.TEXT_JUSTIFY_CENTER);

        // 6 rows centered, each row: label left-aligned, value right-aligned
        // Use inset from edges for round display
        var inset = w * 18 / 100; // stay inside round edges
        var leftX = inset;
        var rightX = w - inset;
        var startY = cy - h * 30 / 100;
        var rowH = h * 11 / 100;

        // SpO2
        _drawRow(dc, leftX, rightX, startY, "SpO2",
            _model.currentSpO2 > 0 ? _model.currentSpO2 + "%" : "--", 0x87CEEB);

        // Temp
        _drawRow(dc, leftX, rightX, startY + rowH, "Temp",
            _model.currentTemp != 0 ? _model.currentTemp.format("%.1f") + "°" : "--", 0xFFA500);

        // Stress
        _drawRow(dc, leftX, rightX, startY + rowH * 2, "Stress",
            _model.currentStress > 0 ? _model.currentStress.toString() : "--",
            _getStressColor(_model.currentStress));

        // Body Battery
        _drawRow(dc, leftX, rightX, startY + rowH * 3, "Body Bat",
            _model.currentBodyBattery > 0 ? _model.currentBodyBattery.toString() : "--",
            _getBBColor(_model.currentBodyBattery));

        // Pressure
        var pressureText = "--";
        if (_model.currentPressure > 0) {
            pressureText = (_model.currentPressure / 100).format("%.0f");
        }
        _drawRow(dc, leftX, rightX, startY + rowH * 4, "Press",
            pressureText, Graphics.COLOR_LT_GRAY);

        // Calories
        _drawRow(dc, leftX, rightX, startY + rowH * 5, "Cal",
            _model.totalCalories.toNumber().toString(), 0xFFD700);
    }

    hidden function _drawRow(dc, leftX, rightX, y, label, value, color) {
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, y, Graphics.FONT_MEDIUM, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function _getStressColor(stress) {
        if (stress <= 0) { return Graphics.COLOR_LT_GRAY; }
        if (stress <= 25) { return 0x00BFFF; }
        if (stress <= 50) { return 0xFFA500; }
        return 0xFF0000;
    }

    hidden function _getBBColor(bb) {
        if (bb <= 0) { return Graphics.COLOR_LT_GRAY; }
        if (bb >= 60) { return 0x00FF00; }
        if (bb >= 30) { return 0xFFA500; }
        return 0xFF0000;
    }

    hidden function _drawPausedScreen(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 20 / 100, Graphics.FONT_LARGE, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 2 / 100, Graphics.FONT_NUMBER_MEDIUM,
            _model.formatTime(_model.sessionElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        var roundsText = _model.rounds.size() + " rounds";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h * 15 / 100, Graphics.FONT_SMALL, roundsText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x00FF00, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h * 27 / 100, Graphics.FONT_TINY, "START: Resume", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + h * 34 / 100, Graphics.FONT_TINY, "BACK: Save/Discard", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawPageDots(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var y = h - h * 5 / 100;
        var dotR = w / 100 + 1;
        var spacing = dotR * 4;
        var startX = cx - ((_model.PAGE_COUNT - 1) * spacing / 2);

        for (var i = 0; i < _model.PAGE_COUNT; i++) {
            var x = startX + i * spacing;
            if (i == _model.currentPage) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, dotR);
            } else {
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, dotR);
            }
        }
    }
}
