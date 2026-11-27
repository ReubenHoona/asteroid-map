// Copyright (C) 2026 eos
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The phone's trip on the watch (R5 D-02, apps-misc-10): Gadgetbridge sends the next turn of a
// Google Maps navigation as the assistant relay's PhoneEvent "nav" (AsteroidOSNavigation:
// {"st":"nav","ins","di","dm","act","eta","tt","dt","pc"} or {"st":"end"}); the Maps app shows it on
// its trip screen (NavigationPage: the manoeuvre glyph, the distance, the step, "ETA %1 · %2", Exit),
// opens it by itself when a trip starts (Auto-launch, /map/autoLaunch, on by default; the launcher's
// NavAutoLaunch opens the app with /map/open "nav") and closes it when the trip ends. At start it asks
// btsyncd where the trip is (PhoneEventState "nav"). The whole app on the doubles of mocks/; the bus
// signals are played with DBusLog.emitSignal. Invented streets and times only.
import QtQuick
import QtTest
import Nemo.Configuration
import Nemo.DBus
import org.asteroid.controls
import "../../src"

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
    // the manoeuvre glyphs side by side, for the look review
    Component {
        id: glyphSheet
        Rectangle {
            width: 384
            height: 384
            color: "black"
            property alias grid: grid
            Grid {
                id: grid
                anchors.centerIn: parent
                columns: 5
                spacing: 6
            }
        }
    }
    Component { id: glyphComponent; ManeuverIcon {} }

    MapCase {
        id: tc
        name: "Navigation"
        host: host

        readonly property string assistant: "org.asteroidos.btsyncd.Assistant"
        readonly property var turn: ({ st: "nav", ins: "Turn left onto Elm Way", di: "100 m", dm: 100, act: "left",
                                       eta: "11:55", tt: 780, dt: "4.6 mi", pc: 35 })
        property int closed: 0

        function navEvent(o) {
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", JSON.stringify(o)])
            wait(30)
        }
        function link() { return named("phoneLink") }
        function navPage() { return named("navigationPage") }
        function shownNav() { var p = navPage(); return p && isShown(p) ? p : undefined }
        //! the app opened for a trip (the launcher's request), btsyncd answering with state
        function startForTrip(conf, state) {
            ConfStore.reset()
            DBusLog.reset()
            conf = conf || {}
            if (!conf.hasOwnProperty("/map/open"))
                conf["/map/open"] = "nav@" + Date.now()
            for (var k in conf)
                ConfStore.set(k, conf[k])
            // null: an older btsyncd (no PhoneEventState)
            if (state === null)
                DBusLog.errors[assistant + ".PhoneEventState"] = true
            else if (state !== undefined)
                DBusLog.replies[assistant + ".PhoneEventState"] = state
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            verify(c.status === Component.Ready, c.errorString())
            app = createTemporaryObject(c, host, { width: 384, height: 384 })
            verify(app, "the app")
            closed = 0
            app.closeApp = function () { tc.closed++ }
            tryVerify(function () { return navPage() !== undefined }, 5000, "the trip screen")
            wait(80)
        }
        function startPlain(conf, state) {
            ConfStore.reset()
            DBusLog.reset()
            for (var k in (conf || {}))
                ConfStore.set(k, conf[k])
            if (state !== undefined)
                DBusLog.replies[assistant + ".PhoneEventState"] = state
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            verify(c.status === Component.Ready, c.errorString())
            app = createTemporaryObject(c, host, { width: 384, height: 384 })
            verify(app, "the app")
            closed = 0
            app.closeApp = function () { tc.closed++ }
            tryVerify(function () { return mainView() !== undefined }, 5000, "the map page")
            wait(80)
        }
        //! the trip screen pushed over the map has gone (the stock pop transition ran)
        function popped() {
            tryVerify(function () { return stack().layers.length === 0 }, 3000, "popped")
            wait(30)
        }
        //! scrolled to the end of the trip screen, where Exit is; then tapped
        function tapExit() {
            var f = named("navFlickable")
            f.contentY = f.contentHeight - f.height
            wait(50)
            var e = named("navExit"), p = e.mapToItem(app, 0, 0)
            verify(p.y >= 0 && p.y + e.height <= 384, "Exit in view at " + p.y)
            tap(e, "Exit")
        }
        function text(n) { var o = named(n); return o && isShown(o) ? o.text : undefined }

        // ------------------------------------------------ a trip while the map shows
        function test_a_trip_opens_the_trip_screen() {
            startPlain()
            compare(shownNav(), undefined, "no trip, no trip screen")
            compare(DBusLog.of("PhoneEventState").length, 1, "where the trip is: asked once at start")
            compare(DBusLog.of("PhoneEventState")[0].args, ["nav"])
            navEvent(turn)
            settle()
            verify(shownNav(), "the trip screen opened by itself (Auto-launch on by default)")
            compare(stack().currentLayer.objectName, "navigationPage")
            compare(text("navHeadline"), "100 m")
            compare(text("navInstruction"), "Turn left onto Elm Way")
            compare(text("navFooter"), "ETA 11:55 · 4.6 mi")
            compare(named("navManeuver").act, "left")
            compare(named("navManeuver").shown, "left")
            compare(text("navStarting"), undefined)
            compare(named("navExit").text, "Exit")
            // at rest the step fills the screen; Exit is under it
            compare(named("navFlickable").contentY, 0)
            verify(named("navExit").mapToItem(app, 0, 0).y >= 384, "Exit under the step")
            compare(named("navExit").containerColor, Theme.color.error)
            // the next turn changes the screen in place
            navEvent({ st: "nav", ins: "Keep right at the fork", di: "350 m", act: "keep_right", eta: "11:56" })
            compare(text("navHeadline"), "350 m")
            compare(text("navInstruction"), "Keep right at the fork")
            compare(text("navFooter"), "ETA 11:56")
            compare(named("navManeuver").shown, "keep_right")
            compare(stack().layers.length, 1, "still one trip screen")
            // the end: back to the map
            navEvent({ st: "end" })
            popped()
            compare(shownNav(), undefined, "the trip screen closed")
            verify(isShown(mainView()), "the map")
            compare(closed, 0, "the app the user opened stays")
        }

        function test_auto_launch_off() {
            startPlain({ "/map/autoLaunch": false })
            navEvent(turn)
            settle()
            compare(shownNav(), undefined, "Auto-launch off: the map stays")
            verify(link().navigating, "the trip is known")
            navEvent({ st: "end" })
            verify(!link().navigating)
        }

        function test_other_events_and_bad_json_change_nothing() {
            startPlain()
            DBusLog.emitSignal(assistant, "PhoneEvent", ["cam", "{\"ev\":\"shot\"}"])
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", "not json"])
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", "{\"st\":\"what\"}"])
            wait(50)
            verify(!link().navigating)
            compare(shownNav(), undefined)
        }

        function test_exit_and_the_next_turns() {
            startPlain()
            navEvent(turn)
            settle()
            verify(shownNav())
            tapExit()
            popped()
            compare(shownNav(), undefined, "Exit leaves the trip screen")
            verify(link().navigating, "the phone goes on navigating")
            // more turns of the same trip do not open it again
            navEvent({ st: "nav", ins: "Turn right onto Birch Lane", di: "50 m", act: "right" })
            settle()
            compare(shownNav(), undefined)
            // a turn after 10 minutes without one is a new trip: it opens again
            link().tripAt = Date.now() - 11 * 60000
            navEvent({ st: "nav", ins: "Head north", di: "20 m", act: "continue" })
            settle()
            verify(shownNav(), "a new trip opens the screen")
        }

        // ------------------------------------------------ opened by the launcher for a trip
        function test_opened_for_a_trip() {
            var st = JSON.parse(JSON.stringify(turn))
            st.age = 5
            startForTrip({}, JSON.stringify(st))
            compare(stack().firstPageItem.objectName, "navigationPage", "the trip screen is the first page")
            compare(mainView(), undefined, "the map is not made")
            compare(compass().active, false, "no compass without a map")
            compare(source().active, false, "no position")
            compare(ConfStore.writesOf("/map/open"), [""], "the request is taken once")
            tryCompare(link(), "navigating", true, 3000)
            compare(text("navHeadline"), "100 m")
            near(link().tripAt, Date.now() - 5000, 1500, "the age counts back")
            // the end: the app opened for the trip closes
            navEvent({ st: "end" })
            compare(closed, 1, "closed at the end")
        }

        function test_opened_for_a_trip_then_exit() {
            startForTrip({}, JSON.stringify({ st: "nav", ins: "Turn left onto Elm Way", di: "100 m", act: "left", age: 1 }))
            tryCompare(link(), "navigating", true, 3000)
            tapExit()
            tryVerify(function () { return mainView() !== undefined }, 5000, "the map after Exit")
            compare(shownNav(), undefined)
            compare(compass().active, true, "the map's compass")
            navEvent({ st: "end" })
            compare(closed, 0, "the user is on the map: the app stays")
        }

        // btsyncd has the end, nothing, or a trip 10 minutes old: the map
        function test_opened_for_a_trip_that_ended_data() {
            return [{ tag: "end", state: JSON.stringify({ st: "end", age: 2 }) },
                    { tag: "none", state: "" },
                    { tag: "stale", state: JSON.stringify({ st: "nav", ins: "Head north", di: "20 m", age: 700 }) }]
        }
        function test_opened_for_a_trip_that_ended(data) {
            startForTrip({}, data.state)
            tryVerify(function () { return mainView() !== undefined }, 5000, "the map")
            settle()
            compare(shownNav(), undefined)
            verify(!link().navigating)
            compare(closed, 0)
        }

        // a request left from long ago (the app did not start then) is not taken as one
        function test_a_stale_request() {
            ConfStore.reset()
            DBusLog.reset()
            ConfStore.set("/map/open", "nav@" + (Date.now() - 120000))
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            app = createTemporaryObject(c, host, { width: 384, height: 384 })
            tryVerify(function () { return mainView() !== undefined }, 5000, "the map, not the trip screen")
            compare(navPage(), undefined)
            compare(ConfStore.writesOf("/map/open"), [""], "cleared")
        }

        // a request while the app runs: the trip screen
        function test_a_request_while_running() {
            startPlain({ "/map/autoLaunch": false })
            ConfStore.set("/map/open", "nav@" + Date.now())
            tryVerify(function () { return shownNav() !== undefined }, 3000, "the trip screen")
            compare(ConfStore.get("/map/open"), "")
        }

        function test_an_older_btsyncd() {
            // no PhoneEventState: the screen waits for the next turn, "Starting navigation…"
            startForTrip({}, null)
            tryCompare(link(), "stateKnown", true, 3000)
            wait(50)
            verify(shownNav(), "still the trip screen")
            compare(text("navStarting"), "Starting navigation…")
            compare(text("navHeadline"), undefined)
            compare(named("navManeuver").visible, false)
            navEvent(turn)
            compare(text("navStarting"), undefined)
            compare(text("navHeadline"), "100 m")
        }

        function test_opened_during_a_trip() {
            // the user opens the app while the phone navigates: the trip, also with Auto-launch off
            startPlain({ "/map/autoLaunch": false }, JSON.stringify({ st: "nav", ins: "Head north", di: "20 m", act: "continue", age: 3 }))
            tryVerify(function () { return shownNav() !== undefined }, 3000, "the trip screen")
            settle()
            compare(stack().layers.length, 1, "over the map")
            tapExit()
            popped()
            verify(isShown(mainView()), "the map under it")
        }

        function test_phone_gone() {
            startPlain()
            navEvent(turn)
            settle()
            verify(shownNav())
            // the phone's link drops: no end comes, the trip is over
            compare(DBusLog.emitSignal("org.asteroidos.btsyncd.Phone", "ConnectedChanged", [false]), 1)
            popped()
            verify(!link().navigating)
            compare(shownNav(), undefined)
            // the phone's signals are taken only during a trip
            compare(DBusLog.emitSignal("org.asteroidos.btsyncd.Phone", "ConnectedChanged", [false]), 0)
        }

        // ------------------------------------------------ the words
        function test_states() {
            startPlain()
            navEvent({ st: "nav", ins: "Elm Way", di: "10 m", act: "finish", eta: "12:01" })
            settle()
            compare(text("navHeadline"), "Arrived")
            compare(named("navManeuver").shown, "finish")
            navEvent({ st: "nav", ins: "Elm Way", act: "offroute" })
            compare(text("navHeadline"), "Rerouting...")
            compare(text("navFooter"), undefined, "no arrival known: no footer")
            // no time from the phone: the seconds left from now, in the system format
            navEvent({ st: "nav", ins: "Head north", di: "20 m", tt: 600 })
            compare(text("navFooter"), "ETA " + TimeFormat.time(new Date(link().tripAt + 600000)))
            compare(named("navManeuver").shown, "", "no manoeuvre: the navigation arrow")
            // the distance left alone
            navEvent({ st: "nav", ins: "Head north", di: "20 m", dt: "2 km" })
            compare(text("navFooter"), "2 km")
        }

        function test_every_manoeuvre_has_a_glyph() {
            var names = ["continue", "left", "left_slight", "left_sharp", "right", "right_slight", "right_sharp",
                         "keep_left", "keep_right", "uturn_left", "uturn_right", "roundabout_right", "roundabout_left",
                         "roundabout_straight", "roundabout_uturn", "merge", "offroute", "finish"]
            var g = createTemporaryObject(glyphComponent, root)
            for (var i = 0; i < names.length; i++) {
                g.act = names[i]
                compare(g.shown, names[i], names[i] + " has a drawing")
            }
            g.act = "teleport"
            compare(g.shown, "", "an unknown one: the arrow")
            compare(g.width, Theme.dp(48), "48 dp")
        }

        // ------------------------------------------------ Settings: the Auto-launch switch
        function test_auto_launch_switch() {
            startPlain()
            tapNamed("menu")
            settle()
            var sw = named("autoLaunchSwitch")
            verify(sw && isShown(sw), "the switch")
            compare(sw.text, "Auto-launch")
            compare(sw.checked, true, "on by default")
            compare(text("autoLaunchCaption"), "When navigating on your phone, auto-launch the trip on watch")
            named("settingsFlickable").contentY = Math.max(0, sw.y - Theme.dp(60))
            wait(50)
            tap(sw, "the switch")
            compare(ConfStore.writesOf("/map/autoLaunch"), [false])
            compare(sw.checked, false)
        }

        // ------------------------------------------------ battery
        function test_nothing_runs_for_the_trip() {
            startForTrip({}, JSON.stringify({ st: "nav", ins: "Head north", di: "20 m", act: "continue", age: 1 }))
            tryCompare(link(), "navigating", true, 3000)
            var calls = DBusLog.calls.length
            wait(1500)
            compare(DBusLog.calls.length, calls, "no call while nothing comes")
            var timers = findAll(navPage(), function (x) { return x.hasOwnProperty("interval") && x.hasOwnProperty("repeat") && x.running })
            compare(timers.length, 0, "no timer runs on the trip screen")
            var running = findAll(navPage(), function (x) { return x.hasOwnProperty("running") && x.running === true })
            compare(running.length, 0, "no animation runs on the trip screen")
        }

        // ------------------------------------------------ pictures
        function test_picture_starting() {
            startForTrip({ "/org/asteroidos/ux/time-text": true }, null)
            tryCompare(link(), "stateKnown", true, 3000)
            wait(300)
            verify(shownNav())
            grabImage(screen).save("shots/nav-starting.png")
        }
        function test_picture_settings() {
            startPlain({ "/org/asteroidos/ux/time-text": true })
            tapNamed("menu")
            settle()
            var f = named("settingsFlickable")
            f.contentY = Math.max(0, named("autoLaunchSwitch").y - Theme.dp(40))
            wait(200)
            grabImage(screen).save("shots/settings-autolaunch.png")
        }
        function test_picture_glyphs() {
            var sheet = createTemporaryObject(glyphSheet, root)
            var names = ["continue", "left", "left_slight", "left_sharp", "right", "right_slight", "right_sharp",
                         "keep_left", "keep_right", "uturn_left", "uturn_right", "roundabout_right", "roundabout_left",
                         "roundabout_straight", "roundabout_uturn", "merge", "offroute", "finish", ""]
            for (var i = 0; i < names.length; i++)
                glyphComponent.createObject(sheet.grid, { act: names[i], width: 64, height: 64 })
            wait(200)
            grabImage(sheet).save("shots/nav-glyphs.png")
        }
        function test_pictures() {
            startPlain({ "/org/asteroidos/ux/time-text": true })
            navEvent(turn)
            settle()
            wait(300)
            var img = grabImage(screen)
            img.save("shots/nav-turn.png")
            // the glyph is white ink in the top middle
            var ink = 0
            for (var x = 150; x < 234; x++)
                for (var y = 48; y < 144; y++) {
                    var p = Qt.color(img.pixel(x, y))
                    if (p.r + p.g + p.b > 2.4)
                        ink++
                }
            verify(ink > 200, "the manoeuvre is drawn: " + ink)
            navEvent({ st: "nav", ins: "Turn right onto a street with a long name that needs two lines",
                       di: "1.2 km", act: "roundabout_right", eta: "12:10", dt: "12 km" })
            wait(200)
            grabImage(screen).save("shots/nav-long.png")
            navEvent({ st: "nav", ins: "Elm Way", di: "10 m", act: "finish", eta: "12:01" })
            wait(200)
            grabImage(screen).save("shots/nav-arrived.png")
        }
    }
}
