// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: QtSensors' Compass without a sensor backend (the image's
// sensorfw and iio-sensor-proxy plugins would talk to the build host's system
// bus). reading is null until the test gives one with setReading(azimuth,
// calibrationLevel); a new reading is a new object, so readingChanged fires
// for each, as the real sensor's.
import QtQuick

QtObject {
    property bool active: false
    property bool alwaysOn: false
    property string identifier
    readonly property bool connectedToBackend: true
    property var reading: null

    property int startCalls: 0
    function start() { startCalls++; active = true; return true }
    function stop() { active = false }

    function setReading(azimuth, calibrationLevel) {
        reading = { azimuth: azimuth, calibrationLevel: calibrationLevel, timestamp: Date.now() }
    }
}
