/*
 * Copyright (C) 2023 - Arseniy Movshev <dodoradio@outlook.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick
import org.asteroid.controls
import QtPositioning
import QtLocation
import Nemo.Configuration
import QtSensors

Application {
    id: app

    Plugin {
        id: mapProvider
        name: "osm"
        // the providers repository's street map needs an API key: use
        // OpenStreetMap's own tiles (the custom map type)
        PluginParameter { name: "osm.useragent"; value: "asteroid-map (AsteroidOS)" }
        PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: true }
        PluginParameter { name: "osm.mapping.custom.host"; value: "https://tile.openstreetmap.org/" }
    }
    PositionSource {
        id: positionProvider
        preferredPositioningMethods: prioritiseGPS.value ? PositionSource.SatellitePositioningMethods : PositionSource.AllPositioningMethods
    }
    Compass {
        id: compass
        // only while a map page is there: the trip screen alone (opened by itself, the display
        // perhaps off) reads no sensor
        active: enableCompass.value && app.mapPages > 0
    }
    //! the map pages that exist (MainMapView counts itself)
    property int mapPages: 0
    // The map is made once the app has its size (makeMap()): main.qml is made at 0 x 0 and gets the
    // window's size after it, and a map made at 0 x 0 and then sized reached the first frame more
    // than twice as late.
    LayerStack {
        id: pageStack
        anchors.fill: parent
    }
    property bool mapMade: false
    function makeMap() {
        if (mapMade || width <= 0)
            return
        mapMade = true
        // the launcher opened the app for the phone's trip (NavAutoLaunch asks for "nav" once per
        // trip): the trip screen is the first page, the map is not made; the Maps tile asks for the
        // map itself ("map"); else the home, as stock Maps opens on its home screen (D-13)
        var request = takeOpenRequest()
        if (request === "nav") {
            openedForTrip = true
            pageStack.firstPage = navigationPage
        } else if (request === "map") {
            pageStack.firstPage = mainMapView
        } else {
            pageStack.firstPage = homePage
        }
        phoneLink.refresh()
    }
    onWidthChanged: makeMap()
    Component.onCompleted: makeMap()

    // ---- the phone's trip (D-02): turn by turn navigation mirrored from the phone ----
    PhoneLink { id: phoneLink }
    // stock Maps' Auto-launch (auto_launch_watch_title): a trip the phone starts opens the trip
    // screen; on by default (the user's choice, Q57); Settings has the switch
    ConfigurationValue {
        id: autoLaunch
        key: "/map/autoLaunch"
        defaultValue: true
    }
    readonly property bool autoLaunchOn: autoLaunch.value !== false && autoLaunch.value !== "false"
    // A request of the launcher, as the other apps' (contract row CR-36): dconf /map/open "<what>@<ms>",
    // "nav" (the trip screen) read at start and on change, "map" (the Maps tile: the map at the place
    // it set) read at start and on change; a request older than 60 s or more than 5 s
    // ahead is ignored; the key is cleared. No timer: the request arrives as a change of the key.
    ConfigurationValue {
        id: openRequest
        key: "/map/open"
        defaultValue: ""
        onValueChanged: if (app.mapMade) Qt.callLater(app.openRequested)
    }
    //! the request's what ("" for none, or one too old), the key cleared
    function takeOpenRequest() {
        var request = String(openRequest.value || "")
        if (request === "")
            return ""
        openRequest.value = ""
        var at = request.lastIndexOf("@")
        var age = Date.now() - Number(request.substring(at + 1))
        if (at < 0 || !(age > -5000 && age < 60000))
            return ""
        return request.substring(0, at)
    }
    function openRequested() {
        var request = takeOpenRequest()
        if (request === "nav")
            showTrip()
        else if (request === "map" && mapPages === 0)
            openMap()
    }
    //! the trip screen is the first page because the app was opened for it
    property bool openedForTrip: false
    //! how the app closes (the tests replace it)
    property var closeApp: function () { Qt.quit() }
    function tripShown() {
        var top = pageStack.currentLayer ? pageStack.currentLayer : pageStack.firstPageItem
        return !!top && top.objectName === "navigationPage"
    }
    function showTrip() {
        if (tripShown())
            return
        pageStack.push(navigationPage)
    }
    // Exit: the trip screen goes, the page under it shows; opened for the trip: the home (the phone
    // goes on navigating)
    function exitTrip() {
        if (pageStack.currentLayer && pageStack.currentLayer.objectName === "navigationPage") {
            pageStack.popAnim()
        } else if (openedForTrip) {
            openedForTrip = false
            pageStack.firstPage = homePage
        }
    }

    // ---- the home (D-13): the map, search, Home and Work, directions on the phone ----
    function openMap() {
        pageStack.push(mainMapView)
    }
    //! the directions page for what the phone's maps app is asked (q) under its title
    function directionsTo(q, title) {
        pageStack.push(directionsPage, { query: q, title: title })
    }
    //! the phone took the trip: back to the home, stock's open-on-phone confirmation ("Check your phone")
    function tripHandedOver(how) {
        while (pageStack.layers.length > 0)
            pageStack.pop(pageStack.currentLayer)
        confirmation.showOpenOnPhone()
    }
    Confirmation {
        id: confirmation
        objectName: "openOnPhone"
    }
    Connections {
        target: phoneLink
        // a trip began: at start (the app opened during one) always, later with Auto-launch on
        function onTripStarted(atStart) {
            if (atStart || app.autoLaunchOn)
                app.showTrip()
        }
        // the trip ended: the trip screen closes; the app opened for it closes with it
        function onTripEnded() {
            if (app.openedForTrip && !pageStack.currentLayer)
                app.closeApp()
            else if (pageStack.currentLayer && pageStack.currentLayer.objectName === "navigationPage")
                pageStack.popAnim()
        }
        // opened for a trip btsyncd does not know (it ended before the app came up): the map
        function onStateChecked(answered) {
            if (answered && app.openedForTrip && !phoneLink.navigating && !pageStack.currentLayer)
                app.exitTrip()
        }
    }
    ConfigurationValue {
        id: enableCompass
        key: "/map/enableCompass"
        defaultValue: true
    }
    ConfigurationValue {
        id: prioritiseGPS
        key: "/map/prioritiseGPS"
        defaultValue: true
    }
    Component {
        id: mainMapView
        MainMapView {
        }
    }
    Component {
        id: settingsPage
        SettingsPage {}
    }
    Component {
        id: homePage
        HomePage {
            link: phoneLink
            onOpenMap: app.openMap()
            onOpenSearch: pageStack.push(searchPage)
            onOpenPlace: (place) => app.directionsTo(place, place === "home" ? homeText : workText)
            onOpenTrip: app.showTrip()
            onOpenSettings: pageStack.push(settingsPage)
        }
    }
    Component {
        id: searchPage
        SearchPage {
            onSearched: (q) => app.directionsTo(q, q)
        }
    }
    Component {
        id: directionsPage
        DirectionsPage {
            link: phoneLink
            onStarted: (how) => app.tripHandedOver(how)
        }
    }
    Component {
        id: navigationPage
        NavigationPage {
            link: phoneLink
            onExitClicked: app.exitTrip()
        }
    }
}
