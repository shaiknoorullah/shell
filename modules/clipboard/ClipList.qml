pragma ComponentBehavior: Bound

// Virtualised list of clipboard entries. Selection (currentIndex) is driven by
// the parent (ClipboardContent) so the search field can own keyboard focus;
// clicking a row emits activated(index).

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

StyledListView {
    id: root

    property var entries: []

    signal activated(int index)

    model: entries
    spacing: Tokens.spacing.small
    clip: true
    currentIndex: 0
    keyNavigationEnabled: false

    highlightMoveDuration: 150
    highlightResizeDuration: 0
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08
    }

    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: ClipEntry {
        onActivated: i => root.activated(i)
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }
}
