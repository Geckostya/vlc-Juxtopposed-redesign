/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
// NOTE: all modules used throughout the redesigned interface must be imported
//       here, so that if one of them can not be imported the interface can
//       close gracefully.
import QtQml
import QtQml.Models
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates
import QtQuick.Window

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.Playlist
import VLC.Player
import VLC.Dialogs
import VLC.Menus
import VLC.Redesign

// Root item of the redesigned interface ("--qt-redesign").
Item {
    id: root

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Main interface")

    Binding { target: Theme; property: "scale"; value: MainCtx.intfScaleFactor }
    // dark/light/system and the accent are chosen in Settings > General (see Theme.mode)

    // ---- secondary windows of the redesign, created on first use

    function openSettings(category) {
        settingsLoader.active = true
        settingsLoader.item.openCategory(category)
    }

    Loader {
        id: settingsLoader
        active: false
        sourceComponent: RSettingsWindow {
            transientParent: root.Window.window
        }
    }

    function openShortcuts() {
        shortcutsLoader.active = true
        shortcutsLoader.item.open()
    }

    Loader {
        id: shortcutsLoader
        active: false
        sourceComponent: RShortcutsWindow {
            transientParent: root.Window.window
        }
    }

    Connections {
        target: DialogsProvider
        function onRedesignSettingsRequested() { root.openSettings("") }
    }

    // --qt-redesign-open=settings[:category] | shortcuts (development helper)
    Component.onCompleted: {
        const open = RedesignSettings.inheritedString("qt-redesign-open")
        if (open.startsWith("settings"))
            Qt.callLater(root.openSettings, open.split(":")[1] || "")
        else if (open === "shortcuts")
            Qt.callLater(root.openShortcuts)
        else if (open === "network")
            Qt.callLater(RWindows.networkStreamRequested)
        else if (open === "playlist")
            Qt.callLater(RWindows.newPlaylistRequested)
        else if (open.startsWith("subtitles"))
            Qt.callLater(RWindows.addSubtitlesRequested, open.substring(10))
        else if (open.startsWith("effects"))
            Qt.callLater(playerView.openEffects, open === "effects:audio" ? 1 : 0)
    }

    Loader { id: networkLoader; active: false; sourceComponent: RNetworkStreamDialog { transientParent: root.Window.window } }
    Loader { id: newPlaylistLoader; active: false; sourceComponent: RNewPlaylistDialog { transientParent: root.Window.window } }
    Loader { id: addSubtitlesLoader; active: false; sourceComponent: RAddSubtitlesDialog { transientParent: root.Window.window } }

    Connections {
        target: RWindows
        function onSettingsRequested(category) { root.openSettings(category) }
        function onShortcutsRequested() { root.openShortcuts() }
        function onNetworkStreamRequested() { networkLoader.active = true; networkLoader.item.open() }
        function onNewPlaylistRequested() { newPlaylistLoader.active = true; newPlaylistLoader.item.open() }
        function onAddSubtitlesRequested(url) { addSubtitlesLoader.active = true; addSubtitlesLoader.item.openFor(url) }
    }

    // keep VLCStyle informed, some C++ helpers (tooltips, popups) rely on it
    Binding { target: VLCStyle; property: "appWidth"; value: root.width }
    Binding { target: VLCStyle; property: "appHeight"; value: root.height }

    Window.onWindowChanged: {
        if (Window.window && !Qt.colorEqual(Window.window.color, "transparent"))
            Window.window.color = Qt.binding(function() { return Theme.barBackground })
    }

    Widgets.ToolTipExt {
        id: attachedToolTip
        parent: null
        z: 99
        colorContext.palette: VLCStyle.palette
        Component.onCompleted: MainCtx.setAttachedToolTip(this)
    }

    Widgets.PointingTooltip {
        parent: null
        z: 99
        colorContext.palette: VLCStyle.palette
        Widgets.PointingToolTipAttached.instance: this
        Component.onDestruction: {
            if (Widgets.PointingToolTipAttached.instance === this)
                Widgets.PointingToolTipAttached.instance = null
        }
    }

    DropArea {
        anchors.fill: parent
        z: -1

        onEntered: (drag) => {
            drag.accepted = !drag.source && (drag.hasUrls || drag.hasText)
        }

        onDropped: (drop) => {
            let urls = []
            if (drop.hasUrls) {
                for (let i = 0; i < drop.urls.length; i++)
                    urls.push(drop.urls[i])
            } else if (drop.hasText) {
                urls.push(...drop.text.replace("\r\n", "\n").split("\n"))
            }
            if (urls.length === 0)
                return
            // a single subtitle file dropped while playing is attached to the media
            if (Player.isStarted && urls.length === 1 && Player.associateSubtitleFile(urls[0])) {
                drop.accept()
                return
            }
            MainPlaylistController.append(urls, true)
            drop.accept()
        }
    }

    RPlayerView {
        id: playerView
        anchors.fill: parent
        focus: true
    }

    Loader {
        asynchronous: true
        source: "qrc:///qt/qml/VLC/Menus/GlobalShortcuts.qml"
    }

    // resize handles on the window border when using client side decorations
    Loader {
        active: {
            const v = MainCtx.intfMainWindow.visibility
            return MainCtx.clientSideDecoration && !MainCtx.platformHandlesResizeWithCSD()
                   && v !== Window.Maximized && v !== Window.FullScreen
        }
        Component.onCompleted: {
            setSource("qrc:///qt/qml/VLC/Widgets/CSDMouseStealer.qml",
                      { target: root, anchorInside: true })
        }
    }
}
