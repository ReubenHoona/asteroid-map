// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: the log of every call made through a DBusInterface double, in
// order (bus, service, path, iface, method, signature, args as plain values).
// It outlives the interfaces, so calls made while an app is destroyed stay.
// The replies and errors the doubles give (see DBusInterface.qml), and the bus
// signals a test plays (emitSignal) to the interfaces that take signals.
pragma Singleton
import QtQuick

QtObject {
    property var calls: []
    //! "iface.method" or "method": the reply value, or a function of the plain arguments
    property var replies: ({})
    //! "iface.method" or "method": the call fails (the error callback)
    property var errors: ({})
    property var listeners: []
    signal called(var call)

    function record(c) {
        var log = calls
        log.push(c)
        calls = log
        called(c)
    }
    function reset() {
        calls = []
        replies = ({})
        errors = ({})
    }
    // the calls of one method (and, when given, to one service)
    function of(method, service) {
        return calls.filter(function (c) {
            return c.method === method && (service === undefined || c.service === service)
        })
    }
    function listen(o) {
        if (listeners.indexOf(o) < 0)
            listeners.push(o)
    }
    function unlisten(o) {
        var i = listeners.indexOf(o)
        if (i >= 0)
            listeners.splice(i, 1)
    }
    //! the bus signal name(args) of iface, to every interface of iface that takes signals; how many took it
    function emitSignal(iface, name, args) {
        var n = 0
        var all = listeners.slice()
        for (var i = 0; i < all.length; i++) {
            var o = all[i]
            if (o.iface !== iface || !o.signalsEnabled || typeof o["rc" + name] !== "function")
                continue
            o["rc" + name].apply(o, args || [])
            n++
        }
        return n
    }
}
