// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: Nemo.Configuration ConfigurationValue on ConfStore. Reads the stored value or the
// default, follows writes to its key, stores what the app assigns.
import QtQuick
import Nemo.Configuration

QtObject {
    id: cv
    property string key
    property var defaultValue
    property var value
    property bool _sync: false

    function _load() {
        _sync = true
        value = ConfStore.has(key) ? ConfStore.get(key) : defaultValue
        _sync = false
    }
    function sync() {}
    onKeyChanged: _load()
    onDefaultValueChanged: if (!ConfStore.has(key)) _load()
    onValueChanged: if (!_sync && key !== "") ConfStore.appWrite(key, value)
    Component.onCompleted: _load()
    property Connections _watch: Connections {
        target: ConfStore
        function onChanged(k) { if (k === cv.key) cv._load() }
    }
}
