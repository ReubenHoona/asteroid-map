Tests of asteroid-map
=====================

<!-- Copyright (C) 2026 eos-mainline contributors -->
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->

QML tests of the Map app, run on the build host under qemu-aarch64 with the
image's Qt (qmltestrunner, offscreen, 384 x 384, software Qt Quick). Each test
loads the app from this checkout (`src/main.qml` or a single file of `src/`)
on the test doubles of `qml/mocks/`: nothing reaches a bus, the positioning
or sensor services of the host, or the network (no map tile is fetched or
drawn, so no place is ever on screen). Fixtures use coordinates 0,0 or a few
thousandths of a degree from it (open sea) and invented names only.

## The test files

### qml/tst_location.qml

The location rules (FP-A5):

- CR-21: dconf `/org/asteroidos/settings/location-enabled` false (a bool or
  the string "false") is stock Maps' "location is off" state: the "Enable
  watch location?" dialog (check and close x) at start and on the locate
  button, no `update()`/`start()` of the PositionSource, no pill, no claim.
  The check writes true; the close x writes nothing. Switched at run time:
  on to off stops the source, drops the request and releases the claim; off
  to on asks for nothing until the locate button.
- CR-04: `SetInUse("location", true)` on the session bus, service
  `org.asteroidos.launcher`, path `/org/asteroidos/launcher/ongoing`,
  interface `org.asteroidos.launcher.Ongoing`, signature `sb`, when the locate
  button asks for a fix; `SetInUse("location", false)` when the asking ends:
  a fix, a source error (access, closed, timeout), the source giving up after
  the app's 30 s wait, a request that never started a source, the switch off,
  the app closed. Checked: the exact call, nothing at start or from panning
  and zooming, nothing on close without a claim, one call per change, always
  in pairs (true, false, true, ...).
- LocationStatus.qml on its own: idle / waiting / failed / fix / off, the
  single-shot wait (30 s by default, no polling), requests, errors, the
  switch, and `inUse` (the claim's source).

### qml/tst_map.qml

The map screen: the tile source the app sets up (plugin `osm`, OpenStreetMap's
tile server as the custom map type, providers repository off, a user agent),
the credit under the map, the view kept in dconf (zoom, centre x 1e6) at
start and close, the zoom buttons (0.3 a tap), wheel zoom (0.125 a step),
drag to pan, a fix (centre, zoom 15 unless closer, the position marker), the
compass button (modes 0/1/2 in `/map/view/compassMode`, its icon and turn, the
map turning with the heading in mode 2, press and hold for north up, compass
off), the "Waiting for location..." / "Can't detect your location" pill (texts,
colours, place), the six Material 3 tonal icon buttons (size, inside the round
screen, margins, stock accessible names), the menu opening the settings, the
set of dconf keys the app writes, and source checks (every file in
resources.qrc, every `qsTrId` id with its `//%` English, no hard-coded colours
or texts, no handwriting pad, waypoint.svg installed, the desktop entry).
Pictures: `map-main.png` (no tiles: the open map is black), `map-waiting.png`,
`map-failed.png`, `map-location-off.png`.

### qml/tst_waypoints.qml

The pin button's set point controls (close, confirm, the cross, the header),
the waypoint page (add with the map centre, the default name with the time,
the icon choice, the name through the stock full screen keyboard, save,
append), the pins drawn from `/map/waypointList` (icon, colour, the pin tip on
the coordinate, pin contrast on light and dark colours, outside writes), a tap
on a pin opening its page in edit mode, edit in place, remove of one entry,
dates and the default name in the system 12/24 hour format. Stored per
waypoint: [icon, [latitude, longitude], colour, name, time saved] (as JSON).
Pictures: `map-pins.png`, `map-set-point.png`, `map-waypoint-page.png`.

### qml/tst_settings.qml

The settings page from the menu: stock CP3A list numbers (top 16.64 %, sides
5.2 %, 4 dp apart), texts, the Compass switch (`/map/enableCompass`: the
compass sensor on and off) and the Use GPS switch (`/map/prioritiseGPS`:
satellite or all positioning methods), switches showing stored values, the
credits, back to the map. Picture: `map-settings.png`.

`qml/MapCase.qml` holds the helpers the four files share (start the app with
dconf values, find its parts, the claim log); it is not a test file.

## Running

    . ~/mainline/agents/newlook-wt/r2ah/env.sh      # or set the variables below yourself
    SHOTS=/some/folder tests/run-qemu.sh             # every tests/qml/tst_*.qml
    tests/run-qemu.sh tst_location tst_map           # some of them

`tests/run-qemu.sh` (the shared runner, the same file in each app) reads:

| variable | meaning |
|---|---|
| R | a copy of an image rootfs (qemu -L; only read), required |
| QEMU | the qemu-aarch64 user mode binary, required |
| QMLTESTRUNNER / XSYSROOT | an aarch64 qmltestrunner of the image's Qt, or a sysroot with one in usr/bin |
| CONTROLS / XB | a qml-asteroid checkout to use instead of the rootfs's controls, and a dir with its plugin built (else it is cross-built) |
| SYSROOTS / QM | the OE sysroots-components (lupdate/lrelease make the English catalog from this checkout), or a ready .qm |
| BUILD | build and log dir (default build/qemu-tests, ignored by git) |
| SHOTS | where the pictures go (default: the run folder, removed at the end) |
| TMO | seconds per file (default 600) |
| KEEP | 1 keeps the run folder |
| FAILS | failure lines shown per file (default 12) |
| TZ | the time zone of the run (default UTC; the 12/24 hour checks expect UTC) |

Expected output, one line per file and a total:

    tst_location.qml: N passed, 0 failed, 0 skipped, loops 0
    tst_map.qml: N passed, 0 failed, 0 skipped, loops 0
    tst_settings.qml: N passed, 0 failed, 0 skipped, loops 0
    tst_waypoints.qml: N passed, 0 failed, 0 skipped, loops 0
    Total: N passed, 0 failed, 0 skipped, 0 binding-loop warnings in 4 files (logs: ...)

The runner exits 1 on a failure, a file without totals or a binding loop.

## The doubles (qml/mocks)

| module | stands in for |
|---|---|
| Nemo.Configuration | dconf: `ConfStore` holds the values (`set()` = a write from outside, `writes`/`writesOf()` = what the app wrote) |
| Nemo.DBus | the session and system buses: `DBusInterface` only records each call in `DBusLog` (no reply) |
| Nemo.KeepAlive | mce's display blanking (the dialogs' DisplayBlanking) |
| QtLocation | the map: `Plugin` keeps name and parameters and loads no geo service; `Map` draws no tiles, projects with Web Mercator (center, zoomLevel, bearing) for pan, toCoordinate, fromCoordinate, alignCoordinateToPoint and the map items |
| QtPositioning | the positioning backend (geoclue): `PositionSource` with Qt 6's single request rules, driven by the test (`fix()`, `fail()`, `timeOut()`), counting `update()`/`start()`/`stop()`; `QtPositioning.coordinate()` |
| QtSensors | the compass sensor: `Compass` with readings given by the test (`setReading()`) |

## What the tests cannot see (needs the watch)

- Real tiles, their download, cache and the map's look over them (the cross
  and pins on light tiles, the credit under loaded tiles); pinch zoom and
  rotation (touch only).
- The real positioning stack: whether a fix comes at all, Qt's exact order of
  `active` and `sourceError` changes, whether `stop()` ends a single request
  already sent, and whether `sourceError` is reset when a new request starts.
- The launcher's side of CR-04 (FP-L1): that it owns `org.asteroidos.launcher`,
  shows the location indicator, and drops the claim if the app dies without
  sending `false` (a call made while the process exits may not leave it).
- The app going to the background: the map has no rule of its own for it; a
  single request runs to its end (fix, error or the backend's timeout) and the
  claim follows it.
- The real compass sensor, and the crown (whether it reaches the map as wheel
  events).
