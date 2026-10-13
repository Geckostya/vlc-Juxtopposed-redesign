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
pragma Singleton

import QtQuick

import VLC.MainInterface

// Profiles of the redesign (Figma "Profiles": Movies, Shows, Music, Work + New).
// A profile is a snapshot of the look of the player kept in the Qt settings: theme,
// accent color and the controls added with "Customize Player". Switching saves the
// snapshot of the current profile, then applies the one of the chosen profile.
QtObject {
    id: root

    property var names: {
        try {
            const v = JSON.parse(String(MainCtx.settingValue("Redesign/profileNames", "")))
            if (Array.isArray(v) && v.length > 0)
                return v
        } catch (e) { }
        return [qsTr("Movies"), qsTr("Shows"), qsTr("Music"), qsTr("Work")]
    }
    property string current: String(MainCtx.settingValue("Redesign/profile", ""))

    function snapshot() {
        return { theme: Theme.mode, accent: Theme.accentSetting, extras: RBarCatalog.extras }
    }

    function key(name) {
        return "Redesign/profiles/" + encodeURIComponent(name)
    }

    function select(name) {
        if (name === current)
            return
        if (current.length > 0)
            MainCtx.setSettingValue(key(current), JSON.stringify(snapshot()))
        let s = null
        try {
            s = JSON.parse(String(MainCtx.settingValue(key(name), "")))
        } catch (e) { }
        if (s) {
            Theme.setMode(s.theme || "dark")
            Theme.setAccent(s.accent || "")
            RBarCatalog.setExtras(Array.isArray(s.extras) ? s.extras : [])
        } else {
            // a profile used for the first time starts from the current look
            MainCtx.setSettingValue(key(name), JSON.stringify(snapshot()))
        }
        current = name
        MainCtx.setSettingValue("Redesign/profile", name)
    }

    function add(name) {
        name = String(name).trim()
        if (name.length === 0 || names.indexOf(name) >= 0)
            return
        names = names.concat([name])
        MainCtx.setSettingValue("Redesign/profileNames", JSON.stringify(names))
        select(name)
    }
}
