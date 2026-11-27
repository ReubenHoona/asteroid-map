// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The location rules of the map (FP-A5), the whole app on the doubles of
// mocks/ (no positioning backend, no bus, no tiles):
// - CR-21: dconf /org/asteroidos/settings/location-enabled false is stock Maps'
//   "location is off" state ("Enable watch location?") and no fix is asked
//   (no update() or start() of the PositionSource); true: the locate button
//   asks; switched at run time both ways.
// - CR-04: SetInUse("location", true) on org.asteroidos.launcher,
//   /org/asteroidos/launcher/ongoing, org.asteroidos.launcher.Ongoing (session
//   bus) while the map asks for a fix, SetInUse("location", false) when it
//   stops asking (a fix, an error, the wait over, the switch off, the app
//   closed); in pairs, no repeats, nothing at start.
// - LocationStatus: the states behind "Waiting for location..." and "Can't
//   detect your location".
// Fixtures: coordinates 0,0 only.
import QtQuick
import QtTest
import QtPositioning
import Nemo.Configuration
import Nemo.DBus
import org.asteroid.controls

Item {
    id: root
    width: 384
    height: 384

    Rectangle { anchors.fill: parent; color: "black" }
    Item {
        id: screen
        anchors.fill: parent
        clip: true
        Item { id: host; anchors.fill: parent }
        // the round edge of the watch
        Canvas {
            anchors.fill: parent
            z: 100
            onPaint: {
                var ctx = getContext("2d")
                ctx.fillStyle = "#000000"
                ctx.beginPath()
                ctx.rect(0, 0, width, height)
                ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI, true)
                ctx.fill()
            }
        }
    }

    MapCase {
        id: tc
        name: "Location"
        host: host

        function off(v) { var c = {}; c[locationKey] = v; return c }
        function newStatus(timeout) {
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/LocationStatus.qml"))
            verify(c.status === Component.Ready, c.errorString())
            var s = createTemporaryObject(c, tc, timeout === undefined ? {} : { waitTimeout: timeout })
            verify(s)
            return s
        }
        function locate() { tapNamed("locate") }

        // ------------------------------------------------ CR-21: the switch
        function test_on_by_default_and_nothing_asked_at_start() {
            startApp()
            compare(mainView().locationOn, true)
            compare(status().state, "idle")
            compare(source().updateCalls, 0)
            compare(source().startCalls, 0)
            compare(source().active, false)
            compare(dialog().shown, false)
            compare(named("locationNote").visible, false)
            // nothing on the bus but the one question to btsyncd where the phone's trip is (R5 D-02,
            // answered from its memory)
            compare(DBusLog.calls.map(function (c) { return c.method }), ["PhoneEventState"])
            compare(launcherCalls().length, 0)
        }
        function test_off_at_start_data() {
            return [ { tag: "bool false", value: false }, { tag: "string false", value: "false" } ]
        }
        function test_off_at_start(data) {
            startApp(off(data.value))
            compare(mainView().locationOn, false)
            compare(status().state, "off")
            compare(status().pending, false)
            // stock Maps' enable_location_title, a check and a close x
            tryCompare(dialog(), "shown", true, 3000)
            compare(dialog().title, "Enable watch location?")
            compare(dialog().buttons, "confirmDismiss")
            compare(source().updateCalls, 0)
            compare(source().startCalls, 0)
            compare(source().active, false)
            compare(named("locationNote").visible, false)
            compare(claims().length, 0)
        }
        function test_off_the_locate_button_asks_nothing() {
            startApp(off(false))
            var d = dialog()
            tryCompare(d, "shown", true, 3000)
            tap(d.dismissButton, "the dismiss button")
            tryCompare(d, "shown", false, 3000)
            settleDialog(d)
            // nothing was written: the switch stays off
            compare(ConfStore.writesOf(locationKey).length, 0)
            locate()
            // the dialog again, no request, no source, no pill, no claim
            tryCompare(d, "shown", true, 3000)
            compare(status().requested, false)
            compare(status().state, "off")
            compare(source().updateCalls, 0)
            compare(source().active, false)
            compare(named("locationNote").visible, false)
            compare(claims().length, 0)
        }
        function test_off_the_check_turns_location_on() {
            startApp(off(false))
            var d = dialog()
            tryCompare(d, "shown", true, 3000)
            settleDialog(d)
            tap(d.confirmButton, "the confirm button")
            compare(ConfStore.writesOf(locationKey), [true])
            compare(mainView().locationOn, true)
            compare(status().state, "idle")
            // turning it on asks for nothing by itself
            compare(source().updateCalls, 0)
            compare(claims().length, 0)
            tryCompare(d, "shown", false, 3000)
            settleDialog(d)
            locate()
            compare(source().updateCalls, 1)
            compare(status().state, "waiting")
            compare(claimFlags(), [true])
        }
        function test_switched_off_while_asking() {
            startApp()
            locate()
            compare(source().active, true)
            compare(claimFlags(), [true])
            ConfStore.set(locationKey, false)
            // the source is stopped, the state is off, the claim released
            verify(source().stopCalls >= 1, "the source is stopped")
            compare(source().active, false)
            compare(status().state, "off")
            compare(status().pending, false)
            compare(status().requested, false)
            compare(status().inUse, false)
            compare(named("locationNote").visible, false)
            compare(claimFlags(), [true, false])
            // off: the locate button only shows the dialog
            var calls = source().updateCalls
            locate()
            tryCompare(dialog(), "shown", true, 3000)
            compare(source().updateCalls, calls)
            compare(claimFlags(), [true, false])
        }
        function test_switched_on_at_run_time() {
            startApp(off(false))
            tryCompare(dialog(), "shown", true, 3000)
            dialog().close()
            settleDialog(dialog())
            ConfStore.set(locationKey, true)
            compare(mainView().locationOn, true)
            compare(status().state, "idle")
            // nothing is asked until the locate button
            compare(source().updateCalls, 0)
            compare(claims().length, 0)
            locate()
            compare(source().updateCalls, 1)
            compare(claimFlags(), [true])
            // and off again
            ConfStore.set(locationKey, "false")
            compare(status().state, "off")
            compare(claimFlags(), [true, false])
        }

        // ------------------------------------------------ CR-04: the claim
        function test_locate_claims_location_in_use() {
            startApp()
            compare(claims().length, 0)
            locate()
            compare(source().updateCalls, 1)
            compare(status().state, "waiting")
            compare(named("locationNoteText").text, "Waiting for location...")
            compare(launcherCalls().length, 1)
            var c = launcherCalls()[0]
            compare(c.bus, DBus.SessionBus)
            compare(c.service, "org.asteroidos.launcher")
            compare(c.path, "/org/asteroidos/launcher/ongoing")
            compare(c.iface, "org.asteroidos.launcher.Ongoing")
            compare(c.method, "SetInUse")
            compare(c.signature, "sb")
            compare(c.args, ["location", true])
        }
        function test_a_fix_releases_the_claim() {
            startApp()
            locate()
            source().fix(0, 0)
            compare(status().state, "fix")
            compare(named("locationNote").visible, false)
            compare(claimFlags(), [true, false])
            var c = claims()[1]
            compare(c.service, "org.asteroidos.launcher")
            compare(c.path, "/org/asteroidos/launcher/ongoing")
            compare(c.iface, "org.asteroidos.launcher.Ongoing")
            compare(c.signature, "sb")
            compare(c.args, ["location", false])
            // asking again with a fix: claimed while the source runs, released when it ends
            locate()
            compare(source().active, true)
            compare(claimFlags(), [true, false, true])
            source().fix(0, 0)
            compare(claimFlags(), [true, false, true, false])
            verifyPaired()
        }
        function test_repeated_taps_claim_once() {
            startApp()
            locate()
            locate()
            locate()
            compare(source().updateCalls, 3)
            compare(claimFlags(), [true])
            source().fix(0, 0)
            compare(claimFlags(), [true, false])
        }
        function test_the_wait_ends_with_the_source() {
            startApp()
            status().waitTimeout = 150
            locate()
            // the app's wait is over while the source still asks: "Can't detect
            // your location", and location is still in use (the source runs)
            tryCompare(status(), "state", "failed", 3000)
            compare(named("locationNoteText").text, "Can't detect your location")
            compare(source().active, true)
            compare(claimFlags(), [true])
            // the source gives up: released
            source().timeOut()
            compare(status().inUse, false)
            compare(claimFlags(), [true, false])
        }
        function test_the_wait_ends_without_a_source() {
            startApp()
            status().waitTimeout = 150
            // asked, but the source never started (no backend on the watch)
            status().request()
            compare(source().active, false)
            compare(claimFlags(), [true])
            tryCompare(status(), "state", "failed", 3000)
            compare(claimFlags(), [true, false])
        }
        function test_a_source_error_releases_the_claim_data() {
            return [ { tag: "access", error: PositionSource.AccessError },
                     { tag: "closed", error: PositionSource.ClosedError },
                     { tag: "timeout", error: PositionSource.UpdateTimeoutError } ]
        }
        function test_a_source_error_releases_the_claim(data) {
            startApp()
            locate()
            compare(claimFlags(), [true])
            // the source stops with an error long before the app's 30 s wait
            source().fail(data.error)
            compare(source().active, false)
            compare(status().state, "failed")
            compare(named("locationNoteText").text, "Can't detect your location")
            // nothing asks any more: no "location in use"
            compare(status().inUse, false)
            compare(claimFlags(), [true, false])
            // a new tap asks and claims again
            locate()
            compare(source().active, true)
            compare(status().state, "waiting")
            compare(claimFlags(), [true, false, true])
            source().fix(0, 0)
            compare(claimFlags(), [true, false, true, false])
        }
        function test_closing_the_app_releases_the_claim() {
            var a = startApp()
            locate()
            compare(claimFlags(), [true])
            a.destroy()
            wait(50)
            compare(claimFlags(), [true, false])
            compare(launcherCalls()[1].path, "/org/asteroidos/launcher/ongoing")
        }
        function test_closing_without_a_claim_sends_nothing() {
            var a = startApp()
            a.destroy()
            wait(50)
            compare(launcherCalls().length, 0)
            a = startApp()
            locate()
            source().fix(0, 0)
            a.destroy()
            wait(50)
            compare(claimFlags(), [true, false])
        }
        function test_claim_only_on_change() {
            startApp()
            var mv = mainView()
            mv.claim(true); mv.claim(true); mv.claim(true)
            compare(claimFlags(), [true])
            mv.claim(false); mv.claim(false)
            compare(claimFlags(), [true, false])
        }
        function test_panning_and_zooming_claim_nothing() {
            startApp()
            tapNamed("zoomIn")
            tapNamed("zoomOut")
            mouseDrag(theMap(), 192, 150, 40, 20)
            compare(source().updateCalls, 0)
            compare(launcherCalls().length, 0)
        }

        // ------------------------------------------------ LocationStatus
        function test_status_waiting_then_failed() {
            var s = newStatus(150)
            compare(s.state, "idle")
            compare(s._wait.running, false)
            s.sourceActive = true
            compare(s.state, "waiting")
            compare(s.inUse, true)
            compare(s._wait.running, true)
            tryCompare(s, "state", "failed", 3000)
            compare(s._wait.running, false)
            // a fix that comes late ends it
            s.hasFix = true
            compare(s.state, "fix")
            compare(s._wait.running, false)
            // lost again while the source runs: waiting again, a new wait
            s.hasFix = false
            compare(s.state, "waiting")
            compare(s._wait.running, true)
            s.sourceActive = false
            compare(s.state, "idle")
            compare(s.inUse, false)
            compare(s._wait.running, false)
        }
        function test_status_request() {
            var s = newStatus(150)
            s.request()
            compare(s.state, "waiting")
            compare(s.inUse, true)
            tryCompare(s, "state", "failed", 3000)
            compare(s.inUse, false)
            // asking again starts a new wait
            s.request()
            compare(s.state, "waiting")
            compare(s.inUse, true)
            compare(s._wait.running, true)
            // a fix ends the request
            s.hasFix = true
            compare(s.state, "fix")
            compare(s.requested, false)
            compare(s.inUse, false)
            // with a fix, a request waits for nothing
            s.request()
            compare(s.requested, false)
            compare(s.inUse, false)
            s.hasFix = false
            compare(s.state, "idle")
        }
        function test_status_error() {
            var s = newStatus(5000)
            s.sourceActive = true
            compare(s.state, "waiting")
            s.sourceActive = false
            s.sourceError = true
            compare(s.state, "idle")
            // a request whose source fails: failed at once, not in use
            s.sourceError = false
            s.request()
            s.sourceActive = true
            compare(s.inUse, true)
            s.sourceActive = false
            s.sourceError = true
            compare(s.state, "failed")
            compare(s.inUse, false)
            // the error is cleared by a new request of the source
            s.sourceError = false
            compare(s.state, "waiting")
            compare(s.inUse, true)
        }
        function test_status_off() {
            var s = newStatus(150)
            s.locationEnabled = false
            s.sourceActive = true
            compare(s.state, "off")
            compare(s.pending, false)
            compare(s.inUse, false)
            compare(s._wait.running, false)
            s.request()
            compare(s.requested, false)
            compare(s.state, "off")
            // on again with the source still running: waiting, in use
            s.locationEnabled = true
            compare(s.state, "waiting")
            compare(s.inUse, true)
            // off while a request waits: the request is dropped
            s.sourceActive = false
            s.request()
            compare(s.requested, true)
            s.locationEnabled = false
            compare(s.requested, false)
            compare(s.inUse, false)
            s.locationEnabled = true
            compare(s.state, "idle")
            compare(s.inUse, false)
        }
        function test_status_one_single_shot_timer() {
            // the app's default wait: 30 s
            var s = newStatus()
            compare(s.waitTimeout, 30000)
            compare(s._wait.repeat, false)
            compare(s._wait.interval, 30000)
            compare(s._wait.running, false)
            s.sourceActive = true
            compare(s._wait.running, true)
            s.sourceActive = false
            compare(s._wait.running, false)
        }
    }
}
