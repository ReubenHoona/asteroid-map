// Copyright (C) 2026 eos
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The Maps home (R5 D-13, stock M-1): the app opens on it (stock's start destination
// home_screen_route), with the map and search buttons, Home and Work, the phone's trip while it
// navigates, and Settings; search types the place on the stock keyboard; the directions page hands
// the trip to the phone (the relay's act "nav" with the travel mode, as the launcher's assistant)
// and the app says "Check your phone" (stock's open-on-phone confirmation). The Maps tile's request
// (/map/open "map") opens the map itself; the launcher's Search Maps complication (/map/open "search",
// R6 A-16) opens the search over the home. The whole app on the doubles of mocks/; the phone's answers
// are DBusLog replies and the relay's ActResult signal. Invented places only.
import QtQuick
import QtTest
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
        name: "Home"
        host: host

        readonly property string assistant: "org.asteroidos.btsyncd.Assistant"
        readonly property var allActions: ["nav", "contacts", "sms", "call", "hangup", "convs", "msgs"]

        //! the app as it opens from the app list: the home
        function startHome(conf, replies) {
            ConfStore.reset()
            DBusLog.reset()
            for (var k in (conf || {}))
                ConfStore.set(k, conf[k])
            for (var r in (replies || {}))
                DBusLog.replies[r] = replies[r]
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            verify(c.status === Component.Ready, c.errorString())
            app = createTemporaryObject(c, host, { width: 384, height: 384 })
            verify(app, "the app")
            tryVerify(function () { return home() !== undefined }, 5000, "the home")
            wait(80)
            return app
        }
        function home() { return named("homePage") }
        //! the one called n on screen (the list keeps rows it does not show)
        function shown(n) { return shownNamed(n) }
        function popped() {
            tryVerify(function () { return stack().layers.length === 0 }, 3000, "popped")
            wait(30)
        }
        //! the directions page for Home, the phone answering Actions with these
        function openHomeDirections(actions) {
            startHome({}, { "org.asteroidos.btsyncd.Assistant.Actions": actions === undefined ? allActions : actions,
                            "org.asteroidos.btsyncd.Assistant.Act": true })
            tap(shown("homeHome"), "Home")
            settle()
            verify(shown("directionsPage"), "the directions page")
        }
        //! the Act the app sent: its id and its action object
        function lastAct() {
            var a = DBusLog.of("Act")
            if (!a.length)
                return null
            var c = a[a.length - 1]
            return { id: c.args[0], js: JSON.parse(c.args[1]), sig: c.signature }
        }
        function answer(result) {
            var a = lastAct()
            verify(a, "an Act was sent")
            DBusLog.emitSignal(assistant, "ActResult", [a.id, JSON.stringify(result)])
            wait(30)
        }

        // ------------------------------------------------ the home
        function test_opens_on_the_home() {
            startHome()
            compare(mainView(), undefined, "no map made at start")
            compare(compass().active, false, "no compass")
            compare(source().active, false, "no position")
            compare(stack().firstPageItem.objectName, "homePage")
            compare(ConfStore.writesOf("/map/open").length, 0, "no request to take")
            var names = ["homeMap", "homeSearch", "homeHome", "homeWork", "homeSettings"]
            for (var i = 0; i < names.length; i++)
                verify(shown(names[i]), names[i])
            compare(shown("homeTrip"), undefined, "no trip row without a trip")
            compare(shown("homeMap").Accessible.name, "Open map view")
            compare(shown("homeSearch").Accessible.name, "Start search")
            compare(shown("homeHome").Accessible.name, "Home")
            compare(shown("homeWork").Accessible.name, "Work")
            compare(shown("homeSettings").text, "Settings")
            compare(shown("homeMap").iconName, "ios-map-outline")
            compare(shown("homeSearch").iconName, "ios-search")
            compare(shown("homeHome").iconName, "ios-home")
            compare(shown("homeWork").iconName, "ios-briefcase")
            // stock's rows: 52 dp, the pairs side by side 4 dp apart, each half the row
            var m = shown("homeMap"), s = shown("homeSearch"), h = shown("homeHome"), w = shown("homeWork")
            near(m.height, Theme.dp(52), 0.5, "row height")
            near(h.height, Theme.dp(52), 0.5, "row height")
            near(m.width, s.width, 0.5, "halves")
            var mp = m.mapToItem(app, 0, 0), sp = s.mapToItem(app, 0, 0), hp = h.mapToItem(app, 0, 0), wp = w.mapToItem(app, 0, 0)
            near(sp.x - (mp.x + m.width), Theme.dp(4), 0.6, "4 dp between map and search")
            near(wp.x - (hp.x + h.width), Theme.dp(4), 0.6, "4 dp between Home and Work")
            verify(hp.y > mp.y, "Home and Work under map and search")
            near(mp.y, sp.y, 0.5)
            near(hp.y, wp.y, 0.5)
            // the map and the settings
            tap(m, "the map button")
            settle()
            verify(mainView() && isShown(mainView()), "the map over the home")
            compare(compass().active, true, "the map's compass")
            stack().pop(stack().currentLayer)
            popped()
            compare(mainView(), undefined, "the map page went")
            compare(compass().active, false)
            tap(shown("homeSettings"), "Settings")
            settle()
            verify(shown("settingsFlickable"), "the settings")
        }

        function test_the_tile_opens_the_map() {
            // the Maps tile's request: the map is the first page, at once; the request is taken
            startApp({ "/map/open": "map@" + Date.now() })
            compare(stack().firstPageItem.objectName, "mainMapView")
            compare(home(), undefined)
            compare(ConfStore.writesOf("/map/open"), [""])
        }

        // ------------------------------------------------ search
        function test_search_types_the_place() {
            startHome({}, { "org.asteroidos.btsyncd.Assistant.Actions": allActions, "org.asteroidos.btsyncd.Assistant.Act": true })
            tap(shown("homeSearch"), "search")
            settle()
            var f = named("searchField")
            verify(f, "the search field")
            tryVerify(function () { return f._keyboard !== null }, 3000, "the keyboard at once")
            var kb = f._keyboard
            verify(String(kb).indexOf("WearKeyboard") === 0, "the stock keyboard: " + kb)
            compare(kb.placeholderText, "Search…")
            kb.accepted("Riverbend Park")
            settle()
            var d = shown("directionsPage")
            verify(d, "the directions for it")
            compare(d.query, "Riverbend Park")
            compare(shown("directionsTitle").text, "Riverbend Park")
            compare(shown("directionsHeader").text, "Directions")
            // nothing typed: nothing happens
            stack().pop(stack().currentLayer)
            wait(50)
            named("searchPage").submit("   ")
            wait(50)
            compare(stack().currentLayer.objectName, "searchPage")
        }

        function test_search_maps_request_at_start() {
            // the Search Maps complication: the home first, the search over it with the keyboard at once
            startHome({ "/map/open": "search@" + Date.now() })
            compare(stack().firstPageItem.objectName, "homePage")
            tryVerify(function () { return stack().currentLayer && stack().currentLayer.objectName === "searchPage" },
                      3000, "the search over the home")
            compare(stack().layers.length, 1)
            compare(ConfStore.writesOf("/map/open"), [""], "the request taken")
            compare(mainView(), undefined, "no map made")
            var f = named("searchField")
            tryVerify(function () { return f._keyboard !== null }, 3000, "the keyboard at once")
            // back: the home
            stack().pop(stack().currentLayer)
            popped()
            verify(shown("homeSearch"), "the home")
        }

        function test_search_maps_request_while_open() {
            startHome()
            // the map over the home, then the complication's request: what was over the home goes
            tap(shown("homeMap"), "the map button")
            settle()
            verify(mainView(), "the map")
            ConfStore.set("/map/open", "search@" + Date.now())
            tryVerify(function () { return stack().currentLayer && stack().currentLayer.objectName === "searchPage" },
                      3000, "the search")
            compare(stack().layers.length, 1, "only the search over the home")
            tryVerify(function () { return mainView() === undefined }, 3000, "the map page went")
            // again while the search is up: nothing new
            ConfStore.set("/map/open", "search@" + Date.now())
            wait(100)
            compare(stack().layers.length, 1)
            // a stale request does nothing
            stack().pop(stack().currentLayer)
            popped()
            ConfStore.set("/map/open", "search@" + (Date.now() - 120000))
            wait(100)
            compare(stack().layers.length, 0, "older than 60 s: ignored")
        }

        // ------------------------------------------------ directions
        function test_directions_modes_and_the_act() {
            openHomeDirections()
            compare(shown("directionsTitle").text, "Home")
            var modes = [["modeDriving", "Driving", "ms-directions_car", "driving"],
                         ["modeWalking", "Walking", "ms-directions_walk", "walking"],
                         ["modeCycling", "Cycling", "ms-directions_bike", "bicycling"],
                         ["modeTransit", "Transit", "ios-bus", "transit"]]
            for (var i = 0; i < modes.length; i++) {
                var b = shown(modes[i][0])
                verify(b, modes[i][0])
                compare(b.text, modes[i][1])
                compare(b.iconName, modes[i][2])
            }
            var walk = shown("modeWalking")
            tap(walk, "Walking")
            tryVerify(function () { return lastAct() !== null }, 3000, "the act")
            var a = lastAct()
            compare(a.sig, "us")
            compare(a.js, { a: "nav", q: "home", mode: "walking" })
            compare(named("directionsPage").sending, true)
            compare(walk.enabled, false, "one at a time")
            // the phone started it: back to the home, "Check your phone"
            answer({ ok: true, app: "google", how: "started" })
            tryVerify(function () { return stack().layers.length === 0 }, 3000, "back to the home")
            var c = named("openOnPhone")
            tryCompare(c, "shown", true, 3000)
            compare(c.type, "openOnPhone")
            compare(c.text, "Check your phone")
        }

        function test_work_and_the_notification() {
            startHome({}, { "org.asteroidos.btsyncd.Assistant.Actions": allActions, "org.asteroidos.btsyncd.Assistant.Act": true })
            tap(shown("homeWork"), "Work")
            settle()
            compare(shown("directionsTitle").text, "Work")
            tap(shown("modeDriving"), "Driving")
            tryVerify(function () { return lastAct() !== null }, 3000)
            compare(lastAct().js, { a: "nav", q: "work", mode: "driving" })
            // the phone could not open it by itself: a notification to tap on the phone
            answer({ ok: true, app: "google", how: "notification" })
            tryCompare(named("openOnPhone"), "shown", true, 3000)
            compare(stack().layers.length, 0)
        }

        function test_failures_data() {
            return [
                { tag: "no-phone", actions: [], connected: false, result: null,
                  text: "Your phone isn't connected. Directions need your phone." },
                { tag: "old-app", actions: [], connected: true, result: null,
                  text: "Update Gadgetbridge on your phone to do this from the watch." },
                { tag: "no-maps", actions: undefined, result: { ok: false, er: "no-maps" },
                  text: "There's no maps app on your phone. Install Google Maps to get directions." },
                { tag: "timeout", actions: undefined, result: { ok: false, er: "timeout" }, text: "Couldn't start navigation" },
                { tag: "disconnected", actions: undefined, result: { ok: false, er: "disconnected" },
                  text: "Your phone isn't connected. Directions need your phone." }
            ]
        }
        function test_failures(data) {
            openHomeDirections(data.actions)
            if (data.connected !== undefined)
                DBusLog.replies["org.asteroidos.btsyncd.Phone.Connected"] = data.connected
            tap(shown("modeDriving"), "Driving")
            if (data.result)
                answer(data.result)
            tryCompare(named("directionsPage"), "sending", false, 3000)
            compare(shown("directionsError").text, data.text)
            compare(named("openOnPhone").shown, false, "no confirmation")
            verify(shown("directionsPage"), "the page stays: a mode again tries again")
            compare(shown("modeDriving").enabled, true)
        }

        function test_the_act_refused() {
            // btsyncd refuses the Act (the phone went between the two calls)
            openHomeDirections()
            DBusLog.replies["org.asteroidos.btsyncd.Assistant.Act"] = false
            tap(shown("modeDriving"), "Driving")
            tryCompare(named("directionsPage"), "sending", false, 3000)
            compare(shown("directionsError").text, "Your phone isn't connected. Directions need your phone.")
        }

        // ------------------------------------------------ the trip on the home
        function test_the_trip_row() {
            startHome({ "/map/autoLaunch": false })
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", JSON.stringify({ st: "nav", ins: "Turn left onto Elm Way",
                                                                             di: "100 m", act: "left", eta: "11:55" })])
            tryVerify(function () { return shown("homeTrip") !== undefined }, 3000, "the trip row")
            var t = shown("homeTrip")
            compare(t.text, "ETA 11:55")
            compare(t.secondaryText, "Turn left onto Elm Way")
            compare(t.iconName, "ms-navigation")
            compare(shown("navigationPage"), undefined, "Auto-launch off: the home stays")
            tap(t, "the trip row")
            settle()
            verify(shown("navigationPage"), "the trip screen")
            // no time yet: "Navigating…"
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", JSON.stringify({ st: "nav", ins: "Head north", di: "20 m" })])
            stack().pop(stack().currentLayer)
            popped()
            compare(shown("homeTrip").text, "Navigating…")
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", JSON.stringify({ st: "end" })])
            tryVerify(function () { return shown("homeTrip") === undefined }, 3000, "the row goes with the trip")
        }

        // ------------------------------------------------ battery
        function test_nothing_runs_on_the_home() {
            startHome()
            var calls = DBusLog.calls.length
            compare(DBusLog.calls.map(function (c) { return c.method }), ["PhoneEventState"], "one question at start")
            wait(1500)
            compare(DBusLog.calls.length, calls, "nothing asked while nothing happens")
            var timers = findAll(home(), function (x) { return x.hasOwnProperty("interval") && x.hasOwnProperty("repeat") && x.running })
            compare(timers.length, 0, "no timer on the home")
        }

        // ------------------------------------------------ pictures
        function test_picture_home() {
            startHome({ "/org/asteroidos/ux/time-text": true })
            wait(300)
            grabImage(screen).save("shots/home.png")
        }
        function test_picture_home_trip() {
            startHome({ "/org/asteroidos/ux/time-text": true, "/map/autoLaunch": false })
            DBusLog.emitSignal(assistant, "PhoneEvent", ["nav", JSON.stringify({ st: "nav", ins: "Turn left onto Elm Way",
                                                                             di: "100 m", act: "left", eta: "11:55" })])
            tryVerify(function () { return shown("homeTrip") !== undefined }, 3000)
            wait(300)
            grabImage(screen).save("shots/home-trip.png")
        }
        function test_picture_search() {
            startHome({ "/org/asteroidos/ux/time-text": true })
            tap(shown("homeSearch"))
            settle()
            tryVerify(function () { return named("searchField")._keyboard !== null }, 3000)
            wait(500)
            grabImage(screen).save("shots/search-keyboard.png")
        }
        function test_picture_directions() {
            openHomeDirections()
            wait(300)
            grabImage(screen).save("shots/directions.png")
            DBusLog.replies["org.asteroidos.btsyncd.Assistant.Act"] = false
            tap(shown("modeDriving"))
            tryCompare(named("directionsPage"), "sending", false, 3000)
            wait(200)
            grabImage(screen).save("shots/directions-error.png")
        }
        function test_picture_check_your_phone() {
            openHomeDirections()
            tap(shown("modeWalking"))
            tryVerify(function () { return lastAct() !== null }, 3000)
            answer({ ok: true, app: "google", how: "started" })
            tryCompare(named("openOnPhone"), "shown", true, 3000)
            wait(900)
            grabImage(screen).save("shots/check-your-phone.png")
        }
    }
}
