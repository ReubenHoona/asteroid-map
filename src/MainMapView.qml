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
import Nemo.DBus

Item {
    id: mapRoot
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

    // Settings > Location (CR-21): off, the map asks for no fix and says, as
    // stock Maps does, "Enable watch location?"
    ConfigurationValue {
        id: locationEnabled
        key: "/org/asteroidos/settings/location-enabled"
        defaultValue: true
    }
    readonly property bool locationOn: locationEnabled.value !== false && locationEnabled.value !== "false"

    // the launcher's "location in use" indicator (CR-04): claimed while the
    // position source works for this app, released when it stops, the
    // location switch goes off or the app closes. No reply is awaited.
    DBusInterface {
        id: ongoing
        bus: DBus.SessionBus
        service: "org.asteroidos.launcher"
        path: "/org/asteroidos/launcher/ongoing"
        iface: "org.asteroidos.launcher.Ongoing"
    }
    property bool _claimed: false
    function claim(active) {
        if (_claimed === active)
            return
        _claimed = active
        ongoing.typedCall("SetInUse", [{ "type": "s", "value": "location" },
                                       { "type": "b", "value": active }])
    }
    Connections {
        target: locationStatus
        function onInUseChanged() { mapRoot.claim(locationStatus.inUse) }
    }
    Connections {
        target: locationEnabled
        function onValueChanged() {
            if (!mapRoot.locationOn)
                positionProvider.stop()
        }
    }
    Component.onDestruction: claim(false)

    // the locate button: a fix is asked for only with location on
    function locate() {
        if (!locationOn) {
            locationDialog().open()
            return
        }
        locationStatus.request()
        positionProvider.update()
    }

    LocationStatus {
        id: locationStatus
        locationEnabled: mapRoot.locationOn
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
    // stock Maps (enable_location_title): the check turns location on. Made once the first frame is
    // drawn (the window's first frameSwapped), or at once when it is wanted before (locationDialog()).
    property bool firstFrameDrawn: false
    Connections {
        target: mapRoot.Window.window
        enabled: !mapRoot.firstFrameDrawn
        function onFrameSwapped() { mapRoot.firstFrameDrawn = true }
    }
    property bool locationDialogWanted: false
    function locationDialog() {
        locationDialogWanted = true
        return _locationDialogLoader.item
    }
    readonly property alias enableLocationDialog: _locationDialogLoader.item
    Loader {
        id: _locationDialogLoader
        anchors.fill: parent
        // a Dialog's own z
        z: 1000
        active: mapRoot.firstFrameDrawn || mapRoot.locationDialogWanted
        sourceComponent: AlertDialog {
            objectName: "enableLocationDialog"
            //% "Enable watch location?"
            title: qsTrId("id-map-enable-location")
            buttons: "confirmDismiss"
            onConfirmed: locationEnabled.value = true
        }
    }
    Component.onCompleted: if (!locationOn) Qt.callLater(function () { mapRoot.locationDialog().open() })
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
