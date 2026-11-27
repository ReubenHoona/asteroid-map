// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The map screen (MainMapView, DefaultMapControls, main.qml), the whole app on
// the doubles of mocks/: the Map double fetches and draws no tiles, so the
// pictures show no place. The tile source the app sets up (osm, OpenStreetMap's
// own tile server, no providers repository), the view kept in dconf (zoom and
// centre x 1e6), the zoom buttons, crown/wheel zoom and drag, the compass
// modes, a position fix (centre, zoom 15, the marker), the "Waiting for
// location..." / "Can't detect your location" pill, the six buttons (Material 3
// tonal icon buttons inside the round screen), the stock accessible names, the
// dconf keys the app writes, the sources (ids with //% English, tokens) and a
// picture of the main page. Fixtures: coordinates 0,0 or a few thousandths of
// a degree from it (open sea), nothing else.
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
        name: "Map"
        host: host

        readonly property var buttonNames: ["zoomIn", "zoomOut", "compassMode", "locate", "menu", "pin"]

        // ------------------------------------------------ the tile source
        function test_tile_source() {
            startApp()
            var p = mapPlugin()
            verify(p, "the Plugin")
            compare(p.name, "osm")
            compare(p.parameter("osm.mapping.providersrepository.disabled"), true)
            compare(p.parameter("osm.mapping.custom.host"), "https://tile.openstreetmap.org/")
            verify(String(p.parameter("osm.useragent")).length > 0, "a user agent for the tile server")
            var m = theMap()
            compare(m.plugin, p)
            // the last type: the custom URL map with the host above
            compare(m.activeMapType, m.supportedMapTypes[m.supportedMapTypes.length - 1])
            compare(m.copyrightsVisible, false)
            sameColor(m.color, "transparent", "map background")
            // the credit sits under the map, between the button columns
            var credit = named("loadingCredit")
            compare(credit.text, "Map Data from OpenStreetMap")
            verify(credit.z < m.z, "the credit is under the map")
            compare(credit.role, "bodyExtraSmall")
            near(credit.width, 384 - 2 * (Theme.margin.side + Theme.size.iconButtonSmall), 0.01, "credit width")
            var c = credit.mapToItem(app, credit.width / 2, credit.height / 2)
            near(c.x, 192, 0.5, "credit centre x")
            near(c.y, 192, 0.5, "credit centre y")
        }

        // ------------------------------------------------ the view in dconf
        function test_view_defaults() {
            startApp()
            var m = theMap()
            near(m.zoomLevel, 3.4, 1e-6, "zoom")
            compare(m.center.latitude, 0)
            compare(m.center.longitude, 0)
            compare(m.bearing, 0)
        }
        function test_view_restored() {
            startApp({ "/map/view/zoomlevel": 5.5, "/map/view/location/lat": 1234,
                       "/map/view/location/long": -5678 })
            var m = theMap()
            near(m.zoomLevel, 5.5, 1e-6, "zoom")
            // stored x 1e6 (the backend rounded the plain degrees)
            near(m.center.latitude, 0.001234, 1e-9, "latitude")
            near(m.center.longitude, -0.005678, 1e-9, "longitude")
        }
        function test_view_saved_on_close() {
            var a = startApp()
            var m = theMap()
            m.zoomLevel = 12
            m.center = QtPositioning.coordinate(0.002, -0.003)
            a.destroy()
            wait(50)
            var z = ConfStore.writesOf("/map/view/zoomlevel")
            var la = ConfStore.writesOf("/map/view/location/lat")
            var lo = ConfStore.writesOf("/map/view/location/long")
            compare(z.length, 1)
            near(z[0], 12, 1e-6, "zoom")
            near(la[0], 2000, 1e-6, "latitude x 1e6")
            near(lo[0], -3000, 1e-6, "longitude x 1e6")
            // and the next start comes back there
            startApp({ "/map/view/zoomlevel": z[0], "/map/view/location/lat": la[0],
                       "/map/view/location/long": lo[0] })
            near(theMap().zoomLevel, 12, 1e-6, "zoom")
            near(theMap().center.latitude, 0.002, 1e-9, "latitude")
            near(theMap().center.longitude, -0.003, 1e-9, "longitude")
        }

        // ------------------------------------------------ zoom and pan
        function test_zoom_buttons() {
            startApp()
            var m = theMap()
            tapNamed("zoomIn")
            near(m.zoomLevel, 3.7, 1e-6, "zoom in")
            tapNamed("zoomIn")
            near(m.zoomLevel, 4.0, 1e-6, "zoom in")
            tapNamed("zoomOut")
            near(m.zoomLevel, 3.7, 1e-6, "zoom out")
        }
        function test_wheel_zooms() {
            // the wheel handler (the crown, where it sends wheel events): 1/120 of a degree per step
            startApp()
            var m = theMap()
            var z = m.zoomLevel
            mouseWheel(m, 192, 120, 0, 120)
            wait(30)
            verify(m.zoomLevel > z, "wheel up zooms in: " + m.zoomLevel)
            near(m.zoomLevel - z, 0.125, 0.01, "one step")
            z = m.zoomLevel
            mouseWheel(m, 192, 120, 0, -120)
            wait(30)
            verify(m.zoomLevel < z, "wheel down zooms out: " + m.zoomLevel)
        }
        function test_drag_pans() {
            startApp({ "/map/view/zoomlevel": 10 })
            var m = theMap()
            var c0 = m.center
            // the map follows the finger: dragged right, the view moves west
            mouseDrag(m, 192, 120, 80, 0)
            wait(50)
            verify(m.center.longitude < c0.longitude - 1e-6, "west: " + m.center.longitude)
            near(m.center.latitude, c0.latitude, 1e-3, "no north-south move")
            var c1 = m.center
            // dragged down, the view moves north
            mouseDrag(m, 192, 100, 0, 80)
            wait(50)
            verify(m.center.latitude > c1.latitude + 1e-6, "north: " + m.center.latitude)
        }

        // ------------------------------------------------ a position fix
        function test_a_fix_centres_the_map() {
            startApp({ "/map/view/location/lat": 3000, "/map/view/location/long": 3000 })
            var m = theMap()
            var marker = find(m, function (x) { return x._isMapItem === true && !x.hasOwnProperty("iconName") })
            verify(marker, "the position marker")
            compare(marker.visible, false)
            tapNamed("locate")
            source().fix(0, 0)
            compare(m.center.latitude, 0)
            compare(m.center.longitude, 0)
            near(m.zoomLevel, 15, 1e-6, "zoomed in to the fix")
            compare(marker.visible, true)
            var c = marker.mapToItem(app, marker.width / 2, marker.height / 2)
            near(c.x, 192, 0.5, "marker x")
            near(c.y, 192, 0.5, "marker y")
            // a dark disc with a pale ring, 12 dp
            var disc = marker.sourceItem
            compare(disc.width, Theme.dp(12))
            sameColor(disc.color, Theme.color.primaryContainer, "marker")
            sameColor(disc.border.color, Theme.color.primary, "ring")
            compare(disc.border.width, Theme.dp(2))
            // closer already: the zoom stays
            m.zoomLevel = 17
            tapNamed("locate")
            source().fix(0, 0)
            near(m.zoomLevel, 17, 1e-6, "the zoom stays")
        }

        // ------------------------------------------------ the compass button
        function test_compass_modes() {
            startApp()
            var b = shownNamed("compassMode")
            tap(b)
            compare(ConfStore.writesOf("/map/view/compassMode"), [1])
            tap(b)
            tap(b)
            compare(ConfStore.writesOf("/map/view/compassMode"), [1, 2, 0])
            // no compass reading: the infinity sign, upright
            compare(b.iconName, "ios-infinite-outline")
            compare(b.rotation, 0)
            // a calibrated reading: the compass icon; mode 1 turns it with the heading
            compass().setReading(90, 1)
            compare(b.iconName, "ios-compass-outline")
            ConfStore.set("/map/view/compassMode", 1)
            compare(b.rotation, 225)
            compare(theMap().bearing, 0)
            // mode 2: the map turns with the heading
            ConfStore.set("/map/view/compassMode", 2)
            compass().setReading(40, 1)
            compare(theMap().bearing, 40)
            compare(b.rotation, 0)
            // press and hold: north up, mode 2 ends
            mousePress(b)
            wait(1200)
            mouseRelease(b)
            wait(30)
            compare(theMap().bearing, 0)
            compare(ConfStore.get("/map/view/compassMode"), 0)
            compass().setReading(80, 1)
            compare(theMap().bearing, 0)
        }
        function test_compass_off() {
            // the compass off: the button only sets north up (mode 0)
            startApp({ "/map/enableCompass": false, "/map/view/compassMode": 2 })
            compare(compass().active, false)
            var b = shownNamed("compassMode")
            tap(b)
            compare(ConfStore.writesOf("/map/view/compassMode"), [0])
            tap(b)
            compare(ConfStore.writesOf("/map/view/compassMode"), [0])
            ConfStore.set("/map/enableCompass", true)
            compare(compass().active, true)
        }

        // ------------------------------------------------ the pill
        function test_location_pill() {
            startApp()
            var note = named("locationNote"), text = named("locationNoteText")
            compare(note.visible, false)
            status().waitTimeout = 200
            tapNamed("locate")
            compare(note.visible, true)
            compare(text.text, "Waiting for location...")
            sameColor(note.color, Theme.color.surfaceContainer, "waiting pill")
            sameColor(text.color, Theme.color.onSurface, "waiting text")
            compare(text.role, "bodyExtraSmall")
            // under the time text, above the buttons, inside the side margins
            near(note.y, Theme.margin.scaffoldVertical, 0.01, "pill y")
            verify(note.y + note.height <= shownNamed("compassMode").y, "above the buttons")
            verify(note.width <= 384 - 2 * Theme.margin.side + 0.01, "inside the margins")
            near(note.x + note.width / 2, 192, 0.5, "centred")
            tryCompare(text, "text", "Can't detect your location", 3000)
            sameColor(note.color, Theme.color.errorContainer, "failed pill")
            sameColor(text.color, Theme.color.onErrorContainer, "failed text")
            // a late fix ends it
            source().fix(0, 0)
            compare(note.visible, false)
        }

        // ------------------------------------------------ the buttons
        function test_buttons() {
            startApp()
            for (var i = 0; i < buttonNames.length; i++) {
                var b = shownNamed(buttonNames[i])
                verify(b, buttonNames[i])
                compare(b.size, Theme.size.iconButtonSmall)
                compare(b.width, Theme.dp(48))
                compare(b.height, Theme.dp(48))
                compare(b.variant, "tonal")
                // the whole circle is on the round screen
                var c = b.mapToItem(app, b.width / 2, b.height / 2)
                var dist = Math.sqrt(Math.pow(c.x - 192, 2) + Math.pow(c.y - 192, 2))
                verify(dist + b.width / 2 <= 192, buttonNames[i] + " reaches the bezel: " + (dist + b.width / 2))
            }
            var zi = shownNamed("zoomIn"), cm = shownNamed("compassMode"), menu = shownNamed("menu")
            near(zi.mapToItem(app, zi.width, 0).x, 384 - Theme.margin.side, 0.01, "right margin")
            near(cm.mapToItem(app, 0, 0).x, Theme.margin.side, 0.01, "left margin")
            near(menu.mapToItem(app, 0, menu.height).y, 384 - Theme.space.l, 0.01, "bottom margin")
            // stock wording for the two buttons stock Maps has
            compare(shownNamed("locate").Accessible.name, "Re-center map to your location")
            compare(shownNamed("compassMode").Accessible.name, "Keep map north up")
        }
        function test_menu_opens_the_settings() {
            startApp()
            tapNamed("menu")
            settle()
            verify(named("settingsFlickable"), "the settings page")
            compare(stack().layers.length, 1)
        }

        // ------------------------------------------------ what persists
        function test_the_keys_the_app_writes() {
            // close in (the drag below stays within a few metres of 0,0)
            var a = startApp({ "/map/view/zoomlevel": 16 })
            tapNamed("zoomIn")
            tap(shownNamed("compassMode"))
            mouseDrag(theMap(), 192, 120, 30, 0)
            tapNamed("pin")
            tap(shownNamed("confirm"))
            settle()
            tap(named("saveWaypoint"))
            settle()
            a.destroy()
            wait(50)
            var keys = {}
            for (var i = 0; i < ConfStore.writes.length; i++)
                keys[ConfStore.writes[i][0]] = true
            var want = ["/map/view/zoomlevel", "/map/view/location/lat", "/map/view/location/long",
                        "/map/view/compassMode", "/map/waypointList"]
            compare(Object.keys(keys).sort(), want.sort())
        }

        // ------------------------------------------------ the sources
        function test_sources() {
            var files = ["main.qml", "MainMapView.qml", "DefaultMapControls.qml", "SetPointMapControls.qml",
                         "SetPointPage.qml", "SettingsPage.qml", "MapWaypoint.qml", "LocationStatus.qml", "PhoneLink.qml",
                         "NavigationPage.qml", "ManeuverIcon.qml"]
            var qrc = read("src/resources.qrc")
            var all = ""
            for (var i = 0; i < files.length; i++) {
                var s = read("src/" + files[i])
                verify(s.length > 100, files[i] + " read")
                verify(qrc.indexOf("<file>" + files[i] + "</file>") >= 0, files[i] + " is in resources.qrc")
                verify(s.indexOf("HandWritingKeyboard") < 0, files[i] + " uses the handwriting pad")
                var code = s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/mg, "")
                verify(!/"#[0-9a-fA-F]{3,8}"/.test(code), files[i] + " has a hard-coded colour")
                verify(!/"white"|"black"/.test(code), files[i] + " has a named colour")
                verify(!/\bcolors\./.test(code), files[i] + " uses the old colors item")
                verify(!/Dims\.[a-z]+\(/.test(code), files[i] + " uses Dims")
                verify(!/(?:text|title|previewText): "[A-Za-z]/.test(code), files[i] + " has a literal English text")
                verify(!/formatDateTime|formatTime/.test(code), files[i] + " formats a time by the Qt locale")
                verify(!/font\.pixelSize|styleName/.test(code), files[i] + " sets a size or style by hand")
                verify(code.indexOf("org.nemomobile.lipstick") < 0, files[i] + " names the old launcher")
                all += s
            }
            // every id has its English text in a //% comment on the line above one of its uses
            var ids = {}, texts = {}, m
            var re = /qsTrId\("([a-z0-9-]+)"\)/g
            while ((m = re.exec(all)) !== null)
                ids[m[1]] = true
            var pair = /\/\/% "([^"\n]+)"[ \t]*\n[^\n]*?qsTrId\("([a-z0-9-]+)"\)/g
            while ((m = pair.exec(all)) !== null)
                texts[m[2]] = m[1]
            var names = Object.keys(ids).sort()
            compare(names, ["id-map-add-waypoint", "id-map-auto-launch", "id-map-auto-launch-caption",
                            "id-map-cant-detect-location", "id-map-compass", "id-map-data-from-osm", "id-map-edit-waypoint",
                            "id-map-enable-location", "id-map-made-by", "id-map-nav-arrived", "id-map-nav-eta",
                            "id-map-nav-eta-distance", "id-map-nav-exit", "id-map-nav-rerouting", "id-map-nav-starting",
                            "id-map-north-up", "id-map-odbl", "id-map-osm-credit", "id-map-recenter", "id-map-settings",
                            "id-map-use-gps", "id-map-waiting-for-location", "id-map-waypoint-name"])
            for (i = 0; i < names.length; i++)
                verify(texts[names[i]] !== undefined, names[i] + " has no //% text")
            compare(texts["id-map-enable-location"], "Enable watch location?")
            compare(texts["id-map-waiting-for-location"], "Waiting for location...")
            compare(texts["id-map-cant-detect-location"], "Can't detect your location")
            // the waypoint pin is the app's icon file, installed with the others
            var cm = read("CMakeLists.txt")
            verify(/install\(FILES waypoint\.svg DESTINATION \/usr\/share\/icons\/asteroid\/\)/.test(cm), "waypoint.svg installed")
            verify(read("src/MapWaypoint.qml").indexOf('iconName: "waypoint"') >= 0)
            var desk = read("asteroid-map.desktop.template")
            verify(!/NoDisplay/.test(desk), "Maps stays in the app list")
            verify(/^Exec=asteroid-map$/m.test(desk))
            verify(/^Icon=ios-topographic-outline$/m.test(desk), "the launcher icon")
        }

        // D-30: the app list label is stock's app name "Maps" (com.google.android.apps.maps app_name), the
        // //% text of the launcher name id that asteroid-generate-desktop writes as Name=
        function test_app_list_label() {
            var h = read("i18n/asteroid-map.desktop.h")
            var m = /\/\/% "([^"\n]+)"[ \t]*\n[^\n]*qtTrId\("id-app-launcher-name"\)/.exec(h)
            verify(m, "the launcher name id has a //% text")
            compare(m[1], "Maps")
        }

        // ------------------------------------------------ the picture
        function test_main_page_picture() {
            // the time at the top, as the image sets it
            startApp({ "/org/asteroidos/ux/time-text": true })
            wait(300)
            var img = grabImage(screen)
            img.save("shots/map-main.png")
            // no tiles: open map area is the black background
            var spots = [[192, 110], [130, 80], [254, 80], [150, 260], [234, 260], [192, 240]]
            for (var i = 0; i < spots.length; i++) {
                var c = Qt.color(img.pixel(spots[i][0], spots[i][1]))
                verify(c.r < 0.02 && c.g < 0.02 && c.b < 0.02, "open map at " + spots[i] + " is " + c)
            }
            // the credit is drawn in the middle
            var ink = 0
            for (var x = 130; x < 254; x++)
                for (var y = 170; y < 214; y++) {
                    var p = Qt.color(img.pixel(x, y))
                    if (p.r + p.g + p.b > 1.2)
                        ink++
                }
            verify(ink > 50, "credit text drawn: " + ink)
            // waiting and failed, for the look review
            status().waitTimeout = 300
            tapNamed("locate")
            wait(100)
            grabImage(screen).save("shots/map-waiting.png")
            tryCompare(status(), "state", "failed", 3000)
            wait(100)
            grabImage(screen).save("shots/map-failed.png")
        }
        function test_location_off_picture() {
            var c = { "/org/asteroidos/ux/time-text": true }
            c[locationKey] = false
            startApp(c)
            tryCompare(dialog(), "shown", true, 3000)
            settleDialog(dialog())
            grabImage(screen).save("shots/map-location-off.png")
        }
    }
}
