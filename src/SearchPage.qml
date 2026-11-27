/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.asteroid.controls

// Search (R5 D-13, stock M-1 "Start search"): the place to go to, typed on the stock full screen
// keyboard, which opens at once with stock's hint "Search…" (abc_search_hint). Its tick goes on to the
// directions for what was typed (the phone's Google Maps finds the place: the watch has no search of its
// own, OpenStreetMap's tiles have no names to search). A swipe on the keyboard leaves the field here; a
// tap on it types again.
Item {
    id: page
    objectName: "searchPage"

    // set by the LayerStack
    property int depth
    property var pop

    signal searched(string query)

    //% "Search…"
    readonly property string hintText: qsTrId("id-map-search-hint")
    readonly property alias field: field

    function submit(text) {
        var q = String(text || "").trim()
        if (q !== "")
            searched(q)
    }

    TextField {
        id: field
        objectName: "searchField"
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.margin.titleSide
        height: Theme.size.button
        previewText: page.hintText
        onEnterKeyClicked: page.submit(field.text)
    }

    // the keyboard at once, as stock's search opens on its input
    Component.onCompleted: Qt.callLater(field.openKeyboard)
}
