# VLC fork: community redesign

This repository is VLC 4.0-dev with an in-progress implementation of the community redesign
(Figma "VLC Redesign (Community)").

Read `redesign-dev/HANDOFF.md` first: goals, decisions, what is done, what is not verified,
how to build on Windows and the next stages.

Key points:
- The new UI is the QML module `VLC.Redesign` in `modules/gui/qt/redesign/`, written from scratch on top of
  the existing C++ facade of the Qt module. Do not edit the classic QML for redesign work.
- Option `qt-redesign` (default on), `--no-qt-redesign` restores the classic UI.
- Icons: `#FF00FF` main color, `#FF8800` accent, rendered by `image://redesignicon/` (synchronous on purpose).
- Design references: `C:\Projects\VLC\RedesignSources\` (FigmaExport PNG/SVG, video, transcript).
- Build on Windows: `redesign-dev\setup.bat` once, then `redesign-dev\build.bat`, run with `redesign-dev\run.bat`.
- Keep meson.build and Makefile.am in sync when adding QML files or icons.
- The user speaks Russian.
