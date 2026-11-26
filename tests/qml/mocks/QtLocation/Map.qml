// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: QtLocation's Map without tiles: nothing is fetched or drawn but
// its colour (the app sets it transparent) and its map items. The view is a
// Web Mercator projection of 256 px tiles (center, zoomLevel, bearing), so
// fromCoordinate, toCoordinate, pan and alignCoordinateToPoint place things as
// the real Map does; zoomLevel is clamped to [minimumZoomLevel,
// maximumZoomLevel]. MapQuickItems declared in it are added at completion, as
// in the real Map; addMapItem, removeMapItem and clearMapItems as Qt 6's
// (a removed item loses its parent item).
import QtQuick
import QtPositioning

Item {
    id: map

    property QtObject plugin: null
    property var supportedMapTypes: [{ name: "Test map", style: 0, mobile: false, night: false }]
    property var activeMapType: null
    property real zoomLevel: 8
    property real minimumZoomLevel: 0
    property real maximumZoomLevel: 20
    property real bearing: 0
    property real tilt: 0
    property var center: QtPositioning.coordinate(0, 0)
    property bool copyrightsVisible: true
    property color color: "transparent"
    readonly property var mapItems: _items
    property var _items: []

    onZoomLevelChanged: {
        if (zoomLevel < minimumZoomLevel)
            zoomLevel = minimumZoomLevel
        else if (zoomLevel > maximumZoomLevel)
            zoomLevel = maximumZoomLevel
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        color: map.color
    }

    // ---- the projection ----
    function _scale() { return 256 * Math.pow(2, zoomLevel) }
    function _world(c) {
        var s = _scale()
        var sin = Math.sin(c.latitude * Math.PI / 180)
        sin = Math.min(Math.max(sin, -0.9999), 0.9999)
        return { x: (c.longitude + 180) / 360 * s,
                 y: (0.5 - Math.log((1 + sin) / (1 - sin)) / (4 * Math.PI)) * s }
    }
    function _coordinate(wx, wy) {
        var s = _scale()
        var lon = wx / s * 360 - 180
        var lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * wy / s))) * 180 / Math.PI
        return QtPositioning.coordinate(lat, lon)
    }
    // screen offset from the centre -> world offset (the map turns by bearing)
    function _unturn(dx, dy) {
        var r = bearing * Math.PI / 180
        return { x: dx * Math.cos(r) - dy * Math.sin(r), y: dx * Math.sin(r) + dy * Math.cos(r) }
    }
    function _turn(dx, dy) {
        var r = -bearing * Math.PI / 180
        return { x: dx * Math.cos(r) - dy * Math.sin(r), y: dx * Math.sin(r) + dy * Math.cos(r) }
    }
    function fromCoordinate(coordinate, clipToViewPort) {
        var w = _world(coordinate), m = _world(center)
        var t = _turn(w.x - m.x, w.y - m.y)
        var p = Qt.point(width / 2 + t.x, height / 2 + t.y)
        if (clipToViewPort !== false && (p.x < 0 || p.y < 0 || p.x > width || p.y > height))
            return Qt.point(NaN, NaN)
        return p
    }
    function toCoordinate(position, clipToViewPort) {
        var m = _world(center)
        var u = _unturn(position.x - width / 2, position.y - height / 2)
        return _coordinate(m.x + u.x, m.y + u.y)
    }
    function pan(dx, dy) {
        center = toCoordinate(Qt.point(width / 2 + dx, height / 2 + dy), false)
    }
    function alignCoordinateToPoint(coordinate, point) {
        var w = _world(coordinate)
        var u = _unturn(point.x - width / 2, point.y - height / 2)
        center = _coordinate(w.x - u.x, w.y - u.y)
    }

    // ---- map items ----
    function addMapItem(item) {
        if (!item || _items.indexOf(item) >= 0)
            return
        var l = _items
        l.push(item)
        _items = l
        item._map = map
        item.parent = map
    }
    function removeMapItem(item) {
        var i = _items.indexOf(item)
        if (i < 0)
            return
        var l = _items
        l.splice(i, 1)
        _items = l
        item._map = null
        item.parent = null
    }
    function clearMapItems() {
        var l = _items.slice()
        for (var i = 0; i < l.length; i++)
            removeMapItem(l[i])
    }

    Component.onCompleted: {
        for (var i = 0; i < children.length; i++)
            if (children[i]._isMapItem === true)
                addMapItem(children[i])
        // the app may have set center.latitude/longitude in place: let the
        // items see the centre (the real Map notifies such a change)
        Qt.callLater(_renotify)
    }
    function _renotify() { center = QtPositioning.coordinate(center.latitude, center.longitude) }
}
