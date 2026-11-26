// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The map's settings page (SettingsPage, from the menu button): a stock CP3A
// Settings list (ListHeader, Material 3 switch rows 4 dp apart, captions), the
// Compass switch (/map/enableCompass: the compass sensor and the compass
// button's modes) and the Use GPS switch (/map/prioritiseGPS: satellite or
// all positioning methods), the OpenStreetMap credits. The whole app on the
// doubles of mocks/.
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
        name: "Settings"
        host: host

        function openSettings(conf) {
            startApp(conf)
            tapNamed("menu")
            settle()
            verify(named("settingsFlickable"), "the settings page")
        }

        function test_layout_and_texts() {
            openSettings({ "/org/asteroidos/ux/time-text": true })
            var title = named("title")
            compare(title.text, "Map settings")
            var column = title.parent
            near(column.y, Theme.margin.listTop, 0.5, "list top")
            near(column.x, Theme.margin.listSide, 0.5, "list side")
            near(column.y, 0.1664 * 384, 1, "list top 16.64 %")
            near(column.x, 0.052 * 384, 1, "list side 5.2 %")
            compare(column.spacing, Theme.space.xs)
            var flick = named("settingsFlickable")
            compare(flick.contentHeight, column.y + column.height + Theme.margin.listBottom)
            var sw1 = named("compassSwitch"), sw2 = named("gpsSwitch")
            compare(sw1.text, "Compass")
            compare(sw2.text, "Use GPS")
            compare(sw1.width, column.width)
            verify(sw1.height >= Theme.size.button, "a 52 dp row")
            // top to bottom: title, Compass, Use GPS, the credits
            verify(title.y < sw1.y && sw1.y < sw2.y && sw2.y < named("caption").y, "order")
            var cap = named("caption")
            compare(cap.role, "bodySmall")
            sameColor(cap.color, Theme.color.onSurfaceVariant, "caption")
            compare(cap.text, "Map Data © OpenStreetMap contributors\nunder the ODbL")
            // the upstream author's credit: two lines under the licence
            compare(named("credit").text.split("\n").length, 2)
            verify(named("credit").y > cap.y, "the credit under the licence")
            grabImage(screen).save("shots/map-settings.png")
        }
        function test_switches_show_the_settings() {
            openSettings()
            compare(named("compassSwitch").checked, true)
            compare(named("gpsSwitch").checked, true)
            openSettings({ "/map/enableCompass": false, "/map/prioritiseGPS": false })
            compare(named("compassSwitch").checked, false)
            compare(named("gpsSwitch").checked, false)
        }
        function test_compass_switch() {
            openSettings()
            compare(compass().active, true)
            tap(named("compassSwitch"))
            compare(ConfStore.writesOf("/map/enableCompass"), [false])
            compare(named("compassSwitch").checked, false)
            // the sensor stops
            compare(compass().active, false)
            tap(named("compassSwitch"))
            compare(ConfStore.writesOf("/map/enableCompass"), [false, true])
            compare(compass().active, true)
        }
        function test_gps_switch() {
            openSettings()
            compare(source().preferredPositioningMethods, PositionSource.SatellitePositioningMethods)
            tap(named("gpsSwitch"))
            compare(ConfStore.writesOf("/map/prioritiseGPS"), [false])
            compare(source().preferredPositioningMethods, PositionSource.AllPositioningMethods)
            tap(named("gpsSwitch"))
            compare(ConfStore.writesOf("/map/prioritiseGPS"), [false, true])
            compare(source().preferredPositioningMethods, PositionSource.SatellitePositioningMethods)
            // nothing is asked for by the switches
            compare(source().updateCalls, 0)
            compare(source().startCalls, 0)
        }
        function test_back_to_the_map() {
            openSettings()
            stack().pop(stack().currentLayer)
            settle()
            tryVerify(function () { return stack().layers.length === 0 }, 3000, "popped")
            verify(shownNamed("menu"), "the map controls")
        }
    }
}
