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

// Header of the library (Figma "Player-1"): back / forward, breadcrumb, item count,
// sort, grid / list, search and the page menu.
Item {
    id: root

    property var library   // RLibraryView

    implicitHeight: Theme.dp(64)

    Row {
        id: nav
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(4)

        RIconButton {
            iconName: "arrow_left"
            toolTip: qsTr("Back")
            enabled: root.library.backStack.length > 0
            onClicked: root.library.back()
        }
        RIconButton {
            iconName: "arrow_right"
            toolTip: qsTr("Forward")
            enabled: root.library.forwardStack.length > 0
            onClicked: root.library.forward()
        }

        Item { width: Theme.dp(8); height: 1 }

        // breadcrumb: parents, then the current page in bold
        Repeater {
            model: root.library.route.crumbs.concat([root.library.route])
            delegate: Row {
                id: crumb
                required property var modelData
                required property int index
                readonly property bool last: index === root.library.route.crumbs.length
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                RIcon {
                    visible: crumb.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_right"
                    size: Theme.dp(12)
                    color: Theme.textDim
                }
                T.AbstractButton {
                    id: crumbBtn
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: crumbText.implicitWidth
                    implicitHeight: Theme.dp(28)
                    hoverEnabled: true
                    enabled: !crumb.last
                    onClicked: root.library.navigate(crumb.modelData)
                    contentItem: RText {
                        id: crumbText
                        text: crumb.modelData.title
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: crumb.last ? Font.DemiBold : Font.Normal
                        color: crumb.last || crumbBtn.hovered ? Theme.textStrong : Theme.textItem
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(12)

        RText {
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("%n items", "", root.library.itemCount)
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall + Theme.dp(1)
        }

        RIconButton {
            id: sortBtn
            anchors.verticalCenter: parent.verticalCenter
            iconName: root.library.sortCriteria.length > 0 ? "sort_active" : "sort"
            toolTip: qsTr("Sort")
            onClicked: sortMenu.popup(sortBtn, 0, sortBtn.height + Theme.dp(6))
        }

        RIconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: root.library.grid ? "list" : "grid"
            toolTip: root.library.grid ? qsTr("List view") : qsTr("Grid view")
            onClicked: root.library.grid = !root.library.grid
        }

        RTextField {
            id: search
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Theme.dp(320), root.width * 0.25)
            height: Theme.dp(34)
            leftPadding: Theme.dp(36)
            placeholderText: qsTr("Search")
            background: Rectangle { radius: Theme.radius; color: Theme.p.bgA3 }
            onTextChanged: searchDelay.restart()
            Timer { id: searchDelay; interval: 300; onTriggered: root.library.searchPattern = search.text }
            Connections {
                target: root.library
                function onRouteChanged() { search.text = "" }
            }
            RIcon {
                x: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Theme.iconSizeSmall
                color: Theme.textDim
            }
        }

        RIconButton {
            anchors.verticalCenter: parent.verticalCenter
            iconName: "more"
            toolTip: qsTr("More")
            onClicked: pageMenu.popup(this, 0, height + Theme.dp(6))
        }
    }

    RMenu {
        id: sortMenu
        RAction { text: qsTr("Default order"); checkable: true; checked: root.library.sortCriteria === ""; onTriggered: root.library.sortCriteria = "" }
        RAction { text: qsTr("Name"); checkable: true; checked: root.library.sortCriteria === "title"; onTriggered: root.library.sortCriteria = "title" }
        RAction { text: qsTr("Duration"); checkable: true; checked: root.library.sortCriteria === "duration"; onTriggered: root.library.sortCriteria = "duration" }
        RAction { text: qsTr("Date added"); checkable: true; checked: root.library.sortCriteria === "insertion"; onTriggered: root.library.sortCriteria = "insertion" }
        RMenuSeparator { }
        RAction {
            text: root.library.sortOrder === Qt.AscendingOrder ? qsTr("Ascending") : qsTr("Descending")
            iconName: root.library.sortOrder === Qt.AscendingOrder ? "arrow_up" : "arrow_down"
            onTriggered: root.library.sortOrder = root.library.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder
        }
    }

    RMenu {
        id: pageMenu
        RAction { iconName: "add"; text: qsTr("Add a folder to the library"); onTriggered: root.library.parent && addFolderProxy() }
        RAction { iconName: "refresh"; text: qsTr("Rescan the library"); onTriggered: MainCtx.mediaLibraryAvailable && rescan.item && rescan.item.reload() }
        RAction { iconName: "settings_2t"; text: qsTr("Library settings"); onTriggered: RWindows.settingsRequested("library") }
    }

    function addFolderProxy() {
        const dir = RedesignSettings.browseDirectory("")
        if (dir.length > 0 && folders.item)
            folders.item.add("file:///" + dir.replace(/\\/g, "/").replace(/^\/+/, ""))
    }

    Loader { id: folders; active: MainCtx.mediaLibraryAvailable; source: "RLibraryFolders.qml" }
    Loader { id: rescan; active: MainCtx.mediaLibraryAvailable; source: "RLibraryRescan.qml" }
}
