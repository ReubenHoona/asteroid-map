// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: the QtPositioning singleton. coordinate() gives a plain object
// with latitude, longitude, altitude and isValid (computed when read, as the
// real geoCoordinate's), so the app's coordinates stay inside the test.
pragma Singleton
import QtQuick

QtObject {
    function coordinate(latitude, longitude, altitude) {
        return {
            latitude: latitude === undefined ? NaN : Number(latitude),
            longitude: longitude === undefined ? NaN : Number(longitude),
            altitude: altitude === undefined ? NaN : Number(altitude),
            get isValid() {
                return isFinite(this.latitude) && isFinite(this.longitude)
                        && Math.abs(this.latitude) <= 90 && Math.abs(this.longitude) <= 180
            },
            toString: function () { return "coordinate(" + this.latitude + ", " + this.longitude + ")" }
        }
    }
}
