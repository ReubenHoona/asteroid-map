// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: the log of every call made through a DBusInterface double, in
// order (bus, service, path, iface, method, signature, args as plain values).
// It outlives the interfaces, so calls made while an app is destroyed stay.
pragma Singleton
import QtQuick

QtObject {
    property var calls: []
    signal called(var call)

    function record(c) {
        var log = calls
        log.push(c)
        calls = log
        called(c)
    }
    function reset() { calls = [] }
    // the calls of one method (and, when given, to one service)
    function of(method, service) {
        return calls.filter(function (c) {
            return c.method === method && (service === undefined || c.service === service)
        })
    }
}
