// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Waypoints: the pin button's set point controls (SetPointMapControls), the
// waypoint page (SetPointPage: add, edit, remove; the name field with the stock
// full screen keyboard, text-input-24; the icon choice; dates in the system
// 12/24 hour format) and the pins on the map (MapWaypoint) drawn from dconf
// /map/waypointList, which keeps per waypoint [icon, [latitude, longitude],
// colour, name, time saved]. The whole app on the doubles of mocks/.
// Fixtures: invented names, coordinates 0,0 or a few thousandths of a degree
// from it (open sea).
import QtQuick
import QtTest
import QtPositioning
import Nemo.Configuration
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
        name: "Waypoints"
        host: host

        readonly property string use12h: "/org/asteroidos/settings/use-12h-format"
        // two stored waypoints: a light and a dark colour
        readonly property var twoPoints: [
            ["ios-bicycle", [0.001, 0.002], "#ffffff", "Test Point", "2026-11-14T13:05:00.000Z"],
            ["ios-boat-outline", [0, 0], "#202020", "Sample Point", "2026-11-15T08:30:00.000Z"]
        ]

        function cleanup() {
            ConfStore.set(use12h, false)
        }
        function withList(list, more) {
            var c = more || {}
            c[listKey] = JSON.stringify(list)
            return c
        }
        function stored() { return JSON.parse(ConfStore.get(listKey)) }
        function page() { return named("saveWaypoint") ? stack().currentLayer : null }
        function nameField() { return find(stack().currentLayer, function (x) { return x.hasOwnProperty("previewText") }) }
        //! the page's header text ("Add waypoint" or "Edit waypoint")
        function pageTitle() {
            var h = find(stack().currentLayer, function (x) { return /^(Add|Edit) waypoint$/.test(String(x.text)) && isShown(x) })
            return h ? h.text : ""
        }
        function iconList() {
            return find(stack().currentLayer, function (x) { return x.hasOwnProperty("orientation") && x.orientation === ListView.Horizontal })
        }
        //! the icon choices made so far (the list makes its buttons as they come into view)
        function iconButtons() {
            return findAll(iconList().contentItem, function (x) { return x.hasOwnProperty("variant") && x.hasOwnProperty("iconName") })
        }
        //! the icon names of the list, in order
        function iconNames() {
            var lv = iconList(), n = []
            for (var i = 0; i < lv.count; i++)
                n.push(lv.model.get(i).name)
            return n
        }
        //! scroll the icon list to the icon and tap it, as a finger would
        function chooseIcon(name) {
            var lv = iconList()
            var i = iconNames().indexOf(name)
            verify(i >= 0, name)
            lv.positionViewAtIndex(i, ListView.Center)
            wait(50)
            var b = lv.itemAtIndex(i)
            verify(b, "the button of " + name)
            tap(b, name)
            return b
        }
        function openNewPage() {
            tapNamed("pin")
            tap(shownNamed("confirm"), "confirm")
            settle()
            verify(named("saveWaypoint"), "the waypoint page")
        }
        function dateLabel() {
            return find(stack().currentLayer, function (x) { return x.hasOwnProperty("wrapMode") && x.visible && /2026/.test(x.text) })
        }

        // ------------------------------------------------ the set point controls
        function test_pin_shows_the_set_point_controls() {
            startApp()
            tapNamed("pin")
            compare(shownNamed("pin"), undefined)
            compare(shownNamed("menu"), undefined)
            var ok = shownNamed("confirm"), close = shownNamed("close"), cross = shownNamed("cross")
            verify(ok && close && cross, "confirm, close and the cross")
            compare(ok.variant, "filled")
            compare(close.variant, "tonal")
            compare(ok.size, Theme.size.iconButtonSmall)
            var c = cross.mapToItem(app, cross.width / 2, cross.height / 2)
            near(c.x, 192, 0.5, "cross x")
            near(c.y, 192, 0.5, "cross y")
            compare(cross.width, Theme.size.iconSmall)
            // the header says what it is for
            var header = find(app, function (x) { return x.text === "Add waypoint" && isShown(x) })
            verify(header, "the Add waypoint header")
            // the zoom buttons still work
            var z = theMap().zoomLevel
            tapNamed("zoomIn")
            near(theMap().zoomLevel, z + 0.3, 1e-6, "zoom in")
            // close: back to the map controls, nothing saved
            tap(close)
            verify(shownNamed("pin"), "the map controls are back")
            compare(shownNamed("confirm"), undefined)
            compare(ConfStore.writesOf(listKey).length, 0)
        }

        // ------------------------------------------------ add
        function test_add_a_waypoint() {
            startApp({ "/map/view/location/lat": 1000, "/map/view/location/long": 2000 })
            near(theMap().center.latitude, 0.001, 1e-9, "centre")
            openNewPage()
            compare(pageTitle(), "Add waypoint")
            var field = nameField()
            compare(field.previewText, "Waypoint name")
            compare(field.height, Theme.size.button)
            // the default name: the date and the time
            verify(/^\S.*, \d{1,2}:\d\d/.test(field.text), "default name: " + field.text)
            // no date line and no remove button for a new one
            compare(isShown(named("removeWaypoint")), false)
            // the icons: the first is chosen (filled), the others plain
            compare(iconNames(), ["ios-locate-outline", "ios-checkmark", "ios-help", "ios-information",
                                  "ios-body-outline", "ios-bicycle", "ios-car-outline", "ios-boat-outline"])
            var icons = iconButtons()
            verify(icons.length >= 4, "icon buttons made: " + icons.length)
            for (var i = 0; i < icons.length; i++) {
                var chosen = icons[i].iconName === "ios-locate-outline"
                compare(icons[i].variant, chosen ? "filled" : "plain")
                sameColor(icons[i].iconColor, chosen ? Theme.color.onPrimary : Theme.color.onSurfaceVariant,
                          icons[i].iconName)
                compare(icons[i].size, Theme.size.iconButtonSmall)
            }
            var first = iconList().itemAtIndex(0)
            var bike = chooseIcon("ios-bicycle")
            compare(bike.variant, "filled")
            compare(first.variant, "plain")
            field.text = "Test Point"
            var save = named("saveWaypoint")
            compare(save.variant, "filled")
            compare(save.size, Theme.size.iconButton)
            tap(save)
            settle()
            // stored: [icon, [lat, lon], colour, name, time]
            var list = stored()
            compare(list.length, 1)
            compare(list[0][0], "ios-bicycle")
            near(list[0][1][0], 0.001, 1e-9, "latitude")
            near(list[0][1][1], 0.002, 1e-9, "longitude")
            sameColor(list[0][2], Theme.color.primary, "default colour")
            compare(list[0][3], "Test Point")
            verify(Math.abs(new Date(list[0][4]).getTime() - Date.now()) < 120000, "saved now: " + list[0][4])
            compare(ConfStore.writesOf(listKey).length, 1)
            // back on the map with its map controls and the new pin
            compare(stack().layers.length, 0)
            verify(shownNamed("pin"), "the map controls")
            compare(shownNamed("confirm"), undefined)
            compare(waypointItems().length, 1)
        }
        function test_add_appends() {
            startApp(withList(twoPoints))
            openNewPage()
            tap(named("saveWaypoint"))
            settle()
            var list = stored()
            compare(list.length, 3)
            compare(list[0][3], "Test Point")
            compare(list[1][3], "Sample Point")
            compare(waypointItems().length, 3)
        }
        function test_the_name_field_opens_the_stock_keyboard() {
            startApp()
            openNewPage()
            var field = nameField()
            compare(field.fullScreenKeyboard, true)
            tap(field)
            var kb = field._keyboard
            verify(kb, "the full screen keyboard")
            verify(String(kb).indexOf("WearKeyboard") === 0, "a WearKeyboard: " + kb)
            compare(kb.placeholderText, "Waypoint name")
            compare(findAll(root.Window.contentItem, function (x) { return String(x).indexOf("HandWritingKeyboard") === 0 }).length, 0)
            // its tick writes the name back
            kb.accepted("Sample Point")
            compare(field.text, "Sample Point")
            tryCompare(field, "_keyboard", null, 3000)
            tap(named("saveWaypoint"))
            settle()
            compare(stored()[0][3], "Sample Point")
        }

        // ------------------------------------------------ the pins on the map
        function test_pins_from_dconf() {
            startApp(withList(twoPoints))
            var m = theMap()
            var pins = waypointItems()
            compare(pins.length, 2)
            for (var i = 0; i < 2; i++) {
                var p = pins.filter(function (x) { return x.index === i })[0]
                verify(p, "pin " + i)
                compare(p.iconName, twoPoints[i][0])
                sameColor(p.iconColor, twoPoints[i][2], "pin colour")
                compare(p.zoomLevel, 0)
                // the tip of the pin (bottom centre) is on the coordinate
                var at = m.fromCoordinate(QtPositioning.coordinate(twoPoints[i][1][0], twoPoints[i][1][1]), false)
                var tip = p.mapToItem(m, p.width / 2, p.height)
                near(tip.x, at.x, 0.5, "pin x")
                near(tip.y, at.y, 0.5, "pin y")
                compare(p.sourceItem.width, Theme.dp(24))
                compare(p.sourceItem.iconName, "waypoint")
            }
            // the pin is dark on a light colour, light on a dark one
            var light = pins.filter(function (x) { return x.index === 0 })[0]
            var dark = pins.filter(function (x) { return x.index === 1 })[0]
            sameColor(light.sourceItem.iconColor, Theme.color.surfaceContainer, "pin on a light colour")
            sameColor(dark.sourceItem.iconColor, Theme.color.onSurface, "pin on a dark colour")
            // the position marker stays on the map with them
            compare(m.mapItems.length, 3)
        }
        function test_pins_follow_dconf() {
            startApp()
            compare(waypointItems().length, 0)
            ConfStore.set(listKey, JSON.stringify(twoPoints))
            compare(waypointItems().length, 2)
            ConfStore.set(listKey, JSON.stringify([twoPoints[1]]))
            compare(waypointItems().length, 1)
            compare(waypointItems()[0].iconName, "ios-boat-outline")
            ConfStore.set(listKey, "[]")
            compare(waypointItems().length, 0)
            compare(theMap().mapItems.length, 1)
        }

        // ------------------------------------------------ edit and remove
        function test_a_pin_opens_its_page() {
            startApp(withList(twoPoints))
            var pin = waypointItems().filter(function (x) { return x.index === 1 })[0]
            tap(pin.sourceItem, "the pin")
            settle()
            verify(named("saveWaypoint"), "the waypoint page")
            compare(pageTitle(), "Edit waypoint")
            compare(nameField().text, "Sample Point")
            verify(isShown(named("removeWaypoint")), "the remove button")
            var chosen = iconButtons().filter(function (b) { return b.variant === "filled" })
            compare(chosen.length, 1)
            compare(chosen[0].iconName, "ios-boat-outline")
            verify(dateLabel(), "the date line")
        }
        function test_edit_saves_in_place() {
            startApp(withList(twoPoints))
            mainView().editWaypoint(0)
            settle()
            nameField().text = "Edited Point"
            chooseIcon("ios-car-outline")
            tap(named("saveWaypoint"))
            settle()
            var list = stored()
            compare(list.length, 2)
            compare(list[0][0], "ios-car-outline")
            compare(list[0][1], twoPoints[0][1])
            compare(list[0][2], twoPoints[0][2])
            compare(list[0][3], "Edited Point")
            compare(list[1][3], "Sample Point")
            compare(stack().layers.length, 0)
        }
        function test_remove_takes_one() {
            startApp(withList(twoPoints.concat([["ios-help", [0, 0.001], "#202020", "Third Point", "2026-11-16T10:00:00.000Z"]])))
            mainView().editWaypoint(0)
            settle()
            tap(named("removeWaypoint"))
            settle()
            var list = stored()
            compare(list.length, 2)
            compare(list[0][3], "Sample Point")
            compare(list[1][3], "Third Point")
            compare(waypointItems().length, 2)
            compare(stack().layers.length, 0)
            verify(shownNamed("pin"), "the map controls")
        }

        // ------------------------------------------------ 12/24 hour (settings-b-28)
        function test_dates_follow_the_system_format() {
            // stored 14 Nov 2026 13:05 UTC (the runner's zone)
            var c = withList(twoPoints)
            c[use12h] = true
            startApp(c)
            ConfStore.set(use12h, true)
            mainView().editWaypoint(0)
            settle()
            var label = dateLabel()
            verify(label, "the date line")
            verify(/1:05\s?[ap]m$/i.test(label.text), "12 hour: " + label.text)
            verify(!/01:05/.test(label.text), "no leading zero: " + label.text)
            verify(/14/.test(label.text), "the day: " + label.text)
            // the page takes the format when it opens
            stack().pop(stack().currentLayer)
            settle()
            ConfStore.set(use12h, false)
            mainView().editWaypoint(0)
            settle()
            label = dateLabel()
            verify(label, "the date line")
            verify(/13:05$/.test(label.text), "24 hour: " + label.text)
        }
        function test_new_name_has_the_time() {
            startApp()
            ConfStore.set(use12h, true)
            openNewPage()
            verify(/^\S.*, \d{1,2}:\d\d\s?[ap]m$/i.test(nameField().text), "12 hour: " + nameField().text)
        }

        // ------------------------------------------------ pictures
        function test_pictures() {
            // the time at the top, as the image sets it
            startApp(withList(twoPoints, { "/org/asteroidos/ux/time-text": true }))
            wait(200)
            grabImage(screen).save("shots/map-pins.png")
            tapNamed("pin")
            wait(100)
            grabImage(screen).save("shots/map-set-point.png")
            tap(shownNamed("confirm"))
            settle()
            grabImage(screen).save("shots/map-waypoint-page.png")
        }
    }
}
