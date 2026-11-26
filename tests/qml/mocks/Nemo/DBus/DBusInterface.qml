// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: Nemo.DBus' DBusInterface. Nothing reaches a bus and no reply
// comes back (callbacks are not called): each call is only recorded in DBusLog
// with the interface's bus, service, path and iface, the method, the D-Bus
// signature of the arguments and their plain values.
import QtQuick

QtObject {
    id: obj
    property int bus: DBus.SessionBus
    property string service
    property string path
    property string iface
    property bool signalsEnabled: false
    property bool propertiesEnabled: false

    function typedCall(method, args, callback, errorCallback) {
        var types = [], values = []
        for (var i = 0; args && i < args.length; i++) {
            types.push(args[i].type)
            values.push(args[i].value)
        }
        DBusLog.record({ bus: bus, service: service, path: path, iface: iface, method: method,
                         signature: types.join(""), args: values, typed: true })
        return true
    }
    function call(method, args, callback, errorCallback) {
        // an untyped call: Qt picks the types (a string is s, a bool b, a number i)
        var types = [], values = []
        for (var i = 0; args && i < args.length; i++) {
            var v = args[i]
            types.push(typeof v === "boolean" ? "b" : typeof v === "number" ? "i" : "s")
            values.push(v)
        }
        DBusLog.record({ bus: bus, service: service, path: path, iface: iface, method: method,
                         signature: types.join(""), args: values, typed: false })
        return true
    }
}
