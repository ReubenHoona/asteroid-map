// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: Nemo.DBus' DBusInterface. Nothing reaches a bus: each call is recorded in DBusLog
// with the interface's bus, service, path and iface, the method, the D-Bus signature of the
// arguments and their plain values. A reply comes back (the callback, after the call, as on the bus)
// only for a method a test gave one in DBusLog.replies ("iface.method" or "method": a value, or a
// function of the plain arguments); a method in DBusLog.errors calls the error callback. While
// signals are enabled the object takes DBusLog.emitSignal(iface, name, args): Nemo.DBus calls the
// object's function "rc" + the signal name.
import QtQuick

QtObject {
    id: obj
    property int bus: DBus.SessionBus
    property string service
    property string path
    property string iface
    property bool signalsEnabled: false
    property bool propertiesEnabled: false

    onSignalsEnabledChanged: signalsEnabled ? DBusLog.listen(obj) : DBusLog.unlisten(obj)
    Component.onCompleted: if (signalsEnabled) DBusLog.listen(obj)
    Component.onDestruction: DBusLog.unlisten(obj)

    function _answer(method, values, callback, errorCallback) {
        var key = iface + "." + method
        if (DBusLog.errors.hasOwnProperty(key) || DBusLog.errors.hasOwnProperty(method)) {
            if (errorCallback)
                Qt.callLater(function () { errorCallback() })
            return
        }
        var r = DBusLog.replies.hasOwnProperty(key) ? DBusLog.replies[key]
              : DBusLog.replies.hasOwnProperty(method) ? DBusLog.replies[method] : undefined
        if (r === undefined || !callback)
            return
        var v = typeof r === "function" ? r(values) : r
        Qt.callLater(function () { callback(v) })
    }
    function typedCall(method, args, callback, errorCallback) {
        var types = [], values = []
        for (var i = 0; args && i < args.length; i++) {
            types.push(args[i].type)
            values.push(args[i].value)
        }
        DBusLog.record({ bus: bus, service: service, path: path, iface: iface, method: method,
                         signature: types.join(""), args: values, typed: true })
        _answer(method, values, callback, errorCallback)
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
        _answer(method, values, callback, errorCallback)
        return true
    }
}
