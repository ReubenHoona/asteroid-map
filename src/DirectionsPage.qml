/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.asteroid.controls

// Directions to a place (R5 D-13, stock M-1): the place as the title, stock's "Directions" header
// (directions_eta_button_header) and its travel modes (mode_driving, mode_walking, mode_cycling,
// mode_transit). A mode starts the trip on the phone, as stock Wear OS hands a trip to the phone and as
// the launcher's assistant does: the relay's act "nav" (Gadgetbridge opens Google Maps' navigation, or
// its directions for transit; with Google Maps' own "home" and "work" for those two). The phone's
// answer: started or a notification to accept on the phone -> the app's open-on-phone confirmation
// (main.qml); an error -> a line here, and a mode tapped again tries again. The phone's trip then shows
// on the watch by itself (Auto-launch, NavigationPage).
Item {
    id: page
    objectName: "directionsPage"

    // set by the LayerStack
    property int depth
    property var pop
    //! what the phone's maps app is asked for: "home", "work" or the place typed
    property string query: ""
    //! the title: the place, or Home / Work
    property string title: ""
    //! the phone (PhoneLink)
    property var link: null

    //! the phone took it: how ("started", "notification", "other": another maps app shows the place)
    signal started(string how)

    //! "" idle, "sending" while the phone is asked, else the error's text
    property string phase: ""
    readonly property bool sending: phase === "sending"
    readonly property string errorText: sending ? "" : phase

    //% "Directions"
    readonly property string directionsText: qsTrId("id-map-directions")
    readonly property var modes: [
        //% "Driving"
        { name: "modeDriving", mode: "driving", icon: "ms-directions_car", text: qsTrId("id-map-mode-driving") },
        //% "Walking"
        { name: "modeWalking", mode: "walking", icon: "ms-directions_walk", text: qsTrId("id-map-mode-walking") },
        //% "Cycling"
        { name: "modeCycling", mode: "bicycling", icon: "ms-directions_bike", text: qsTrId("id-map-mode-cycling") },
        //% "Transit"
        { name: "modeTransit", mode: "transit", icon: "ios-bus", text: qsTrId("id-map-mode-transit") }
    ]

    // the phone's answer as the watch says it
    function failureText(r) {
        var er = r ? r.er : ""
        if (er === "no-phone" || er === "disconnected")
            //% "Your phone isn't connected. Directions need your phone."
            return qsTrId("id-map-dir-no-phone")
        if (er === "old-app")
            //% "Update Gadgetbridge on your phone to do this from the watch."
            return qsTrId("id-map-dir-old-app")
        if (er === "no-maps")
            //% "There's no maps app on your phone. Install Google Maps to get directions."
            return qsTrId("id-map-dir-no-maps")
        //% "Couldn't start navigation"
        return qsTrId("id-map-dir-failed")
    }

    function go(mode) {
        if (sending || !link)
            return
        phase = "sending"
        link.act({ a: "nav", q: page.query, mode: mode }, function (r) {
            if (r && r.ok) {
                phase = ""
                page.started(String(r.how === "notification" ? "notification" : r.app === "other" ? "other" : "started"))
            } else {
                phase = page.failureText(r)
            }
        })
    }

    ScalingList {
        id: list
        objectName: "directionsList"
        anchors.fill: parent
        model: page.modes.length + 2

        itemDelegate: Item {
            id: cell
            property int index: -1
            height: row.height

            Loader {
                id: row
                width: parent.width
                sourceComponent: cell.index === 0 ? titleRow : cell.index === 1 ? headerRow : cell.index >= 2 ? modeRow : null
            }
            Component {
                id: titleRow
                Column {
                    spacing: Theme.dp(4)
                    Label {
                        objectName: "directionsTitle"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        role: "titleMedium"
                        color: Theme.color.onSurface
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        text: page.title
                    }
                    Label {
                        objectName: "directionsError"
                        width: parent.width
                        visible: page.errorText !== ""
                        horizontalAlignment: Text.AlignHCenter
                        role: "bodySmall"
                        color: Theme.color.error
                        wrapMode: Text.Wrap
                        text: page.errorText
                    }
                }
            }
            Component {
                id: headerRow
                ListSubHeader {
                    objectName: "directionsHeader"
                    text: page.directionsText
                }
            }
            Component {
                id: modeRow
                Button {
                    readonly property var m: page.modes[Math.max(0, cell.index - 2)]
                    objectName: m.name
                    variant: "tonal"
                    enabled: !page.sending
                    minimumHeight: Theme.dp(52)
                    iconName: m.icon
                    iconSize: Theme.dp(24)
                    text: m.text
                    onClicked: page.go(m.mode)
                }
            }
        }
    }
}
