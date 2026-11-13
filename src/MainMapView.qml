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
import Nemo.Configuration
import QtPositioning
import QtLocation
import QtSensors

Item {
    objectName: "mainMapView"
    //! what the map says about the position fix (and for tests)
    readonly property QtObject location: locationStatus

    ConfigurationValue {
        id: mapZoom
        key: "/map/view/zoomlevel"
        defaultValue: 3.4
    }
    ConfigurationValue {
        id: mapCenterLat
        key: "/map/view/location/lat"
        defaultValue: ""
    }
    ConfigurationValue {
        id: mapCenterLong
        key: "/map/view/location/long"
        defaultValue: ""
    }
    ConfigurationValue {
        id: compassMode
        key: "/map/view/compassMode"
        defaultValue: 0
    }
    ConfigurationValue {
        id: waypointSource
        key: "/map/waypointList"
        defaultValue: "[]"
        onValueChanged: {
            mapView.updateWaypoints()
            console.log("value changed")
        }
        Component.onCompleted: mapView.updateWaypoints()
    }

    LocationStatus {
        id: locationStatus
        sourceActive: positionProvider.active
        hasFix: positionProvider.position.coordinate.isValid
        sourceError: positionProvider.sourceError !== PositionSource.NoError
    }

    Label {
        objectName: "loadingCredit"
        //% "Map Data from OpenStreetMap"
        text: qsTrId("id-map-data-from-osm")
        role: "bodyExtraSmall"
        color: Theme.color.onSurfaceVariant
        // between the two columns of buttons
        width: parent.width - 2 * (Theme.margin.side + Theme.size.iconButtonSmall)
        wrapMode: Text.Wrap
        maximumLineCount: 3
        horizontalAlignment: Text.AlignHCenter
        anchors.centerIn: parent
        z: 0
    }

    // "Waiting for location..." while a fix is awaited, "Can't detect your
    // location" when none came (stock Maps strings)
    Rectangle {
        id: locationNote
        objectName: "locationNote"
        readonly property string state: locationStatus.state
        visible: state === "waiting" || state === "failed"
        anchors.horizontalCenter: parent.horizontalCenter
        // under the time text, above the buttons
        y: Theme.margin.scaffoldVertical
        width: Math.min(parent.width - 2 * Theme.margin.side, noteLabel.implicitWidth + 2 * Theme.space.l)
        height: noteLabel.implicitHeight + 2 * Theme.space.s
        radius: Math.min(Theme.shape.large, height / 2)
        color: state === "failed" ? Theme.color.errorContainer : Theme.color.surfaceContainer
        z: 4
        Label {
            id: noteLabel
            objectName: "locationNoteText"
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.space.l
                rightMargin: Theme.space.l
            }
            role: "bodyExtraSmall"
            color: locationNote.state === "failed" ? Theme.color.onErrorContainer : Theme.color.onSurface
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            //% "Can't detect your location"
            text: locationNote.state === "failed" ? qsTrId("id-map-cant-detect-location")
                                                   //% "Waiting for location..."
                                                   : qsTrId("id-map-waiting-for-location")
        }
    }
    Map {
        id: mapView
        plugin: mapProvider
        activeMapType: supportedMapTypes[supportedMapTypes.length - 1]
        anchors.fill: parent
        copyrightsVisible: false //this is compensated by showing the copyright when application is loading
        color: "transparent"
        z: 1
        Component.onCompleted: {
            zoomLevel = mapZoom.value
            //the precision of the saved value seems to get truncated by nemo-configuration or its backend.
            //multiply by a million to prevent the value getting 'rounded'
            center.latitude = mapCenterLat.value/1000000
            center.longitude = mapCenterLong.value/1000000
        }
        Component.onDestruction: {
            mapZoom.value = zoomLevel
            mapCenterLat.value = center.latitude*1000000
            mapCenterLong.value = center.longitude*1000000
        }

        PinchHandler {
            id: pinch
            target: null
            onActiveChanged: if (active) {
                mapView.startCentroid = mapView.toCoordinate(pinch.centroid.position, false)
            }
            onScaleChanged: (delta) => {
                mapView.zoomLevel += Math.log2(delta)
                mapView.alignCoordinateToPoint(mapView.startCentroid, pinch.centroid.position)
            }
            onRotationChanged: (delta) => {
                mapView.bearing -= delta
                mapView.alignCoordinateToPoint(mapView.startCentroid, pinch.centroid.position)
            }
            grabPermissions: PointerHandler.TakeOverForbidden
        }
        WheelHandler {
            id: wheel
            rotationScale: 1/120
            property: "zoomLevel"
        }
        DragHandler {
            id: drag
            target: null
            onTranslationChanged: (delta) => mapView.pan(-delta.x, -delta.y)
        }
        Connections {
            target: positionProvider
            function onPositionChanged() {
                mapView.center = positionProvider.position.coordinate
                if (mapView.zoomLevel < 13)
                    mapView.zoomLevel = 15
            }
        }
        Connections {
            target: compass
            function onReadingChanged() {
                if (compassMode.value == 2 && compass.reading) {
                    mapView.bearing = compass.reading.azimuth
                }
            }
        }
        // where the last position fix is
        MapQuickItem {
            id: positionMarker
            coordinate: positionProvider.position.coordinate
            visible: positionProvider.position.coordinate.isValid
            anchorPoint.x: sourceItem.width / 2
            anchorPoint.y: sourceItem.height / 2
            z: 3
            sourceItem: Rectangle {
                // a dark disc with a pale ring: visible on light and dark tiles
                width: Theme.dp(12)
                height: width
                radius: width / 2
                color: Theme.color.primaryContainer
                border.color: Theme.color.primary
                border.width: Theme.dp(2)
            }
        }
        property MapQuickItem mapItem
        function updateWaypoints() {
            clearMapItems()
            addMapItem(positionMarker)
            var waypointsList = JSON.parse(waypointSource.value)
            console.log(waypointsList)
            for(var i = 0, size = waypointsList.length; i < size ; i++){
                var currWaypointData = waypointsList[i]
                mapItem = waypoint.createObject(mapView)
                mapItem.coordinate = QtPositioning.coordinate(currWaypointData[1][0],currWaypointData[1][1])
                console.log(mapItem.coordinate)
                mapItem.iconName = currWaypointData[0]
                console.log(currWaypointData[2])
                mapItem.iconColor = currWaypointData[2]
                mapItem.index = i
                mapView.addMapItem(mapItem)
            }
            console.log("waypoints updated")
        }
    }
    DefaultMapControls {
        id: mapControls
        anchors.fill: parent
        z: 2
    }
    SetPointMapControls {
        id: setPointControls
        anchors.fill: parent
        visible: false
        z: 2
        function primaryButtonAction() {
             pageStack.push(setPointPage,{coord: mapView.center})
        }
    }
    function editWaypoint(index) {
        pageStack.push(setPointPage,{editMode: true, editIndex: index})
    }
    Component {
        id: waypoint
        MapWaypoint {
        }
    }
    Component {
        id: setPointPage
        SetPointPage {
        }
    }
}
