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

        var phaseColor = _model.getPhaseColor();

        // Phase bar top
        dc.setColor(phaseColor, phaseColor);
        dc.fillRectangle(0, 0, w, h * 2 / 100);

        // Phase + round (top area)
        dc.setColor(phaseColor, Graphics.COLOR_TRANSPARENT);
        var roundText = _model.currentRound > 0 ? ("  R" + _model.currentRound) : "";
        dc.drawText(cx, h * 5 / 100, Graphics.FONT_MEDIUM,
            _model.getPhaseName() + roundText, Graphics.TEXT_JUSTIFY_CENTER);

        // Phase timer (large, centered)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 18 / 100, Graphics.FONT_NUMBER_HOT,
            _model.formatTime(_model.phaseElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // HR big number (center)
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, h * 45 / 100, Graphics.FONT_NUMBER_MEDIUM, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // bpm + zone below HR
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var zoneText = "bpm";
        if (hrZone > 0) {
            zoneText = "bpm  Z" + hrZone;
        }
        dc.drawText(cx, h * 62 / 100, Graphics.FONT_SMALL, zoneText, Graphics.TEXT_JUSTIFY_CENTER);

        // Calories left, total time right
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - w * 15 / 100, h * 73 / 100, Graphics.FONT_SMALL,
            _model.totalCalories.toNumber().toString() + " cal", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + w * 15 / 100, h * 73 / 100, Graphics.FONT_SMALL,
            _model.formatTime(_model.sessionElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // Hint
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        if (_model.phase == PHASE_SAUNA) {
            dc.drawText(cx, h * 84 / 100, Graphics.FONT_XTINY, "LAP: End Set", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_model.currentRound == 0) {
            dc.drawText(cx, h * 84 / 100, Graphics.FONT_XTINY, "LAP: Start Sauna", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, h * 84 / 100, Graphics.FONT_XTINY, "LAP: Next Set", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ===== PAGE 1: HR DETAIL =====
    hidden function _drawHrDetailPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(0xFF4500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 3 / 100, Graphics.FONT_SMALL, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);

        // Current HR
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, h * 10 / 100, Graphics.FONT_NUMBER_MEDIUM, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // Session stats
        var y = h * 30 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "SESSION  min / avg / max", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var hrMinD = _model.sessionHrMin == 999 ? 0 : _model.sessionHrMin;
        dc.drawText(cx, y + h * 4 / 100, Graphics.FONT_MEDIUM,
            hrMinD + " / " + _model.getSessionHrAvg() + " / " + _model.sessionHrMax,
            Graphics.TEXT_JUSTIFY_CENTER);

        // Round stats
        y = h * 45 / 100;
        if (_model.currentRound > 0 && _model.phase == PHASE_SAUNA) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "ROUND " + _model.currentRound, Graphics.TEXT_JUSTIFY_CENTER);

            var rd = _model.currentRoundData;
            var rdMin = rd.hrMin == 999 ? 0 : rd.hrMin;
            dc.setColor(0xFF8C00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + h * 4 / 100, Graphics.FONT_MEDIUM,
                rdMin + " / " + rd.getHrAvg() + " / " + rd.hrMax,
                Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 14 / 100;
        } else {
            y += h * 6 / 100;
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
            dc.drawText(cx, y + h * 4 / 100, Graphics.FONT_MEDIUM,
                (recovery > 0 ? recovery.toString() : "--") + " bpm",
                Graphics.TEXT_JUSTIFY_CENTER);
            y += h * 14 / 100;
        }

        // Respiration
        if (_model.currentRespRate > 0) {
            dc.setColor(0x87CEEB, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_SMALL,
                "Resp: " + _model.currentRespRate + " br/min", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ===== PAGE 2: BODY =====
    hidden function _drawBodyPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(0x00BFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 3 / 100, Graphics.FONT_SMALL, "BODY", Graphics.TEXT_JUSTIFY_CENTER);

        // 6 rows of metrics, evenly spaced
        var startY = h * 12 / 100;
        var rowH = h * 13 / 100;
        var labelX = cx - w * 30 / 100;
        var valueX = cx + w * 30 / 100;

        // Row 1: SpO2
        _drawRow(dc, labelX, valueX, startY, "SpO2",
            _model.currentSpO2 > 0 ? _model.currentSpO2 + "%" : "--", 0x87CEEB);

        // Row 2: Temperature
        _drawRow(dc, labelX, valueX, startY + rowH, "TEMP",
            _model.currentTemp != 0 ? _model.currentTemp.format("%.1f") + "°" : "--", 0xFFA500);

        // Row 3: Stress
        _drawRow(dc, labelX, valueX, startY + rowH * 2, "STRESS",
            _model.currentStress > 0 ? _model.currentStress.toString() : "--",
            _getStressColor(_model.currentStress));

        // Row 4: Body Battery
        _drawRow(dc, labelX, valueX, startY + rowH * 3, "BODY BATT",
            _model.currentBodyBattery > 0 ? _model.currentBodyBattery.toString() : "--",
            _getBBColor(_model.currentBodyBattery));

        // Row 5: Pressure
        var pressureText = "--";
        if (_model.currentPressure > 0) {
            pressureText = (_model.currentPressure / 100).format("%.0f");
        }
        _drawRow(dc, labelX, valueX, startY + rowH * 4, "PRESS hPa",
            pressureText, Graphics.COLOR_LT_GRAY);

        // Row 6: Calories
        _drawRow(dc, labelX, valueX, startY + rowH * 5, "CALORIES",
            _model.totalCalories.toNumber().toString(), 0xFFD700);
    }

    hidden function _drawRow(dc, labelX, valueX, y, label, value, color) {
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(valueX, y, Graphics.FONT_MEDIUM, value, Graphics.TEXT_JUSTIFY_RIGHT);
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

    hidden function _drawPageDots(dc) {
        var cx = dc.getWidth() / 2;
        var y = dc.getHeight() - dc.getHeight() * 4 / 100;
        var dotR = dc.getWidth() * 1 / 100;
        if (dotR < 3) { dotR = 3; }
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
