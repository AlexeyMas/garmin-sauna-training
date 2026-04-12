using Toybox.System;
using Toybox.Sensor;
using Toybox.Activity;
using Toybox.SensorHistory;
using Toybox.Application;
using Toybox.Timer;
using Toybox.Attention;
using Toybox.ActivityRecording;
using Toybox.FitContributor;
using Toybox.UserProfile;
using Toybox.ActivityMonitor;

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
    var restingHR = 0;
    var timeToRecovery = 0;
    var tempHistory = [];       // temperature samples for graph
    const TEMP_HISTORY_MAX = 30; // max samples (every 30s = 15 min)
    var hrAtSaunaEnd = 0;       // HR when leaving sauna (for recovery tracking)
    var restHrMin = 999;        // lowest HR during current rest
    hidden var _recoveryAlerted = false;

    var sessionHrMax = 0;
    var sessionHrMin = 999;
    var sessionHrSum = 0;
    var sessionHrCount = 0;

    var hrCalc;
    var session;
    var updateTimer;
    var onUpdate;

    // FIT custom fields
    var fitPhase;           // RECORD: 0=sauna, 1=rest
    var fitRecovery;        // RECORD: recovery %
    var fitLapRound;        // LAP: round number
    var fitLapHrMax;        // LAP: HR max
    var fitLapHrAvg;        // LAP: HR avg
    var fitRounds;          // SESSION: total rounds
    var fitAvgRecovery;     // SESSION: avg HR recovery
    var fitBBBefore;        // SESSION: body battery before
    var fitBBAfter;         // SESSION: body battery after
    var fitStressBefore;    // SESSION: stress before
    var fitStressAfter;     // SESSION: stress after

    // Data page index (0=main, 1=HR detail, 2=body)
    var currentPage = 0;
    const PAGE_COUNT = 5;

    function initialize() {
        var maxHR = Application.Properties.getValue("maxHR");
        if (maxHR == null || maxHR == 0) { maxHR = 190; }
        hrCalc = new HrCalculator(maxHR);

        // Read resting HR from user profile
        var profile = Toybox.UserProfile.getProfile();
        if (profile != null) {
            if (profile has :restingHeartRate && profile.restingHeartRate != null) {
                restingHR = profile.restingHeartRate;
            }
            if (restingHR == 0 && profile has :averageRestingHeartRate && profile.averageRestingHeartRate != null) {
                restingHR = profile.averageRestingHeartRate;
            }
        }
        // Try ActivityMonitor as last resort
        if (restingHR == 0) {
            var hrHistory = SensorHistory.getHeartRateHistory({:period => 1});
            if (hrHistory != null) {
                var minHr = hrHistory.getMin();
                if (minHr != null) { restingHR = minHr.toNumber(); }
            }
        }

        currentRoundData = new RoundData();
        updateTimer = new Timer.Timer();
    }

    function capturePreSessionMetrics() {
        // Capture recovery time before session starts
        var amInfo = ActivityMonitor.getInfo();
        if (amInfo != null && amInfo has :timeToRecovery && amInfo.timeToRecovery != null) {
            timeToRecovery = amInfo.timeToRecovery;
        }
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
            // Wider window — stress may not update every second during activity
            var iter = SensorHistory.getStressHistory({:period => 5, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (iter != null) {
                // Find first valid sample
                var sample = iter.next();
                while (sample != null) {
                    if (sample.data != null && sample.data > 0) {
                        return sample.data.toNumber();
                    }
                    sample = iter.next();
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

        // Create FIT custom fields
        // RECORD fields (per-second graphs)
        fitPhase = session.createField("Phase", 0, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => ""});
        fitRecovery = session.createField("Recovery", 1, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "%"});

        // LAP fields
        fitLapRound = session.createField("Round", 10, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :units => ""});
        fitLapHrMax = session.createField("Lap HR Max", 11, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "bpm"});
        fitLapHrAvg = session.createField("Lap HR Avg", 12, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "bpm"});

        // SESSION fields
        fitRounds = session.createField("Sauna Rounds", 20, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => ""});
        fitAvgRecovery = session.createField("Avg HR Recovery", 21, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "bpm"});
        fitBBBefore = session.createField("BB Before", 22, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => ""});
        fitBBAfter = session.createField("BB After", 23, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => ""});
        fitStressBefore = session.createField("Stress Before", 24, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => ""});
        fitStressAfter = session.createField("Stress After", 25, FitContributor.DATA_TYPE_UINT8,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => ""});

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

        // Read stress, body battery, recovery every 10s (or first tick)
        if (sessionElapsed == 1 || sessionElapsed % 10 == 0) {
            // Try ActivityMonitor first for stress (works during activity)
            var amInfo = ActivityMonitor.getInfo();
            if (amInfo != null) {
                if (amInfo has :stressScore && amInfo.stressScore != null) {
                    currentStress = amInfo.stressScore;
                }
                if (amInfo has :timeToRecovery && amInfo.timeToRecovery != null) {
                    timeToRecovery = amInfo.timeToRecovery;
                }
            }
            // Fallback to SensorHistory if still 0
            if (currentStress == 0) {
                currentStress = _getLatestStress();
            }
            currentBodyBattery = _getLatestBodyBattery();
        }

        // Record temp every 30s for graph
        if (currentTemp != 0 && sessionElapsed % 30 == 0) {
            tempHistory.add(currentTemp);
            if (tempHistory.size() > TEMP_HISTORY_MAX) {
                tempHistory = tempHistory.slice(tempHistory.size() - TEMP_HISTORY_MAX, null);
            }
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

            // Track min HR during rest for recovery indicator
            if (phase == PHASE_REST && currentRound > 0) {
                if (currentHR < restHrMin) { restHrMin = currentHR; }
                // Vibrate when recovery target reached
                if (!_recoveryAlerted && getRecoveryPercent() >= 100) {
                    _recoveryAlerted = true;
                    if (Attention has :vibrate) {
                        Attention.vibrate([
                            new Attention.VibeProfile(50, 200),
                            new Attention.VibeProfile(0, 100),
                            new Attention.VibeProfile(50, 200)
                        ]);
                    }
                }
            }
        }

        if (phase == PHASE_SAUNA) {
            currentRoundData.saunaDuration = phaseElapsed;
        } else if (currentRound > 0) {
            currentRoundData.restDuration = phaseElapsed;
        }

        // Write FIT RECORD fields every second
        if (fitPhase != null) { fitPhase.setData(phase == PHASE_SAUNA ? 1 : 0); }
        if (fitRecovery != null) {
            var recPct = getRecoveryPercent();
            fitRecovery.setData(recPct > 255 ? 255 : recPct);
        }

        if (onUpdate != null) {
            onUpdate.invoke();
        }
    }

    function toggleLap() {
        if (phase == PHASE_REST) {
            // End rest phase → start sauna
            // Write LAP FIT data before addLap
            if (currentRound > 0) {
                _writeLapFitData();
                if (session != null) { session.addLap(); }
                rounds.add(currentRoundData);
            } else {
                // Close the READY/warm-up period as its own lap
                if (session != null) { session.addLap(); }
            }
            currentRound++;
            currentRoundData = new RoundData();
            phase = PHASE_SAUNA;
            phaseElapsed = 0;

            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 500)]);
            }
        } else {
            // End sauna phase → start rest
            // Write LAP FIT data before addLap
            _writeLapFitData();
            if (session != null) { session.addLap(); }

            currentRoundData.hrAtSaunaEnd = currentHR;
            hrAtSaunaEnd = currentHR;
            restHrMin = 999;
            _recoveryAlerted = false;
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

        // Write SESSION FIT data before stop
        _writeSessionFitData();

        Sensor.enableSensorEvents(null);

        if (session != null) { session.stop(); }

        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 1000)]);
        }
    }

    hidden function _writeLapFitData() {
        if (fitLapRound != null) { fitLapRound.setData(currentRound); }
        if (fitLapHrMax != null) { fitLapHrMax.setData(currentRoundData.hrMax); }
        if (fitLapHrAvg != null) { fitLapHrAvg.setData(currentRoundData.getHrAvg()); }
    }

    hidden function _writeSessionFitData() {
        if (fitRounds != null) { fitRounds.setData(rounds.size()); }
        if (fitAvgRecovery != null) { fitAvgRecovery.setData(getAvgHrRecovery()); }
        if (fitBBBefore != null) { fitBBBefore.setData(bodyBatteryBefore); }
        if (fitBBAfter != null) { fitBBAfter.setData(bodyBatteryAfter); }
        if (fitStressBefore != null) { fitStressBefore.setData(stressBefore); }
        if (fitStressAfter != null) { fitStressAfter.setData(stressAfter); }
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

    // How much HR dropped from sauna end
    function getHrDrop() {
        if (hrAtSaunaEnd == 0 || currentHR <= 0) { return 0; }
        var drop = hrAtSaunaEnd - currentHR;
        return drop > 0 ? drop : 0;
    }

    // Recovery: how close HR is to resting state + minimum time
    // 0% = HR at sauna end, 100% = HR reached restingHR+10
    // Minimum 3 min rest required regardless of HR
    function getRecoveryPercent() {
        if (hrAtSaunaEnd == 0 || currentHR <= 0) { return 0; }
        if (phase != PHASE_REST) { return 0; }

        // HR component: how close to resting
        var targetHR = restingHR > 0 ? restingHR + 10 : 70;
        var totalRange = hrAtSaunaEnd - targetHR;
        if (totalRange <= 0) { totalRange = 30; }
        var currentDrop = hrAtSaunaEnd - currentHR;
        if (currentDrop < 0) { currentDrop = 0; }
        var hrPct = (currentDrop * 100) / totalRange;
        if (hrPct > 100) { hrPct = 100; }

        // Time component: minimum 7 min rest (420s)
        var minRestTime = 420;
        var timePct = (phaseElapsed * 100) / minRestTime;
        if (timePct > 100) { timePct = 100; }

        // Both must be met: take the lower one
        return hrPct < timePct ? hrPct : timePct;
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
