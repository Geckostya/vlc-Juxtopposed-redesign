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
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player

// Library of the redesign (Figma "Player-1..5"): sidebar on the left, header with
// history, breadcrumb, sort, view and search, and the page of the current route.
// The pages need the media library: they are loaded only when it is available.
Item {
    id: root

    // route: { page: "home" | "videos" | "music" | "network" | "playlists" | "recent",
    //          title, params: {...}, crumbs: [route, ...] (parents, for the breadcrumb) }
    property var route: ({ page: "home", title: qsTr("Home"), params: ({}), crumbs: [] })
    property var backStack: []
    property var forwardStack: []

    // header state shared with the page
    property bool grid: true
    property string searchPattern: ""
    property string sortCriteria: ""
    property int sortOrder: Qt.AscendingOrder
    property int itemCount: 0

    // area where RMainInterface shows the playing media while browsing
    readonly property rect miniPlayerRect: Qt.rect(width - Theme.dp(396), height - Theme.dp(344),
                                                   Theme.dp(380), Theme.dp(214))

    signal backToPlayer()

    function navigate(r) {
        backStack = backStack.concat([route])
        forwardStack = []
        searchPattern = ""
        route = r
    }
    // route of a top level page of the sidebar
    function openPage(page) {
        const titles = { home: qsTr("Home"), videos: qsTr("Videos"), music: qsTr("Music"),
                         network: qsTr("Network"), playlists: qsTr("Playlists"), recent: qsTr("Recent") }
        if (route.page === page && route.crumbs.length === 0)
            return
        navigate({ page: page, title: titles[page], params: ({}), crumbs: [] })
    }
    // route below the current one (folder, album...)
    function openChild(title, params) {
        navigate({ page: route.page, title: title, params: params,
                   crumbs: route.crumbs.concat([route]) })
    }
    function back() {
        if (backStack.length === 0)
            return
        forwardStack = [route].concat(forwardStack)
        route = backStack[backStack.length - 1]
        backStack = backStack.slice(0, -1)
    }
    function forward() {
        if (forwardStack.length === 0)
            return
        backStack = backStack.concat([route])
        route = forwardStack[0]
        forwardStack = forwardStack.slice(1)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.p.bgB2
    }

    // same top bar as the player; its sidebar button goes back to the player
    RTopBar {
        id: topBar
        width: parent.width
        libraryAvailable: Player.isStarted
        sidebarOpen: true
        onSidebarToggled: root.backToPlayer()
        onMenuRequested: mainMenu.popup(menuButton, 0, menuButton.height + Theme.dp(6))
    }
    RMainMenu { id: mainMenu }

    RLibrarySidebar {
        id: sidebar
        x: Theme.dp(8)
        y: topBar.height + Theme.dp(8)
        width: Theme.dp(200)
        height: parent.height - y - Theme.dp(8)
        currentPage: root.route.page
        onPageRequested: (page) => root.openPage(page)
        onAddRequested: addFolder.trigger()
    }

    Item {
        id: main
        anchors.left: sidebar.right
        anchors.leftMargin: Theme.dp(28)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(24)
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom

        RLibraryHeader {
            id: header
            width: parent.width
            library: root
        }

        Rectangle {
            id: divider
            anchors.top: header.bottom
            width: parent.width
            height: 1
            color: Theme.p.dividerDim
        }

        Loader {
            id: page
            anchors.top: divider.bottom
            anchors.topMargin: Theme.dp(20)
            anchors.bottom: parent.bottom
            width: parent.width
            active: MainCtx.mediaLibraryAvailable || root.route.page === "network"
            source: {
                switch (root.route.page) {
                case "videos": return "RLibVideosPage.qml"
                case "music": return "RLibMusicPage.qml"
                case "network": return "RLibNetworkPage.qml"
                case "playlists": return "RLibPlaylistsPage.qml"
                case "recent": return "RLibRecentPage.qml"
                default: return "RLibHomePage.qml"
                }
            }
            onLoaded: item.library = root
        }

        RText {
            anchors.centerIn: page
            visible: !page.active
            width: Math.min(implicitWidth, parent.width - Theme.dp(40))
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("The media library is turned off. Turn on \"Use the media library\" in Settings > Library and restart VLC.")
            color: Theme.textDim
        }
    }

    // "Add item": adds a folder to the media library
    Loader {
        id: addFolder
        active: MainCtx.mediaLibraryAvailable
        source: "RLibraryFolders.qml"
        function trigger() {
            const dir = RedesignSettings.browseDirectory("")
            if (dir.length > 0 && item)
                item.add("file:///" + dir.replace(/\\/g, "/").replace(/^\/+/, ""))
        }
    }
}
