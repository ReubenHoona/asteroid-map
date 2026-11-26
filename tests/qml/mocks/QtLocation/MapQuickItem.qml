// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: QtLocation's MapQuickItem. Its sourceItem is drawn in it; on a
// Map double it sits where the Map puts its coordinate (minus anchorPoint), off
// a map it has no parent item (as a removed map item).
import QtQuick
import QtPositioning

Item {
    id: item
    property var coordinate: QtPositioning.coordinate()
    property point anchorPoint
    property real zoomLevel: 0
    property bool autoFadeIn: true
    property Item sourceItem: null
    //! the Map double the item is on (set by addMapItem, cleared on removal)
    property Item _map: null
    readonly property bool _isMapItem: true

    width: sourceItem ? sourceItem.width : 0
    height: sourceItem ? sourceItem.height : 0
    x: _map && coordinate && coordinate.isValid ? _map.fromCoordinate(coordinate, false).x - anchorPoint.x : 0
    y: _map && coordinate && coordinate.isValid ? _map.fromCoordinate(coordinate, false).y - anchorPoint.y : 0

    onSourceItemChanged: if (sourceItem) sourceItem.parent = item
    Component.onCompleted: if (sourceItem) sourceItem.parent = item
}
