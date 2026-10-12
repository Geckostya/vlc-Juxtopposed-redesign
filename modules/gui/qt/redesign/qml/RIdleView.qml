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
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Playlist
import VLC.Dialogs

// Shown when there is no video: big artwork for music, otherwise the cone
// and a call to action to open something.
Item {
    id: root

    readonly property bool hasArtwork: Player.isStarted && Player.artwork.toString().length > 0

    Image {
        id: artwork
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Theme.dp(20)
        width: Math.min(parent.width, parent.height) * 0.5
        height: width
        fillMode: Image.PreserveAspectCrop
        source: root.hasArtwork ? Player.artwork : ""
        visible: root.hasArtwork && status === Image.Ready
        asynchronous: true
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.dp(18)
        visible: !artwork.visible

        RIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "logo"
            size: Theme.dp(96)
            color: Theme.p.logo
            accentColor: Theme.p.logo
            opacity: 0.9
        }

        RText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Player.isStarted
            text: qsTr("Drop media here to play it")
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeLarge
        }

        RPanelButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Player.isStarted
            implicitWidth: Theme.dp(200)
            text: qsTr("Open media…")
            onClicked: DialogsProvider.simpleOpenDialog()
        }
    }

    RText {
        anchors.top: artwork.bottom
        anchors.topMargin: Theme.dp(16)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: artwork.visible
        text: Player.artist.length > 0 ? Player.title + "  —  " + Player.artist : Player.title
        color: Theme.textStrong
        font.pixelSize: Theme.fontSizeLarge
    }
}
