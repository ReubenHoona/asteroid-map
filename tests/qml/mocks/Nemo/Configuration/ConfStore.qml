// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: the dconf database behind the ConfigurationValue double. set() is a write from outside
// the app (btsyncd, eos-weather, the phone); writes the app makes are logged in writes ([key, value]).
pragma Singleton
import QtQuick

QtObject {
    property var values: ({})
    property var writes: []
    signal changed(string key)

    function has(key) { return values.hasOwnProperty(key) }
    function get(key) { return values[key] }
    function set(key, value) {
        values[key] = value
        changed(key)
    }
    function unset(key) {
        delete values[key]
        changed(key)
    }
    function appWrite(key, value) {
        values[key] = value
        writes.push([key, value])
        changed(key)
    }
    function writesOf(key) {
        return writes.filter(function (w) { return w[0] === key }).map(function (w) { return w[1] })
    }
    function reset() {
        values = {}
        writes = []
    }
}
