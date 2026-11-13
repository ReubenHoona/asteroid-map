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

// The buttons over the map: Material 3 tonal icon buttons (48 dp, the touch
// target) in the corners of the round screen, 5.2 % from the side and 12 dp
// above the bottom edge.
Item {
    id: controls

    readonly property real buttonSize: Theme.size.iconButtonSmall

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
        // the icon turns with the heading in compass mode 1 (the old button
        // turned 360 - azimuth with the icon 45 degrees back)
        rotation: compassMode.value == 1 && compass.reading ? 315 - compass.reading.azimuth : 0
        iconName: compass.reading && compass.reading.calibrationLevel > 0 ? "ios-compass-outline" : "ios-infinite-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin.side
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: - height/2 + DeviceSpecs.flatTireHeight/2
        z: 2
        //% "Keep map north up"
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
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: height/2 + DeviceSpecs.flatTireHeight/2
        anchors.left: parent.left
        anchors.leftMargin: Theme.margin.side
        z: 2
        //% "Re-center map to your location"
        Accessible.name: qsTrId("id-map-recenter")
        onClicked: {
            locationStatus.request()
            positionProvider.update()
        }
    }
    IconButton {
        objectName: "menu"
        iconName: "ios-menu-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.l
        anchors.right: parent.horizontalCenter
        z: 2
        onClicked: pageStack.push(settingsPage,{})
    }
    IconButton {
        objectName: "pin"
        iconName: "ios-pin-outline"
        size: controls.buttonSize
        variant: "tonal"
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.l
        anchors.left: parent.horizontalCenter
        z: 2
        onClicked: {
            parent.visible = false
            setPointControls.visible = true
        }
    }
}
