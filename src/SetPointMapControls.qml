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
import org.asteroid.utils

// The same buttons as DefaultMapControls while a waypoint is placed: close
// (tonal) and confirm (filled, the primary action), and a cross at the centre.
Item {
    id: controls

    readonly property real buttonSize: Theme.size.iconButtonSmall

    PageHeader {
        //% "Add waypoint"
        text: qsTrId("id-map-add-waypoint")
    }
    IconButton {
        objectName: "zoomIn"
        iconName: "ios-add-circle-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin.side
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: - height/2 + DeviceSpecs.flatTireHeight/2
        z: 2
        onClicked: mapView.zoomLevel = mapView.zoomLevel + 0.3
    }
    IconButton {
        objectName: "zoomOut"
        iconName: "ios-remove-circle-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.right: parent.right
        anchors.rightMargin: Theme.margin.side
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height/2 + DeviceSpecs.flatTireHeight/2
        z: 2
        onClicked: mapView.zoomLevel = mapView.zoomLevel - 0.3
    }
    IconButton {
        objectName: "compassMode"
        rotation: compassMode.value == 1 && compass.reading ? 315 - compass.reading.azimuth : 0
        iconName: compass.reading && compass.reading.calibrationLevel > 0 ? "ios-compass-outline" : "ios-infinite-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin.side
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: - height/2 + DeviceSpecs.flatTireHeight/2
        z: 2
        Accessible.name: qsTrId("id-map-north-up")
        onClicked: compassMode.value = enableCompass.value ? (compassMode.value+1)%3 : 0
        onPressAndHold: {
            if (compassMode.value == 2) {compassMode.value = 0}
            mapView.bearing = 0
        }
    }
    IconButton {
        objectName: "locate"
        iconName: "ios-locate-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin.side
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height/2 + DeviceSpecs.flatTireHeight/2
        z: 2
        Accessible.name: qsTrId("id-map-recenter")
    }
    IconButton {
        objectName: "close"
        iconName: "ios-close-circle-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.l
        anchors.right: parent.horizontalCenter
        z: 2
        onClicked: {
            parent.visible = false
            mapControls.visible = true
        }
    }
    IconButton {
        objectName: "confirm"
        iconName: "ios-checkmark-circle-outline"
        size: controls.buttonSize
        variant: "filled"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.l
        anchors.left: parent.horizontalCenter
        z: 2
        onClicked: primaryButtonAction()
    }
    Icon {
        objectName: "cross"
        anchors.centerIn: parent
        width: Theme.size.iconSmall
        height: width
        name: "ios-add"
        // dark on the (light) map tiles
        color: Theme.color.surfaceContainer
    }
}
