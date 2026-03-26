using Toybox.System;
using Toybox.Sensor;
using Toybox.Activity;
using Toybox.SensorHistory;
using Toybox.Application;
using Toybox.Timer;
using Toybox.Attention;
using Toybox.ActivityRecording;

enum {
    PHASE_SAUNA = 0,
    PHASE_REST = 1
}

enum {
    STATE_IDLE = 0,
    STATE_ACTIVE = 1,
    STATE_PAUSED = 2,
    STATE_SESSION_SUMMARY = 3
}

class RoundData {
    var hrMax = 0;
    var hrMin = 999;
    var hrSum = 0;
    var hrCount = 0;
    var saunaDuration = 0;
    var restDuration = 0;
    var hrAtSaunaEnd = 0;
    var hrRecovery1Min = 0;
    var calories = 0.0;

    function getHrAvg() {
        if (hrCount == 0) { return 0; }
        return hrSum / hrCount;
    }

    function getHrRecoveryScore() {
        if (hrAtSaunaEnd == 0 || hrRecovery1Min == 0) { return 0; }
        return hrAtSaunaEnd - hrRecovery1Min;
    }
}

class SessionModel {
    var state = STATE_IDLE;
    var phase = PHASE_REST;
    var currentRound = 0;

    var phaseElapsed = 0;
    var sessionElapsed = 0;

    var currentHR = 0;
    var currentSpO2 = 0;
    var currentTemp = 0;       // device temperature
    var currentPressure = 0;   // barometric pressure (Pa)
    var currentAltitude = 0;   // altitude (m)
    var currentRespRate = 0;   // respiration rate
    var totalCalories = 0.0;

    var rounds = [];
    var currentRoundData;

    hidden var _recoveryRecorded = false;

    var bodyBatteryBefore = 0;
    var bodyBatteryAfter = 0;
    var stressBefore = 0;
    var stressAfter = 0;
    var currentStress = 0;
    var currentBodyBattery = 0;

    var sessionHrMax = 0;
    var sessionHrMin = 999;
    var sessionHrSum = 0;
    var sessionHrCount = 0;

    var hrCalc;
    var session;
    var updateTimer;
    var onUpdate;

    // Data page index (0=main, 1=HR detail, 2=body)
    var currentPage = 0;
    const PAGE_COUNT = 3;

    function initialize() {
        var maxHR = Application.Properties.getValue("maxHR");
        if (maxHR == null || maxHR == 0) { maxHR = 190; }
        hrCalc = new HrCalculator(maxHR);

        currentRoundData = new RoundData();
        updateTimer = new Timer.Timer();
    }

    function capturePreSessionMetrics() {
        bodyBatteryBefore = _getLatestBodyBattery();
        stressBefore = _getLatestStress();
    }

    function capturePostSessionMetrics() {
        bodyBatteryAfter = _getLatestBodyBattery();
        stressAfter = _getLatestStress();
    }

    hidden function _getLatestBodyBattery() {
        if (SensorHistory has :getBodyBatteryHistory) {
            var iter = SensorHistory.getBodyBatteryHistory({:period => 1});
            if (iter != null) {
                var sample = iter.next();
                if (sample != null && sample.data != null) {
                    return sample.data.toNumber();
                }
            }
        }
        return 0;
    }

    hidden function _getLatestStress() {
        if (SensorHistory has :getStressHistory) {
            var iter = SensorHistory.getStressHistory({:period => 1});
            if (iter != null) {
                var sample = iter.next();
                if (sample != null && sample.data != null) {
                    return sample.data.toNumber();
                }
            }
        }
        return 0;
    }

    function startSession() {
        state = STATE_ACTIVE;
        phase = PHASE_REST;
        currentRound = 0;
        phaseElapsed = 0;
        sessionElapsed = 0;
        totalCalories = 0.0;
        sessionHrMax = 0;
        sessionHrMin = 999;
        sessionHrSum = 0;
        sessionHrCount = 0;
        rounds = [];
        currentRoundData = new RoundData();
        currentPage = 0;

        capturePreSessionMetrics();

        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_PULSE_OXIMETRY]);
        Sensor.enableSensorEvents(method(:onSensor));

        session = ActivityRecording.createSession({
            :name => "Sauna",
            :sport => Activity.SPORT_TRAINING,
            :subSport => Activity.SUB_SPORT_CARDIO_TRAINING
        });
        session.start();

        updateTimer.start(method(:onTimer), 1000, true);
    }

    function onSensor(info as Sensor.Info) as Void {
        if (info.heartRate != null) {
            currentHR = info.heartRate;
        }
        if (info has :oxygenSaturation && info.oxygenSaturation != null) {
            currentSpO2 = info.oxygenSaturation;
        }
        if (info has :temperature && info.temperature != null) {
            currentTemp = info.temperature;
        }
        if (info has :pressure && info.pressure != null) {
            currentPressure = info.pressure;
        }
        if (info has :altitude && info.altitude != null) {
            currentAltitude = info.altitude;
        }
    }

    function onTimer() {
        if (state != STATE_ACTIVE) {
            return;
        }

        phaseElapsed++;
        sessionElapsed++;

        // Read respiration rate from Activity.Info
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null && actInfo has :respirationRate && actInfo.respirationRate != null) {
            currentRespRate = actInfo.respirationRate;
        }

        // Read stress and body battery every 10s (or first tick)
        if (sessionElapsed == 1 || sessionElapsed % 10 == 0) {
            currentStress = _getLatestStress();
            currentBodyBattery = _getLatestBodyBattery();
        }

        if (currentHR > 0) {
            // Track HR for current round during sauna
            if (phase == PHASE_SAUNA) {
                currentRoundData.hrCount++;
                currentRoundData.hrSum += currentHR;
                if (currentHR > currentRoundData.hrMax) { currentRoundData.hrMax = currentHR; }
                if (currentHR < currentRoundData.hrMin) { currentRoundData.hrMin = currentHR; }
            }

            // Session HR stats always
            sessionHrCount++;
            sessionHrSum += currentHR;
            if (currentHR > sessionHrMax) { sessionHrMax = currentHR; }
            if (currentHR < sessionHrMin) { sessionHrMin = currentHR; }

            // Calories ALWAYS count when HR is available
            var cals = hrCalc.caloriesPerSecond(currentHR, true);
            totalCalories += cals;
            if (phase == PHASE_SAUNA) {
                currentRoundData.calories += cals;
            }

            // HR recovery tracking
            if (phase == PHASE_REST && !_recoveryRecorded && phaseElapsed >= 60 && currentRound > 0) {
                currentRoundData.hrRecovery1Min = currentHR;
                _recoveryRecorded = true;
            }
        }

        if (phase == PHASE_SAUNA) {
            currentRoundData.saunaDuration = phaseElapsed;
        } else if (currentRound > 0) {
            currentRoundData.restDuration = phaseElapsed;
        }

        if (onUpdate != null) {
            onUpdate.invoke();
        }
    }

    function toggleLap() {
        if (phase == PHASE_REST) {
            if (currentRound > 0) {
                if (session != null) { session.addLap(); }
                rounds.add(currentRoundData);
            }
            currentRound++;
            currentRoundData = new RoundData();
            phase = PHASE_SAUNA;
            phaseElapsed = 0;

            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 500)]);
            }
        } else {
            currentRoundData.hrAtSaunaEnd = currentHR;
            phase = PHASE_REST;
            phaseElapsed = 0;
            _recoveryRecorded = false;

            if (Attention has :vibrate) {
                Attention.vibrate([
                    new Attention.VibeProfile(100, 300),
                    new Attention.VibeProfile(0, 200),
                    new Attention.VibeProfile(100, 300)
                ]);
            }
        }
    }

    function finishSession() {
        if (currentRoundData.saunaDuration > 0) {
            rounds.add(currentRoundData);
        }

        state = STATE_SESSION_SUMMARY;
        updateTimer.stop();
        capturePostSessionMetrics();

        Sensor.enableSensorEvents(null);

        if (session != null) { session.stop(); }

        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 1000)]);
        }
    }

    function saveActivity() {
        if (session != null) { session.save(); session = null; }
    }

    function discardActivity() {
        if (session != null) { session.discard(); session = null; }
    }

    function getCurrentHRZone() {
        return hrCalc.getHRZone(currentHR);
    }

    function getSessionHrAvg() {
        if (sessionHrCount == 0) { return 0; }
        return sessionHrSum / sessionHrCount;
    }

    function getAvgHrRecovery() {
        if (rounds.size() == 0) { return 0; }
        var sum = 0;
        var count = 0;
        for (var i = 0; i < rounds.size(); i++) {
            var score = rounds[i].getHrRecoveryScore();
            if (score > 0) { sum += score; count++; }
        }
        if (count == 0) { return 0; }
        return sum / count;
    }

    function getTotalDuration() {
        return sessionElapsed;
    }

    function formatTime(seconds) {
        var m = seconds / 60;
        var s = seconds % 60;
        return m.format("%02d") + ":" + s.format("%02d");
    }

    function getPhaseName() {
        if (phase == PHASE_SAUNA) { return "SAUNA"; }
        if (currentRound == 0) { return "READY"; }
        return "REST";
    }

    function getPhaseColor() {
        if (phase == PHASE_SAUNA) { return 0xFF4500; }
        return 0x00FF7F;
    }

    function nextPage() {
        currentPage = (currentPage + 1) % PAGE_COUNT;
    }

    function prevPage() {
        currentPage = (currentPage - 1 + PAGE_COUNT) % PAGE_COUNT;
    }
}
