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
        active: enableCompass.value
    }
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
        pageStack.firstPage = mainMapView
    }
    onWidthChanged: makeMap()
    Component.onCompleted: makeMap()
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
}
