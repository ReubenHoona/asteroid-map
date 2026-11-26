// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: QtLocation's Plugin. It loads no geo service (the image's osm
// plugin would fetch map tiles from the internet): it only keeps the name and
// the parameters the app gives, for the tests to read.
import QtQuick

QtObject {
    id: plugin
    property string name
    property var preferred: []
    readonly property bool isAttached: true
    default property list<QtObject> parameters

    //! the value of the parameter called key, undefined when there is none
    function parameter(key) {
        for (var i = 0; i < parameters.length; i++)
            if (parameters[i].name === key)
                return parameters[i].value
        return undefined
    }
}
