/*
 * Copyright (C) 2026 eos
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import Nemo.DBus

// What the Maps app asks of the phone, through asteroid-btsyncd's assistant relay
// (org.asteroidos.btsyncd.Assistant on the session bus; the phone half is Gadgetbridge's
// AsteroidOSPhoneActionRunner and AsteroidOSNavigation):
//   - act(): the phone's actions, as the launcher's assistant sends them ("nav": the phone's Google
//     Maps starts the trip; one ActResult per Act, er "no-phone" when no phone is there, "old-app"
//     for a Gadgetbridge without the action)
//   - trip: the phone's turn by turn navigation, the PhoneEvent "nav" ({"st":"nav","ins","di","dm",
//     "act","eta","tt","dt","pc"} or {"st":"end"}), and at start the last one btsyncd has
//     (PhoneEventState "nav", with its age; an older btsyncd has no such method and the trip shows
//     with the next turn). A trip with no turn for 10 minutes is over (Gadgetbridge's rule).
// Battery: nothing polls. The events come only while the phone navigates, and only while the app runs
// does it take them.
Item {
    id: link
    objectName: "phoneLink"
    visible: false

    //! the trip as the phone last said it (the event's object), null when none is known
    property var trip: null
    //! the time the trip's last turn came (ms since the epoch; the age btsyncd gave counts back)
    property double tripAt: 0
    //! the phone navigates: a turn came and no end after it, less than 10 minutes ago
    readonly property bool navigating: trip !== null && trip.st === "nav"
    //! btsyncd answered the question at start (or has no such method): the trip is as known as it gets
    property bool stateKnown: false
    readonly property int staleMs: 600000

    //! a trip began (atStart: btsyncd's state at start said so, else a turn came)
    signal tripStarted(bool atStart)
    signal tripEnded()
    //! btsyncd answered where the trip is (answered false: an older btsyncd, no such method)
    signal stateChecked(bool answered)

    DBusInterface {
        id: relay
        bus: DBus.SessionBus
        service: "org.asteroidos.btsyncd"
        path: "/org/asteroidos/btsyncd/assistant"
        iface: "org.asteroidos.btsyncd.Assistant"
        signalsEnabled: true
        function rcActResult(id: int, json: string) { link.actResult(id, json) }
        function rcPhoneEvent(kind: string, json: string) { link.phoneEvent(kind, json) }
    }
    DBusInterface {
        id: phone
        bus: DBus.SessionBus
        service: "org.asteroidos.btsyncd"
        path: "/org/asteroidos/btsyncd/phone"
        iface: "org.asteroidos.btsyncd.Phone"
        // the phone gone during a trip: no end will come, the trip is over (btsyncd forgets it too)
        signalsEnabled: link.navigating
        function rcConnectedChanged(connected: bool) {
            if (!connected && link.navigating)
                link.setTrip({ st: "end" }, Date.now(), false)
        }
    }

    // ---- the trip ----
    function phoneEvent(kind, json) {
        if (kind !== "nav")
            return
        var o
        try { o = JSON.parse(json) } catch (e) { return }
        if (!o || typeof o !== "object")
            return
        setTrip(o, Date.now(), false)
    }
    function setTrip(o, at, atStart) {
        var was = navigating
        if (o.st === "nav") {
            // a new trip when none was on, or the last turn is 10 minutes old
            var fresh = !was || at - tripAt > staleMs
            trip = o
            tripAt = at
            stateKnown = true
            if (fresh) {
                if (was)
                    tripEnded()
                tripStarted(!!atStart)
            }
        } else if (o.st === "end") {
            trip = null
            tripAt = 0
            stateKnown = true
            if (was)
                tripEnded()
        }
    }
    //! where the trip is now (at start): btsyncd's last "nav" with its age
    function refresh() {
        relay.typedCall("PhoneEventState", [{ "type": "s", "value": "nav" }], function (json) {
            var o = null
            try { o = json ? JSON.parse(json) : null } catch (e) { o = null }
            if (o && o.st === "nav" && Number(o.age) * 1000 < staleMs) {
                var age = Math.max(0, Number(o.age) || 0)
                delete o.age
                if (!navigating)
                    setTrip(o, Date.now() - age * 1000, true)
            }
            stateKnown = true
            stateChecked(true)
        }, function () {
            stateKnown = true
            stateChecked(false)
        })
    }

    // ---- the phone's actions ----
    property var actWaits: ({})
    property int actSeq: 2000000 + Math.floor(Math.random() * 1000000)

    //! act({ a: "nav", q, mode }, cb): cb(result) with { ok, er, ... }
    function act(json, cb) {
        relay.typedCall("Actions", [], function (list) {
            if (list && list.indexOf(json.a) >= 0) {
                var id = ++actSeq
                var waits = actWaits
                waits[id] = cb
                actWaits = waits
                relay.typedCall("Act", [{ "type": "u", "value": id }, { "type": "s", "value": JSON.stringify(json) }],
                    function (ok) { if (!ok) actResult(id, JSON.stringify({ ok: false, er: "no-phone" })) },
                    function () { actResult(id, JSON.stringify({ ok: false, er: "no-phone" })) })
                return
            }
            // connected but without them: Gadgetbridge is too old
            phone.typedCall("Connected", [], function (connected) {
                cb({ ok: false, er: connected ? "old-app" : "no-phone" })
            }, function () { cb({ ok: false, er: "no-phone" }) })
        }, function () { cb({ ok: false, er: "no-phone" }) })
    }
    function actResult(id, json) {
        var cb = actWaits[id]
        if (!cb)
            return
        var waits = actWaits
        delete waits[id]
        actWaits = waits
        var r
        try { r = JSON.parse(json) } catch (e) { r = { ok: false, er: "failed" } }
        cb(r)
    }
}
