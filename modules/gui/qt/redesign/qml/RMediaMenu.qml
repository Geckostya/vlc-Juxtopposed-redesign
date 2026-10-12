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

import VLC.MediaLibrary

// Right click menu of library items (Figma "file context menu", "folder context menu").
RMenu {
    id: root

    property var item
    property bool isFolder: false
    property var togglePlayed: null      // function, for videos

    function openFor(it, globalPos, folder, played) {
        item = it
        isFolder = folder === true
        togglePlayed = played || null
        const p = parent ? parent.mapFromGlobal(globalPos.x, globalPos.y) : globalPos
        popup(p.x, p.y)
    }

    RAction {
        iconName: "play"
        text: root.isFolder ? qsTr("Play all") : qsTr("Play")
        onTriggered: MediaLib.addAndPlay(root.item.id)
    }
    RAction {
        iconName: "queue_2t"
        text: qsTr("Add to queue")
        onTriggered: MediaLib.addToPlaylist(root.item.id)
    }
    RAction {
        iconName: "check_selected_2t"
        text: qsTr("Mark as watched / unwatched")
        enabled: root.togglePlayed !== null
        onTriggered: root.togglePlayed()
    }
}
