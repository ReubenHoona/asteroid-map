/*
 * Copyright (C) 2026 eos-mainline contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick

/*
 * What the map says about the position fix, as stock Maps does
 * (strings LOCATION_NOT_YET_AVAILABLE "Waiting for location..." and
 * cant_detect_location "Can't detect your location"):
 *
 *   "fix"      there is a position: nothing is said
 *   "idle"     the source is not running and no fix was asked for: nothing
 *   "off"      Settings > Location is off: no fix is asked for, nothing runs
 *   "waiting"  the source runs, or a fix was asked for, and none has come
 *   "failed"   still none after waitTimeout, or the source reported an error
 *
 * One single-shot timer, running only while a fix is awaited; no polling.
 * A fix that arrives later ends "failed".
 */
QtObject {
    id: status

    //! /org/asteroidos/settings/location-enabled (CR-21); false: stock's
    //! "Enable watch location?" state, no fix is ever asked for
    property bool locationEnabled: true
    //! PositionSource.active
    property bool sourceActive: false
    //! the position is a valid coordinate
    property bool hasFix: false
    //! PositionSource.sourceError is not NoError
    property bool sourceError: false
    //! ms to wait for a fix before "Can't detect your location"
    property int waitTimeout: 30000

    property bool requested: false
    property bool timedOut: false

    readonly property bool pending: locationEnabled && !hasFix && (sourceActive || requested)
    //! the position source works for this app: the launcher's "location in
    //! use" claim (CR-04 SetInUse("location")) follows it; a fix that was
    //! asked for and did not come in time, or whose source failed, no longer counts
    readonly property bool inUse: locationEnabled && (sourceActive || (requested && !timedOut && !hasFix && !sourceError))
    readonly property string state: !locationEnabled ? "off"
        : hasFix ? "fix"
        : !pending ? "idle"
        : (sourceError || timedOut) ? "failed" : "waiting"

    //! the user asked for a fix (the locate button)
    function request() {
        if (!locationEnabled || hasFix)
            return
        requested = true
        timedOut = false
        if (pending)
            wait.restart()
    }

    onPendingChanged: {
        if (pending) {
            timedOut = false
            wait.restart()
        } else {
            wait.stop()
            requested = false
            timedOut = false
        }
    }

    property Timer _wait: Timer {
        id: wait
        interval: status.waitTimeout
        repeat: false
        onTriggered: status.timedOut = true
    }
}
