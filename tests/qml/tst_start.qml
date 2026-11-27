// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// The start (src/main.qml, src/MainMapView.qml): QQuickView makes main.qml at 0 x 0 and gives it the
// window's size after it. The map page is made once the app has its size (a map made at 0 x 0 did its
// work twice); the location question, not on screen at start, is made once the first frame is drawn,
// or at once when it is wanted before (location off at start: tst_location's test_off_at_start). The
// whole app on the doubles of mocks/.
import QtQuick
import QtTest
import Nemo.Configuration
import Nemo.DBus
import org.asteroid.controls

Item {
    id: root
    width: 384
    height: 384

    Rectangle { anchors.fill: parent; color: "black" }
    Item { id: host; anchors.fill: parent }

    MapCase {
        id: tc
        name: "Start"
        host: host

        function test_map_at_size_question_after_the_first_frame() {
            ConfStore.reset()
            DBusLog.reset()
            var c = Qt.createComponent(Qt.resolvedUrl("../../src/main.qml"))
            verify(c.status === Component.Ready, c.errorString())
            app = createTemporaryObject(c, null)
            verify(app, "the app")
            compare(app.width, 0)
            compare(mainView(), undefined, "no map page at 0 x 0")
            app.parent = host
            compare(app.width, 384)
            var v = mainView()
            verify(v, "the map page, made at the screen's size")
            compare(v.width, 384)
            compare(v.locationOn, true)
            compare(dialog(), undefined, "no question before the first frame")
            tryVerify(function () { return v.firstFrameDrawn }, 3000, "the first frame")
            verify(dialog(), "the question, made right after it")
            compare(dialog().shown, false)
            compare(dialog().parent.z, 1000, "a Dialog's own z, as before")
        }
    }
}
