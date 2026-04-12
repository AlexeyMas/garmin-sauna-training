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
            case 3:
                _drawRoundsPage(dc);
                break;
            case 4:
                _drawTrendsPage(dc);
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

        // Phase timer large - raised up
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 27 / 100, Graphics.FONT_NUMBER_MEDIUM,
            _model.formatTime(_model.phaseElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // HR big - raised up
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, cy - h * 5 / 100, Graphics.FONT_NUMBER_MILD, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // bpm + zone + delta from resting
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var zoneText = "bpm";
        if (hrZone > 0) {
            zoneText = "bpm  Z" + hrZone;
        }
        if (_model.currentHR > 0 && _model.restingHR > 0) {
            var delta = _model.currentHR - _model.restingHR;
            if (delta > 0) {
                zoneText += "  +" + delta;
            }
        }
        dc.drawText(cx, cy + h * 10 / 100, Graphics.FONT_XTINY, zoneText, Graphics.TEXT_JUSTIFY_CENTER);

        // Calories and total time
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - w * 15 / 100, cy + h * 20 / 100, Graphics.FONT_XTINY,
            _model.totalCalories.toNumber().toString() + " cal", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + w * 15 / 100, cy + h * 20 / 100, Graphics.FONT_XTINY,
            _model.formatTime(_model.sessionElapsed), Graphics.TEXT_JUSTIFY_CENTER);

        // Recovery indicator during REST, or hint
        var hintY = cy + h * 32 / 100;
        if (_model.phase == PHASE_REST && _model.currentRound > 0) {
            var hrDrop = _model.getHrDrop();
            var recoveryPct = _model.getRecoveryPercent();
            var isReady = recoveryPct >= 100;
            // Orange → Yellow → Green gradient based on recovery
            var arcColor;
            if (isReady) { arcColor = 0x00FF00; }
            else if (recoveryPct >= 70) { arcColor = 0xAAFF00; }
            else if (recoveryPct >= 40) { arcColor = 0xFFA500; }
            else { arcColor = 0xFF6600; }

            // Recovery arc along bottom of screen (inside bezel)
            // 320°=lower-right, 220°=lower-left, 100° span through bottom
            var arcR = cx - 18;
            dc.setPenWidth(10);

            // Dim background arc in dark version of recovery color
            var dimColor;
            if (isReady) { dimColor = 0x004400; }
            else if (recoveryPct >= 70) { dimColor = 0x334400; }
            else if (recoveryPct >= 40) { dimColor = 0x442200; }
            else { dimColor = 0x441100; }
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 320, 220);

            // Bright fill arc proportional to recovery
            if (recoveryPct > 0) {
                var pct = recoveryPct > 100 ? 100 : recoveryPct;
                var sweepDeg = pct * 100 / 100;
                var endAngle = 320 - sweepDeg;
                if (endAngle < 0) { endAngle += 360; }
                dc.setColor(arcColor, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 320, endAngle);
            }
            dc.setPenWidth(1);

            // Recovery text with percentage
            dc.setColor(arcColor, Graphics.COLOR_TRANSPARENT);
            var dropText;
            if (isReady) {
                dropText = "READY";
            } else {
                var pctDisplay = recoveryPct > 99 ? 99 : recoveryPct;
                dropText = "Recovery " + pctDisplay + "%";
            }
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, dropText, Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_model.phase == PHASE_SAUNA) {
            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "LAP: End Set", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "LAP: Start Sauna", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ===== PAGE 1: HR DETAIL =====
    hidden function _drawHrDetailPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var inset = w * 18 / 100;
        var leftX = inset;
        var rightX = w - inset;

        // Title
        dc.setColor(0xFF4500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_XTINY, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);

        // Current HR
        var hrZone = _model.getCurrentHRZone();
        var hrColor = _model.hrCalc.getZoneColor(hrZone);
        dc.setColor(hrColor, Graphics.COLOR_TRANSPARENT);
        var hrText = _model.currentHR > 0 ? _model.currentHR.toString() : "--";
        dc.drawText(cx, cy - h * 35 / 100, Graphics.FONT_NUMBER_MILD, hrText, Graphics.TEXT_JUSTIFY_CENTER);

        // Zone (only if in a zone)
        if (hrZone > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - h * 14 / 100, Graphics.FONT_XTINY, "Z" + hrZone, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Session stats as rows - evenly spaced
        var startY = cy - h * 14 / 100;
        var rowH = h * 13 / 100;

        var hrMinD = _model.sessionHrMin == 999 ? 0 : _model.sessionHrMin;
        _drawRow(dc, leftX, rightX, startY, "Sess Min", hrMinD.toString(), Graphics.COLOR_LT_GRAY);
        _drawRow(dc, leftX, rightX, startY + rowH, "Sess Avg", _model.getSessionHrAvg().toString(), Graphics.COLOR_WHITE);
        _drawRow(dc, leftX, rightX, startY + rowH * 2, "Sess Max", _model.sessionHrMax.toString(), 0xFF4500);

        // Round HR max (if in sauna round)
        if (_model.currentRound > 0 && _model.phase == PHASE_SAUNA) {
            var rd = _model.currentRoundData;
            _drawRow(dc, leftX, rightX, startY + rowH * 3, "R" + _model.currentRound + " Max", rd.hrMax.toString(), 0xFF8C00);
        } else if (_model.rounds.size() > 0) {
            // HR Recovery from last round
            var lastRound = _model.rounds[_model.rounds.size() - 1];
            var recovery = lastRound.getHrRecoveryScore();
            var recColor;
            if (recovery >= 30) { recColor = 0x00FF00; }
            else if (recovery >= 15) { recColor = 0xFFA500; }
            else { recColor = 0xFF0000; }
            _drawRow(dc, leftX, rightX, startY + rowH * 3, "Recovery",
                recovery > 0 ? recovery.toString() : "--", recColor);
        }

        // Respiration
        if (_model.currentRespRate > 0) {
            _drawRow(dc, leftX, rightX, startY + rowH * 4, "Resp", _model.currentRespRate.toString(), 0x87CEEB);
        }
    }

    // ===== PAGE 2: BODY =====
    hidden function _drawBodyPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        // Current time large
        var clockInfo = System.getClockTime();
        var timeStr = clockInfo.hour.format("%02d") + ":" + clockInfo.min.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_NUMBER_MILD, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        var inset = w * 18 / 100;
        var leftX = inset;
        var rightX = w - inset;
        var startY = cy - h * 18 / 100;
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

        // Resting HR
        _drawRow(dc, leftX, rightX, startY + rowH * 4, "Rest HR",
            _model.restingHR > 0 ? _model.restingHR.toString() : "--", 0x87CEEB);
    }

    // ===== PAGE 3: ROUNDS =====
    hidden function _drawRoundsPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var inset = w * 18 / 100;
        var leftX = inset;
        var rightX = w - inset;

        // Title
        dc.setColor(0xFFD700, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_SMALL, "ROUNDS", Graphics.TEXT_JUSTIFY_CENTER);

        // Current phase + time
        var phaseColor = _model.getPhaseColor();
        dc.setColor(phaseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 32 / 100, Graphics.FONT_MEDIUM,
            _model.getPhaseName() + "  " + _model.formatTime(_model.phaseElapsed),
            Graphics.TEXT_JUSTIFY_CENTER);

        // Stats: Total / Rounds / Current — fixed positions
        var startY = cy - h * 18 / 100;
        var rowH = h * 10 / 100;

        _drawRow(dc, leftX, rightX, startY, "Total",
            _model.formatTime(_model.sessionElapsed), Graphics.COLOR_WHITE);
        _drawRow(dc, leftX, rightX, startY + rowH, "Rounds",
            _model.rounds.size().toString(), 0xFFD700);
        if (_model.currentRound > 0) {
            _drawRow(dc, leftX, rightX, startY + rowH * 2, "Current",
                "R" + _model.currentRound, 0xFF8C00);
        }

        // Round history — fixed at bottom, last 2
        if (_model.rounds.size() > 0) {
            var maxShow = 2;
            var rStart = 0;
            if (_model.rounds.size() > maxShow) {
                rStart = _model.rounds.size() - maxShow;
            }
            var y = cy + h * 12 / 100;
            for (var i = rStart; i < _model.rounds.size(); i++) {
                var rd = _model.rounds[i];
                dc.setColor(0xFFAA00, Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, y, Graphics.FONT_SMALL,
                    "R" + (i + 1) + "  " + _model.formatTime(rd.saunaDuration) + " / " + _model.formatTime(rd.restDuration),
                    Graphics.TEXT_JUSTIFY_CENTER);
                y += h * 11 / 100;
            }
        }
    }

    // ===== PAGE 4: TRENDS =====
    hidden function _drawTrendsPage(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - h * 42 / 100, Graphics.FONT_SMALL, "TRENDS", Graphics.TEXT_JUSTIFY_CENTER);

        // Current temp large
        dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
        var tempText = _model.currentTemp != 0 ? _model.currentTemp.format("%.1f") + "°C" : "--";
        dc.drawText(cx, cy - h * 33 / 100, Graphics.FONT_MEDIUM, tempText, Graphics.TEXT_JUSTIFY_CENTER);

        // Temp graph
        var history = _model.tempHistory;
        if (history.size() >= 2) {
            // Graph area - well inside round edges
            var gLeft = w * 22 / 100;
            var gRight = w - w * 22 / 100;
            var gTop = cy - h * 12 / 100;
            var gBottom = cy + h * 12 / 100;
            var gW = gRight - gLeft;
            var gH = gBottom - gTop;

            // Find min/max
            var tMin = history[0];
            var tMax = history[0];
            for (var i = 1; i < history.size(); i++) {
                if (history[i] < tMin) { tMin = history[i]; }
                if (history[i] > tMax) { tMax = history[i]; }
            }
            var tRange = tMax - tMin;
            if (tRange < 1.0) { tRange = 1.0; }

            // Draw grid lines
            dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(gLeft, gTop, gRight, gTop);
            dc.drawLine(gLeft, gBottom, gRight, gBottom);

            // Min/max labels centered above/below graph
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(gRight + 4, gTop - 2, Graphics.FONT_XTINY,
                tMax.format("%.0f"), Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(gRight + 4, gBottom - 12, Graphics.FONT_XTINY,
                tMin.format("%.0f"), Graphics.TEXT_JUSTIFY_LEFT);

            // Draw line graph
            dc.setColor(0xFFA500, Graphics.COLOR_TRANSPARENT);
            var step = gW.toFloat() / (history.size() - 1);
            for (var i = 1; i < history.size(); i++) {
                var x1 = gLeft + ((i - 1) * step).toNumber();
                var y1 = gBottom - ((history[i - 1] - tMin) / tRange * gH).toNumber();
                var x2 = gLeft + (i * step).toNumber();
                var y2 = gBottom - ((history[i] - tMin) / tRange * gH).toNumber();
                dc.drawLine(x1, y1, x2, y2);
                dc.drawLine(x1, y1 + 1, x2, y2 + 1);
            }
        } else {
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_XTINY,
                "Temp graph after 1 min", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // HR vs resting - centered below graph
        var bottomY = cy + h * 18 / 100;
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, bottomY, Graphics.FONT_XTINY, "HR vs Resting", Graphics.TEXT_JUSTIFY_CENTER);
        bottomY += h * 5 / 100;
        if (_model.currentHR > 0 && _model.restingHR > 0) {
            var delta = _model.currentHR - _model.restingHR;
            dc.setColor(delta > 20 ? 0xFF4500 : 0x00BFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bottomY, Graphics.FONT_MEDIUM,
                "+" + delta + " bpm", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, bottomY, Graphics.FONT_MEDIUM, "--", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function _drawRow(dc, leftX, rightX, y, label, value, color) {
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftX, y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightX, y, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
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
