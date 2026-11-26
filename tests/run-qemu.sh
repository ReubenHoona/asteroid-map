#!/bin/sh
# Runs this app's QML tests under qemu-aarch64 against a copy of an AsteroidOS image rootfs, without a
# device: tests/qml/tst_*.qml with an aarch64 qmltestrunner (offscreen platform, 384 x 384, the software
# Qt Quick backend), the app's English catalog installed (-translation) so qsTrId() gives the texts the
# watch shows. Import order: the test doubles of tests/qml/mocks (Nemo.*, Connman, D-Bus), then
# org.asteroid.controls (the rootfs's, or CONTROLS= a qml-asteroid checkout) and the rootfs's
# org.asteroid.utils (both path-patched copies, see below), then the rootfs. The app's QML is read from
# src/ of this checkout. The rootfs and the checkout are only read; the run's files live in a fresh
# /tmp/qXXXXX folder that is removed at the end.
#
# usage: R=<rootfs copy> QEMU=<qemu-aarch64> QMLTESTRUNNER=<aarch64 qmltestrunner> tests/run-qemu.sh [test ...]
#   test: tst_x.qml or tst_x (tests/qml) or a path to a .qml file; none = every tests/qml/tst_*.qml
# Prints a line per file (its totals, the binding-loop warnings it logged, its failures) and a grand
# total; exits 1 when a test failed, a file gave no totals (crash, timeout) or logged a binding loop.
#
# Environment:
#   R              the rootfs copy, qemu -L (cp -a of an image rootfs; only read)               required
#   QEMU           the qemu-aarch64 (user mode) binary                                            required
#   QMLTESTRUNNER  an aarch64 qmltestrunner of the image's Qt; default $XSYSROOT/usr/bin/qmltestrunner
#   XSYSROOT       an aarch64 sysroot with the image's Qt (for QMLTESTRUNNER, or to build CONTROLS)
#   CONTROLS       a qml-asteroid checkout: its src/controls/qml and a plugin built from it replace the
#                  rootfs's org.asteroid.controls; the plugin comes from XB=, else CONTROLS's
#                  tests/qemu/xbuild.sh builds it into $BUILD/controls (needs XSYSROOT and SYSROOTS)
#   XB             a dir with libasteroidcontrolsplugin.so and plugins.qmltypes built from CONTROLS
#   SYSROOTS       the OE build's tmp/sysroots-components: lupdate and lrelease (qttools-native) make the
#                  English catalog from this checkout's sources; without it the rootfs's catalog is used
#   QM             the catalog to install instead (a .qm file)
#   BUILD          build and log dir (default build/qemu-tests in this checkout; git ignores build/)
#   SHOTS          a folder for the pictures tests save (default: the run folder, removed at the end)
#   TMO            seconds per file (default 600)      KEEP=1  keep the run folder
#   FAILS          failure lines shown per file (default 12)
#   TZ             the time zone of the run (default UTC)
#
# The plugins read /etc/asteroid/machine.conf and the controls also /usr/share/icons/asteroid/, which
# qemu -L does not redirect for them: copies of the plugins point those paths at the run folder (a path
# of the same length, hence the 11-character /tmp/qXXXXX). Tests save pictures as shots/<name>.png
# (relative to the run's working directory).
set -u
here=$(cd "$(dirname "$0")" && pwd)
C=$(cd "$here/.." && pwd)
die() { echo "run-qemu.sh: $*" >&2; exit 2; }
APP=$(sed -n '/^project(/,/)/{s/^[ \t]*\(asteroid-[a-z0-9-]*\)[ \t]*$/\1/p}' "$C/CMakeLists.txt" | head -1)
[ -n "$APP" ] || die "no project name in $C/CMakeLists.txt"
[ -n "${R:-}" ] || die "R= the rootfs copy"
[ -n "${QEMU:-}" ] || die "QEMU= the qemu-aarch64 binary"
[ -x "$QEMU" ] || die "QEMU=$QEMU is not executable"
for f in etc/asteroid/machine.conf usr/lib/qml/org/asteroid/controls/qmldir usr/lib/qml/org/asteroid/utils/qmldir \
	usr/lib/qml/QtTest/qmldir; do
	[ -e "$R/$f" ] || die "R=$R has no $f"
done
QTR=${QMLTESTRUNNER:-${XSYSROOT:+$XSYSROOT/usr/bin/qmltestrunner}}
[ -n "$QTR" ] && [ -f "$QTR" ] || die "QMLTESTRUNNER= or XSYSROOT= (for its usr/bin/qmltestrunner)"
B=${BUILD:-$C/build/qemu-tests}
TMO=${TMO:-600}
FAILS=${FAILS:-12}
mkdir -p "$B/logs" || die "cannot make $B"

# ---- what to run ----
QMLS=""
if [ $# -eq 0 ]; then
	QMLS=$(cd "$C/tests/qml" && ls tst_*.qml | sed "s#^#$C/tests/qml/#")
fi
for a in "$@"; do
	case $a in
	*/*.qml)
		[ -f "$a" ] || die "no test $a"
		QMLS="$QMLS $(cd "$(dirname "$a")" && pwd)/$(basename "$a")" ;;
	*)
		a=${a%.qml}
		[ -f "$C/tests/qml/$a.qml" ] || die "no test tests/qml/$a.qml"
		QMLS="$QMLS $C/tests/qml/$a.qml" ;;
	esac
done

# ---- the controls plugin ----
if [ -n "${CONTROLS:-}" ]; then
	[ -f "$CONTROLS/src/controls/CMakeLists.txt" ] || die "CONTROLS=$CONTROLS is not a qml-asteroid checkout"
	if [ -n "${XB:-}" ]; then
		PB=$XB
		echo "controls: $CONTROLS, plugin $PB (XB, as it is)"
	else
		PB=$B/controls
		mkdir -p "$PB"
		printf "controls: %s, plugin cross-built: " "$CONTROLS"
		B=$PB SRCTREE=$CONTROLS sh "$CONTROLS/tests/qemu/xbuild.sh" > "$B/logs/xbuild.log" 2>&1 \
			|| { tail -20 "$B/logs/xbuild.log"; die "plugin build failed: $B/logs/xbuild.log"; }
		echo "$(grep -c "^CXX " "$B/logs/xbuild.log") compiled"
	fi
	[ -f "$PB/libasteroidcontrolsplugin.so" ] && [ -f "$PB/plugins.qmltypes" ] \
		|| die "$PB has no libasteroidcontrolsplugin.so and plugins.qmltypes"
else
	echo "controls: the rootfs's"
fi

# ---- the English catalog ----
if [ -n "${QM:-}" ]; then
	[ -f "$QM" ] || die "QM=$QM is not a file"
	CAT=$QM
elif [ -n "${SYSROOTS:-}" ] && [ -x "$SYSROOTS/x86_64/qttools-native/usr/bin/lupdate" ]; then
	H=$SYSROOTS/x86_64
	LP=""
	for l in libpcre2-native qtbase-native qtdeclarative-native qttools-native zlib-native zstd-native icu-native \
		glib-2.0-native; do
		LP=$LP${LP:+:}$H/$l/usr/lib
	done
	CAT=$B/$APP.en.qm
	(cd "$C" && LD_LIBRARY_PATH=$LP LC_ALL=C.UTF-8 "$H/qttools-native/usr/bin/lupdate" -silent -locations none \
		-source-language en -target-language en $(find src -name "*.qml" -o -name "*.js") -ts "$B/$APP.en.ts" \
		&& LD_LIBRARY_PATH=$LP LC_ALL=C.UTF-8 "$H/qttools-native/usr/bin/lrelease" -silent -idbased \
		"$B/$APP.en.ts" -qm "$CAT") > "$B/logs/catalog.log" 2>&1 || die "catalog failed: $B/logs/catalog.log"
	echo "catalog: $APP.en.qm made from this checkout"
else
	CAT=$R/usr/share/translations/$APP.en.qm
	[ -f "$CAT" ] || die "no $CAT: give SYSROOTS= (to make it) or QM="
	echo "catalog: the rootfs's $APP.en.qm"
fi

# ---- the run folder: its path is as long as /etc/asteroid, for the plugin patches ----
T=$(mktemp -d /tmp/qXXXXX) || die "mktemp"
[ ${#T} -eq 11 ] || die "run folder $T: not 11 characters"
[ -n "${KEEP:-}" ] || trap 'rm -rf "$T"' EXIT
trap 'exit 130' INT TERM
mkdir -p "$T/a" "$T/home" "$T/run" "$T/icons"
chmod 700 "$T/home"
cp "$R/etc/asteroid/machine.conf" "$T/a/machine.conf"
# the watch's screen for the offscreen platform: 384 x 384, device pixel ratio 1
cat > "$T/offscreen.json" <<'JSON'
{ "synchronousWindowSystemEvents": false, "windowFrameMargins": false,
  "screens": [ { "name": "eos", "x": 0, "y": 0, "width": 384, "height": 384, "logicalDpiX": 96, "logicalDpiY": 96, "dpr": 1 } ] }
JSON
ln -s "$R/usr/share/icons/asteroid" "$T/icons/asteroi"
if [ -n "${SHOTS:-}" ]; then
	mkdir -p "$SHOTS" && ln -s "$(cd "$SHOTS" && pwd)" "$T/run/shots"
else
	mkdir "$T/run/shots"
fi
# plug SRC DST [icons]: a copy of a plugin that reads machine.conf (and the icons) from the run folder
patchpath() { # patchpath FILE OLD NEW: OLD -> NEW (same length) in FILE, Latin-1 and UTF-16-LE
	python3 - "$1" "$2" "$3" <<'EOF' || exit 2
import sys
p, old, new = sys.argv[1:4]
assert len(old) == len(new)
d = open(p, "rb").read()
for e in ("latin-1", "utf-16-le"):
    d = d.replace(old.encode(e), new.encode(e))
open(p, "wb").write(d)
EOF
}
plug() {
	cp "$1" "$2"
	patchpath "$2" /etc/asteroid/machine.conf "$T/a/machine.conf"
	[ "${3:-}" = icons ] && patchpath "$2" /usr/share/icons/asteroid/ "$T/icons/asteroi/"
	return 0
}
OV=$T/qml
O=$OV/org/asteroid/controls
mkdir -p "$O" "$OV/org/asteroid/utils"
if [ -n "${CONTROLS:-}" ]; then
	ln -s "$CONTROLS/src/controls/qml" "$O/qml"
	plug "$PB/libasteroidcontrolsplugin.so" "$O/libasteroidcontrolsplugin.so" icons
	cp "$PB/plugins.qmltypes" "$O/plugins.qmltypes"
	S=$(grep -o "qml/[A-Za-z]*\.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE" "$CONTROLS/src/controls/CMakeLists.txt" \
		| sed "s#qml/##;s#\.qml.*##" | tr "\n" " ")
	{
		grep "^module \|^linktarget \|^optional plugin \|^classname " "$R/usr/lib/qml/org/asteroid/controls/qmldir"
		sed -n '/^set(controls$/,/^)/p' "$CONTROLS/src/controls/CMakeLists.txt" | sed '1d;$d' | tr -d ' \t' \
			| while read -r cn; do
				[ -n "$cn" ] || continue
				case " $S " in *" $cn "*) echo "singleton $cn 1.0 qml/$cn.qml" ;; *) echo "$cn 1.0 qml/$cn.qml" ;; esac
			done
		echo "depends QtQuick"
	} > "$O/qmldir"
else
	for cf in "$R"/usr/lib/qml/org/asteroid/controls/*; do
		cn=$(basename "$cf")
		case $cn in
		*.so) plug "$cf" "$O/$cn" icons ;;
		*) ln -s "$cf" "$O/$cn" ;;
		esac
	done
fi
for uf in "$R"/usr/lib/qml/org/asteroid/utils/*; do
	un=$(basename "$uf")
	case $un in
	*.so) plug "$uf" "$OV/org/asteroid/utils/$un" ;;
	qmldir) grep -v "^prefer " "$uf" > "$OV/org/asteroid/utils/qmldir" ;;
	*) cp -r "$uf" "$OV/org/asteroid/utils/$un" ;;
	esac
done

# ---- run ----
NP=0; NF=0; NS=0; NL=0; NFILES=0; BAD=0
report() { # report NAME LOG RC: the file's line and its failures; adds to the totals
	rname=$1; rlog=$2; rc=$3
	tot=$(grep "^Totals: " "$rlog" | tail -1)
	loops=$(grep -c "inding loop" "$rlog")
	p=$(echo "$tot" | sed -n 's/^Totals: \([0-9]*\) passed, \([0-9]*\) failed, \([0-9]*\) skipped.*/\1 \2 \3/p')
	NFILES=$((NFILES + 1))
	NL=$((NL + loops))
	if [ -z "$p" ]; then
		echo "$rname: NO TOTALS (exit $rc$([ "$rc" = 124 ] && echo ", timed out after $TMO s")), loops $loops"
		tail -5 "$rlog" | sed 's/^/    /'
		BAD=1; NF=$((NF + 1))
		return
	fi
	set -- $p
	echo "$rname: $1 passed, $2 failed, $3 skipped, loops $loops"
	NP=$((NP + $1)); NF=$((NF + $2)); NS=$((NS + $3))
	if [ "$2" -gt 0 ] || [ "$loops" -gt 0 ]; then
		grep -E "^(FAIL|   Actual|   Expected|   Loc)|inding loop" "$rlog" | sed "s#$C/##g" \
			| head -"$FAILS" | sed 's/^/    /'
	fi
}
for f in $QMLS; do
	name=$(basename "$f")
	log=$B/logs/${name%.qml}.txt
	(cd "$T/run" && env -i HOME="$T/home" XDG_RUNTIME_DIR="$T/home" XDG_CONFIG_HOME="$T/home" PATH=/usr/bin:/bin \
		LC_ALL=C.UTF-8 TZ="${TZ:-UTC}" QT_QPA_PLATFORM="offscreen:configfile=$T/offscreen.json" \
		QT_QUICK_BACKEND=software QT_PLUGIN_PATH="$R/usr/lib/plugins" QML_DISABLE_DISK_CACHE=1 \
		QML_XHR_ALLOW_FILE_READ=1 QT_LOGGING_RULES="asteroid.rotary.debug=false" \
		QML_IMPORT_PATH="$C/tests/qml/mocks:$OV:$R/usr/lib/qml" QML2_IMPORT_PATH="$C/tests/qml/mocks:$OV:$R/usr/lib/qml" \
		timeout "$TMO" "$QEMU" -L "$R" "$QTR" -import "$C/tests/qml/mocks" -import "$OV" -translation "$CAT" \
		-input "$f") > "$log" 2>&1
	report "$name" "$log" $?
done
[ -n "${KEEP:-}" ] && echo "run folder kept: $T"
echo "Total: $NP passed, $NF failed, $NS skipped, $NL binding-loop warnings in $NFILES files (logs: $B/logs)"
[ "$NF" -eq 0 ] && [ "$NL" -eq 0 ] && [ "$BAD" -eq 0 ]
