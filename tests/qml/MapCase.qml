// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The shared part of the map tests: a TestCase that starts src/main.qml (the
// whole app) in host on the doubles of mocks/ and finds its parts. Not a test
// file itself (the runner runs tst_*.qml).
import QtQuick
import QtTest
import Nemo.Configuration
import Nemo.DBus
import org.asteroid.controls

TestCase {
    id: tc
    when: windowShown

    //! the item the app is created in (384 x 384)
    property Item host
    property var app: null

    readonly property string locationKey: "/org/asteroidos/settings/location-enabled"
    readonly property string listKey: "/map/waypointList"

    // ---- start and find ----
    //! the app with these dconf values written before it starts
    function startApp(conf) {
        ConfStore.reset()
        DBusLog.reset()
        for (var k in (conf || {}))
            ConfStore.set(k, conf[k])
        var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
        verify(c.status === Component.Ready, c.errorString())
        var a = createTemporaryObject(c, host, { width: 384, height: 384 })
        verify(a, "the app")
        app = a
        tryVerify(function () { return mainView() !== undefined }, 5000, "the map page")
        wait(50)
        return a
    }
    //! every object under o (visual children and the other objects it holds) that passes pred
    function findAll(o, pred, out) {
        out = out || []
        if (!o)
            return out
        if (pred(o))
            out.push(o)
        var kids = o.data !== undefined ? o.data : (o.children || [])
        for (var i = 0; i < kids.length; i++)
            findAll(kids[i], pred, out)
        return out
    }
    function find(o, pred) { return findAll(o, pred)[0] }
    function named(n, o) { return find(o || app, function (x) { return x.objectName === n }) }
    //! the visible one called n (the waypoint controls repeat the map controls' names)
    function shownNamed(n, o) {
        return find(o || app, function (x) { return x.objectName === n && x.visible && isShown(x) })
    }
    function isShown(x) {
        for (var p = x; p; p = p.parent)
            if (!p.visible || p.opacity === 0)
                return false
        return true
    }
    function mainView() { return named("mainMapView") }
    function status() { return mainView().location }
    function theMap() { return find(app, function (x) { return x.hasOwnProperty("zoomLevel") && x.hasOwnProperty("plugin") }) }
    function source() { return find(app, function (x) { return x.hasOwnProperty("preferredPositioningMethods") }) }
    function compass() { return find(app, function (x) { return x.hasOwnProperty("alwaysOn") && x.hasOwnProperty("reading") }) }
    function mapPlugin() { return find(app, function (x) { return x.hasOwnProperty("isAttached") && x.hasOwnProperty("parameters") }) }
    function stack() { return named("LayerStack") }
    function dialog() { return named("enableLocationDialog") }
    function waypointItems() {
        return theMap().mapItems.filter(function (i) { return i.hasOwnProperty("iconName") })
    }

    // ---- actions ----
    function tap(item, what) {
        verify(item, what || "the item to tap")
        mouseClick(item)
        wait(30)
    }
    function tapNamed(n) { tap(shownNamed(n), n) }
    //! wait for the page stack to settle after a push or a pop
    function settle() {
        wait(30)
        tryCompare(stack(), "pushing", false, 5000)
        wait(100)
    }
    function settleDialog(d) {
        tryVerify(function () { return !d.active || d.shown }, 5000, "the dialog settles")
        wait(400)
    }

    // ---- the launcher's location claim (CR-04) ----
    //! the calls to the launcher (the app's other call: btsyncd's PhoneEventState at start, R5 D-02)
    function launcherCalls() {
        return DBusLog.calls.filter(function (c) { return c.service === "org.asteroidos.launcher" })
    }
    function claims() { return DBusLog.of("SetInUse") }
    //! the active flags sent so far, in order
    function claimFlags() { return claims().map(function (c) { return c.args[1] }) }
    function lastClaim() { var c = claims(); return c.length ? c[c.length - 1].args[1] : undefined }
    //! true, false, true, ... : never two alike in a row, never a false first
    function verifyPaired() {
        var f = claimFlags()
        for (var i = 0; i < f.length; i++)
            verify(f[i] === (i % 2 === 0), "claims out of pairs: " + JSON.stringify(f))
    }

    // ---- looks ----
    function sameColor(a, b, what) {
        var x = Qt.color(a), y = Qt.color(b)
        verify(Math.abs(x.r - y.r) < 0.004 && Math.abs(x.g - y.g) < 0.004 && Math.abs(x.b - y.b) < 0.004
               && Math.abs(x.a - y.a) < 0.004, (what || "colour") + ": " + x + " is not " + y)
    }
    function near(a, b, tol, what) {
        verify(Math.abs(a - b) <= tol, (what || "") + ": " + a + " is not " + b + " +- " + tol)
    }
    function read(rel) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", Qt.resolvedUrl("../../" + rel), false)
        xhr.send()
        return xhr.responseText
    }
}
