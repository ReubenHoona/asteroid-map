// Copyright (C) 2026 eos-mainline contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Test double: Nemo.KeepAlive's DisplayBlanking (nothing blanks: the display is on)
import QtQuick

QtObject {
    enum Status { Unknown, Off, Dimmed, On }
    property bool preventBlanking: false
    property int status: DisplayBlanking.On
}
