# VLC redesign (Qt Quick)

This folder holds a new interface for the Qt module, written from scratch to
follow the community redesign made by Juxtopposed. The C++ side of
the Qt module is reused as is. That covers `Player`, `MainPlaylistController`,
the media library models, `DialogsProvider` and the video compositors. Only
the QML layer is new.

* `qml/`: the `VLC.Redesign` QML module, with `RMainInterface.qml` as its root
* `icons/`: the icon set exported from the Figma file. Main color is
  `#FF00FF`, accent is `#FF8800`, and both are recolored at runtime by
  `RedesignIconProvider` (`image://redesignicon/<name>?c=<color>&a=<accent>`)
* `redesign_icon_provider.*`: synchronous SVG provider for these icons

The redesigned interface is enabled by default. Start VLC with
`--no-qt-redesign`, or untick *Interface > Main interfaces > Qt > Use the
redesigned interface*, to get the classic interface back.

## Status

| Stage | Content | State |
|-------|---------|-------|
| 1 | Theme, icons, top bar, control bar (thick seek bar, cone volume), tracks popup (video / audio / subtitles), playback popup, queue / bookmarks / chapters panel, main menu, right click menu, auto hiding bars | done |
| 2 | Library sidebar (compact and full), home page, music player view, miniplayer | todo |
| 3 | Settings window (19 screens), keyboard shortcuts window | todo |
| 4 | Dialogs: add subtitles to folder / playlist, open network stream, new playlist | todo |
| 5 | Onboarding, layout customization, profiles | todo |

## Design tokens

`Theme.qml` mirrors the Figma variables (`Dark/BG/A3`, `Dark/FG/A2`, ...).
Sizes are given at 1x and scaled with the interface scale factor through
`Theme.dp()`.
