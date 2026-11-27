/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Shapes
import org.asteroid.controls

// The next manoeuvre of the phone's trip as the trip screen's 48 dp white glyph (stock Maps'
// navigation_current_step.xml maneuver_icon, navigation_step_icon_size 48dp, tinted white). Our own
// line drawings (the stock pictures are Google Maps' assets), one stroked path on a 24 unit square
// per manoeuvre Gadgetbridge names (AsteroidOSNavigation.actionName); the finish is a flag, an
// unknown or absent manoeuvre the navigation arrow.
Item {
    id: glyph

    //! Gadgetbridge's manoeuvre name ("" when the phone gave none)
    property string act: ""
    property color color: Theme.color.onSurface

    implicitWidth: Theme.dp(48)
    implicitHeight: Theme.dp(48)

    readonly property var paths: ({
        "continue": "M12 21 V5 M7 10 L12 5 L17 10",
        "left": "M15 21 V13 Q15 9 11 9 H6 M10 5 L6 9 L10 13",
        "right": "M9 21 V13 Q9 9 13 9 H18 M14 5 L18 9 L14 13",
        "left_slight": "M14 21 V12 L7.5 5.5 M7.5 11 V5.5 H13",
        "right_slight": "M10 21 V12 L16.5 5.5 M16.5 11 V5.5 H11",
        "left_sharp": "M15 21 V6 L7 14 M7 8 V14 H13",
        "right_sharp": "M9 21 V6 L17 14 M17 8 V14 H11",
        "keep_left": "M13 21 V14 L8 9 V4 M5 7 L8 4 L11 7 M13 14 L17 10 V4",
        "keep_right": "M11 21 V14 L16 9 V4 M13 7 L16 4 L19 7 M11 14 L7 10 V4",
        "uturn_left": "M15 21 V10 A4 4 0 0 0 7 10 V17 M4 14 L7 17 L10 14",
        "uturn_right": "M9 21 V10 A4 4 0 0 1 17 10 V17 M20 14 L17 17 L14 14",
        "roundabout_right": "M12 21 V14 M16 10 A4 4 0 1 0 8 10 A4 4 0 1 0 16 10 M16 10 H20.5 M18 7.5 L20.5 10 L18 12.5",
        "roundabout_left": "M12 21 V14 M16 10 A4 4 0 1 0 8 10 A4 4 0 1 0 16 10 M8 10 H3.5 M6 7.5 L3.5 10 L6 12.5",
        "roundabout_straight": "M12 21 V14 M16 10 A4 4 0 1 0 8 10 A4 4 0 1 0 16 10 M12 6 V2.5 M9.5 5 L12 2.5 L14.5 5",
        "roundabout_uturn": "M12 21 V14 M16 10 A4 4 0 1 0 8 10 A4 4 0 1 0 16 10 M8 10 V20 M5.5 17.5 L8 20 L10.5 17.5",
        "merge": "M7 21 V16 L12 11 V4 M17 21 V16 L12 11 M9 7 L12 4 L15 7",
        "offroute": "M18 12 A6 6 0 1 1 15.5 7.1 M15.5 3 V7.1 H19.5",
        "finish": "M7 21 V4 M7 4.5 H17 L14.5 8 L17 11.5 H7"
    })
    readonly property string shown: paths.hasOwnProperty(act) ? act : ""

    Shape {
        id: shape
        anchors.fill: parent
        visible: glyph.shown !== ""
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: glyph.color
            // 2.3 of the 24 units (the scale moves the points, not the stroke)
            strokeWidth: glyph.width * 2.3 / 24
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            scale: Qt.size(glyph.width / 24, glyph.height / 24)
            PathSvg { path: glyph.shown !== "" ? glyph.paths[glyph.shown] : "M0 0" }
        }
    }
    // no manoeuvre named: the navigation arrow of the icon set
    Icon {
        anchors.fill: parent
        visible: glyph.shown === ""
        name: "ms-navigation-fill"
        color: glyph.color
    }
}
