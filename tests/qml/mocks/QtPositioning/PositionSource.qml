// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: QtPositioning's PositionSource without a positioning backend
// (the image's geoclue plugins would talk to the build host's buses). Same
// names and enum values as Qt 6's; the state follows Qt 6's rules:
//   update()  a single request: active until it ends (fix, error, timeout);
//             the last error is reset when a request starts
//   start()   regular updates until stop()
//   stop()    ends both (the double cancels a single request too)
// The test ends a request with fix(lat, lon), fail(error) or timeOut() and
// reads what the app asked in updateCalls, startCalls and stopCalls.
import QtQuick

QtObject {
    id: source

    // values as Qt 6's QGeoPositionInfoSource (0xff, 0xffffff00, 0xffffffff as int)
    enum PositioningMethod {
        NoPositioningMethods = 0,
        SatellitePositioningMethods = 255,
        NonSatellitePositioningMethods = -256,
        AllPositioningMethods = -1
    }
    enum SourceError {
        AccessError = 0,
        ClosedError = 1,
        UnknownSourceError = 2,
        NoError = 3,
        UpdateTimeoutError = 4
    }

    property string name: "test"
    readonly property bool valid: true
    property bool active: false
    property int updateInterval: 0
    property int preferredPositioningMethods: -1
    readonly property int supportedPositioningMethods: -1
    property int sourceError: 3
    property var position: ({ coordinate: QtPositioning.coordinate(), latitudeValid: false,
                              longitudeValid: false, timestamp: undefined })

    // what the app asked for
    property int updateCalls: 0
    property int startCalls: 0
    property int stopCalls: 0
    property var lastTimeout: undefined
    property bool _single: false
    property bool _regular: false

    function update(timeout) {
        updateCalls++
        lastTimeout = timeout
        sourceError = 3
        if (!active) {
            _single = true
            active = true
        }
    }
    function start() {
        startCalls++
        sourceError = 3
        _regular = true
        active = true
    }
    function stop() {
        stopCalls++
        _regular = false
        _single = false
        active = false
    }

    // ---- the test drives the backend ----
    //! a position arrives; a single request ends
    function fix(latitude, longitude) {
        position = { coordinate: QtPositioning.coordinate(latitude, longitude), latitudeValid: true,
                     longitudeValid: true, timestamp: new Date() }
        if (_single) {
            _single = false
            if (!_regular)
                active = false
        }
    }
    //! the backend reports an error: AccessError and ClosedError stop the source,
    //! UpdateTimeoutError ends a single request (active goes first, then the error)
    function fail(error) {
        if (error === 0 || error === 1) {
            _single = false
            _regular = false
            active = false
        } else if (error === 4 && _single) {
            _single = false
            if (!_regular)
                active = false
        }
        sourceError = error
    }
    //! the backend's own timeout for a single request
    function timeOut() { fail(4) }
}
