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

// Map settings as a stock CP3A Settings screen: a ListHeader first in the
// list, then Material 3 switch rows (SwitchButton) 4 dp apart, then captions
// (bodySmall, onSurfaceVariant). The list keeps 5.2 % at each side, starts
// 16.64 % down and ends with 36.46 % of the height of room.
Item {
    id: root

    // set by the LayerStack
    property int depth
    property var pop

    Flickable {
        id: flick
        objectName: "settingsFlickable"
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.y + column.height + Theme.margin.listBottom
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.DragOverBounds

        Column {
            id: column
            y: Theme.margin.listTop
            x: Theme.margin.listSide
            width: root.width - 2 * x
            spacing: Theme.space.xs

            ListHeader {
                objectName: "title"
                //% "Map settings"
                text: qsTrId("id-map-settings")
            }
            SwitchButton {
                objectName: "compassSwitch"
                width: parent.width
                //% "Compass"
                text: qsTrId("id-map-compass")
                checked: enableCompass.value
                onToggled: (state) => enableCompass.value = state
            }
            SwitchButton {
                objectName: "gpsSwitch"
                width: parent.width
                //% "Use GPS"
                text: qsTrId("id-map-use-gps")
                checked: prioritiseGPS.value
                onToggled: (state) => prioritiseGPS.value = state
            }
            Label {
                objectName: "caption"
                width: parent.width
                role: "bodySmall"
                color: Theme.color.onSurfaceVariant
                leftPadding: Theme.space.xl
                rightPadding: Theme.space.xl
                topPadding: Theme.space.s
                bottomPadding: Theme.space.s
                wrapMode: Text.Wrap
                clip: false
                //% "Map Data © OpenStreetMap contributors"
                text: qsTrId("id-map-osm-credit") + "\n" +
                      //% "under the ODbL"
                      qsTrId("id-map-odbl")
            }
            Label {
                objectName: "credit"
                width: parent.width
                role: "bodySmall"
                color: Theme.color.onSurfaceVariant
                leftPadding: Theme.space.xl
                rightPadding: Theme.space.xl
                topPadding: Theme.space.s
                bottomPadding: Theme.space.s
                wrapMode: Text.Wrap
                clip: false
                //% "Made by dodoradio"
                text: qsTrId("id-map-made-by") + "\ndodorad.io"
            }
        }
    }
}
