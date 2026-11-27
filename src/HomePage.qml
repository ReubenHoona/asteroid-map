/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.asteroid.controls

// The Maps home (R5 D-13, stock M-1): the app opens here, as stock Maps opens on its home screen
// (the nav host's start destination home_screen_route, sdm.java; the list ryn.java
// home_screen_transforming_lazy_column): one list of rows, 4 dp apart, the stock list paddings,
// - the map button and the search button side by side (ryn.o: "Open map view" map_button_description,
//   "Start search" generic_search with the search glyph), 52 dp high
// - Home and Work side by side, 52 dp high, 4 dp apart, each half the row (ryn.java:1749-1815,
//   maps_home_chip_text, maps_work_chip_text with the home and work glyphs): directions to the
//   phone's home or work address (Google Maps' own "home" and "work"; stock ALIAS_HOME, ALIAS_WORK)
// - while the phone navigates, the trip ("ETA %1$s" navigation_eta, else "Navigating…"
//   navigating_placeholder, the step under it): its tap opens the trip screen
// - Settings (settings_button, the settings glyph)
// Stock's Recents, Offline maps and the account rows need Google's servers: none here.
Item {
    id: page
    objectName: "homePage"

    // set by the LayerStack
    property int depth
    property var pop
    //! the phone's trip (PhoneLink)
    property var link: null

    signal openMap()
    signal openSearch()
    signal openPlace(string place)
    signal openTrip()
    signal openSettings()

    readonly property alias list: list
    readonly property var trip: link && link.navigating ? link.trip : null
    readonly property var rows: trip ? ["top", "places", "trip", "settings"] : ["top", "places", "settings"]

    //% "Open map view"
    readonly property string mapText: qsTrId("id-map-open-map-view")
    //% "Start search"
    readonly property string searchText: qsTrId("id-map-start-search")
    //% "Home"
    readonly property string homeText: qsTrId("id-map-home")
    //% "Work"
    readonly property string workText: qsTrId("id-map-work")
    //% "Navigating…"
    readonly property string navigatingText: qsTrId("id-map-navigating")
    //% "Settings"
    readonly property string settingsText: qsTrId("id-map-settings-chip")

    readonly property real rowHeight: Theme.dp(52)

    component PairButton: Button {
        id: pb
        property string label
        variant: "tonal"
        centered: true
        minimumHeight: page.rowHeight
        height: page.rowHeight
        iconSize: Theme.dp(24)
        iconColor: Theme.color.onSurface
        iconSpacing: 0
        text: ""
        Accessible.name: label
    }

    ScalingList {
        id: list
        objectName: "homeList"
        anchors.fill: parent
        model: page.rows

        itemDelegate: Item {
            id: cell
            property var modelData
            height: row.height

            Loader {
                id: row
                width: parent.width
                sourceComponent: cell.modelData === "top" ? topRow : cell.modelData === "places" ? placesRow
                               : cell.modelData === "trip" ? tripRow : cell.modelData === "settings" ? settingsRow : null
            }
            Component {
                id: topRow
                Row {
                    spacing: Theme.dp(4)
                    readonly property real half: (width - spacing) / 2
                    PairButton {
                        objectName: "homeMap"
                        width: parent.half
                        iconName: "ios-map-outline"
                        label: page.mapText
                        onClicked: page.openMap()
                    }
                    PairButton {
                        objectName: "homeSearch"
                        width: parent.half
                        iconName: "ios-search"
                        label: page.searchText
                        onClicked: page.openSearch()
                    }
                }
            }
            Component {
                id: placesRow
                Row {
                    spacing: Theme.dp(4)
                    readonly property real half: (width - spacing) / 2
                    PairButton {
                        objectName: "homeHome"
                        width: parent.half
                        iconName: "ios-home"
                        label: page.homeText
                        onClicked: page.openPlace("home")
                    }
                    PairButton {
                        objectName: "homeWork"
                        width: parent.half
                        iconName: "ios-briefcase"
                        label: page.workText
                        onClicked: page.openPlace("work")
                    }
                }
            }
            Component {
                id: tripRow
                Button {
                    objectName: "homeTrip"
                    variant: "tonal"
                    minimumHeight: page.rowHeight
                    iconName: "ms-navigation"
                    iconSize: Theme.dp(24)
                    //% "ETA %1"
                    text: page.trip && page.trip.eta ? qsTrId("id-map-nav-eta").arg(String(page.trip.eta)) : page.navigatingText
                    secondaryText: page.trip && page.trip.ins ? String(page.trip.ins) : ""
                    secondaryMaximumLineCount: 1
                    onClicked: page.openTrip()
                }
            }
            Component {
                id: settingsRow
                Button {
                    objectName: "homeSettings"
                    variant: "tonal"
                    minimumHeight: page.rowHeight
                    iconName: "ms-settings"
                    iconSize: Theme.dp(24)
                    text: page.settingsText
                    onClicked: page.openSettings()
                }
            }
        }
    }
}
