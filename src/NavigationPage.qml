/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.asteroid.controls

// The trip screen: the phone's turn by turn navigation mirrored on the watch, as stock Maps' trip
// screen draws its current step (navigation_current_step.xml: the 48 dp white manoeuvre glyph at the
// top, the distance under it in the display style, the step's text under that, centred, 6.24 % from
// the sides) over its footer line ("ETA %1$s", "%1$s · %2$s": navigation_eta,
// navigation_eta_and_distance). Before the first turn "Starting navigation…"
// (INITIAL_NOTIFICATION_CONTENT_TITLE), at the end "Arrived" (arrived), off the route "Rerouting..."
// (DA_REROUTING). There is no route map: the watch has no route, and the position would cost the GPS.
// The step fills the screen; scrolled under it is Exit (stock's trip summary: exit_navigation_session,
// the red exit chip, 52 dp high).
//
// Exit leaves the trip screen; the phone goes on navigating (the watch cannot end the phone's trip).
// Nothing animates and nothing polls: the page changes when a turn comes (PhoneLink.trip).
Item {
    id: page
    objectName: "navigationPage"

    // set by the LayerStack
    property int depth
    property var pop
    //! the phone's trip (PhoneLink)
    property var link: null

    signal exitClicked()

    readonly property var trip: link ? link.trip : null
    readonly property string act: trip && trip.act !== undefined ? String(trip.act) : ""
    readonly property bool waiting: trip === null
    readonly property bool arrived: act === "finish"
    readonly property bool rerouting: act === "offroute"
    readonly property alias flickable: flick

    //% "Starting navigation…"
    readonly property string startingText: qsTrId("id-map-nav-starting")
    //% "Arrived"
    readonly property string arrivedText: qsTrId("id-map-nav-arrived")
    //% "Rerouting..."
    readonly property string reroutingText: qsTrId("id-map-nav-rerouting")

    //! the big line: the distance to the turn, or what happens
    readonly property string headline: waiting ? "" : arrived ? arrivedText : rerouting ? reroutingText
                                     : trip.di !== undefined ? String(trip.di) : ""
    readonly property string instruction: trip && trip.ins !== undefined ? String(trip.ins) : ""
    //! when the trip ends: the phone's own time, else the seconds left from the turn in the system format
    readonly property string arrival: {
        if (!trip)
            return ""
        if (trip.eta !== undefined && String(trip.eta) !== "")
            return String(trip.eta)
        if (trip.tt !== undefined && Number(trip.tt) > 0)
            return TimeFormat.time(new Date(link.tripAt + Number(trip.tt) * 1000))
        return ""
    }
    readonly property string distanceLeft: trip && trip.dt !== undefined ? String(trip.dt) : ""
    readonly property string footer: {
        //% "ETA %1"
        var eta = arrival !== "" ? qsTrId("id-map-nav-eta").arg(arrival) : ""
        if (eta !== "" && distanceLeft !== "")
            //% "%1 · %2"
            return qsTrId("id-map-nav-eta-distance").arg(eta).arg(distanceLeft)
        return eta !== "" ? eta : distanceLeft
    }

    readonly property real side: width * 0.0624

    Rectangle {
        anchors.fill: parent
        color: Theme.color.background
    }

    Flickable {
        id: flick
        objectName: "navFlickable"
        anchors.fill: parent
        contentWidth: width
        // the step is one screen; Exit is under it
        contentHeight: height + exitButton.height + Theme.dp(40)
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: step
            width: flick.width
            height: flick.height

            ManeuverIcon {
                id: maneuver
                objectName: "navManeuver"
                visible: !page.waiting
                act: page.act
                width: Theme.dp(48)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.dp(22)
            }

            Label {
                id: headlineLabel
                objectName: "navHeadline"
                visible: !page.waiting && text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: maneuver.y + maneuver.height
                width: parent.width - 2 * Theme.margin.titleSide
                horizontalAlignment: Text.AlignHCenter
                role: "displaySmall"
                color: Theme.color.onSurface
                elide: Text.ElideRight
                maximumLineCount: 1
                text: page.headline
            }

            Label {
                id: instructionLabel
                objectName: "navInstruction"
                visible: !page.waiting && text !== ""
                x: page.side
                width: parent.width - 2 * page.side
                y: (headlineLabel.visible ? headlineLabel.y + headlineLabel.height : maneuver.y + maneuver.height) + Theme.dp(2)
                horizontalAlignment: Text.AlignHCenter
                role: "bodyMedium"
                color: Theme.color.onSurface
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                // two lines above the footer, three without one
                maximumLineCount: footerLabel.visible ? 2 : 3
                text: page.instruction
            }

            Label {
                objectName: "navStarting"
                visible: page.waiting
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.margin.titleSide
                horizontalAlignment: Text.AlignHCenter
                role: "titleMedium"
                color: Theme.color.onSurface
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: page.startingText
            }

            // the footer line, where the round screen is still wide enough
            Label {
                id: footerLabel
                objectName: "navFooter"
                visible: !page.waiting && text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - Theme.dp(42)
                width: parent.width * 0.74
                horizontalAlignment: Text.AlignHCenter
                role: "labelMedium"
                color: Theme.color.onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 1
                text: page.footer
            }
        }

        // stock's exit chip is the system red with dark text (action_chip_exit_background,
        // action_chip_exit_text_color), 52 dp (ongoing_navigation_summary_screen_exit_button)
        Button {
            id: exitButton
            objectName: "navExit"
            x: Theme.margin.listSide
            y: step.height + Theme.dp(4)
            width: flick.width - 2 * Theme.margin.listSide
            centered: true
            minimumHeight: Theme.dp(52)
            containerColor: Theme.color.error
            contentColor: Theme.color.onError
            //% "Exit"
            text: qsTrId("id-map-nav-exit")
            onClicked: page.exitClicked()
        }
    }

}
