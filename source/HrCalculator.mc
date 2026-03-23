using Toybox.Math;

// HR zone and calorie calculations for sauna sessions
class HrCalculator {
    private var _maxHR;

    // HR zone boundaries as percentage of max HR
    private const ZONE_BOUNDS = [0.50, 0.60, 0.70, 0.80, 0.90];

    function initialize(maxHR) {
        _maxHR = maxHR;
    }

    // Returns HR zone 0-5 (0 = below zone 1)
    function getHRZone(hr) {
        if (hr <= 0 || _maxHR <= 0) {
            return 0;
        }
        var pct = hr.toFloat() / _maxHR.toFloat();
        for (var i = ZONE_BOUNDS.size() - 1; i >= 0; i--) {
            if (pct >= ZONE_BOUNDS[i]) {
                return i + 1;
            }
        }
        return 0;
    }

    // Zone color for AMOLED display
    function getZoneColor(zone) {
        switch (zone) {
            case 1: return 0x808080; // Gray
            case 2: return 0x00BFFF; // Light blue
            case 3: return 0x00FF00; // Green
            case 4: return 0xFFA500; // Orange
            case 5: return 0xFF0000; // Red
            default: return 0xFFFFFF; // White
        }
    }

    // Estimate calories burned per second using HR
    function caloriesPerSecond(hr, isMale) {
        if (hr <= 0) {
            return 0.0;
        }
        var hrF = hr.toFloat();
        var calsPerMin;
        if (isMale) {
            calsPerMin = (-55.0969 + 0.6309 * hrF + 0.0901 * 80.0 + 0.2017 * 30.0) / 4.184;
        } else {
            calsPerMin = (-20.4022 + 0.4472 * hrF + 0.1263 * 65.0 + 0.0740 * 30.0) / 4.184;
        }
        if (calsPerMin < 0.0) {
            calsPerMin = 0.0;
        }
        return calsPerMin / 60.0;
    }
}
