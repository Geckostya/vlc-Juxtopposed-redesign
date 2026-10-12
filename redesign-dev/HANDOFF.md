# Редизайн VLC: передача работы

> **Начните отсюда.** Документ описывает всё, чтобы продолжить работу без предыдущей переписки.
> Копия лежит в репозитории: `Source\redesign-dev\HANDOFF.md`.

## 0. Где что лежит

```
C:\Projects\VLC\
├── HANDOFF.md              ← этот документ
├── setup.bat               ← разовая установка окружения сборки (нативно, без WSL)
├── build.bat               ← сборка VLC под Windows (вызывает Source\redesign-dev\build.bat)
├── run.bat                 ← запуск с новым интерфейсом
├── run-classic.bat         ← запуск с классическим интерфейсом VLC 4
├── run-debug.bat           ← запуск с подробным логом в build\vlc-log.txt
├── build\                  ← тулчейн, контрибы, дерево сборки (build\win64-native)
│   └── vlc\                ← собранный VLC (vlc.exe)
├── RedesignSources\
│   ├── Figma-Link.txt
│   ├── FigmaExport\        ← PNG + SVG всех фреймов макета (главный источник)
│   ├── Video.mp4, VideoTranscription.txt
├── Source\                 ← git-репозиторий VLC 4 (форк), ветка redesign/stage1
│   ├── CLAUDE.md           ← короткая памятка для Claude Code
│   ├── modules\gui\qt\redesign\   ← новый интерфейс (QML, иконки, провайдер иконок)
│   └── redesign-dev\       ← скрипты сборки (bat, windows\, старый wsl\), BUILD-WINDOWS.md, нарезка иконок, копия этого документа
└── redesign-stage1.patch   ← устарел (всё уже в коммите), можно удалить
```

Корневые `.bat` — это обёртки: настоящие скрипты лежат в `Source\redesign-dev\`
и закоммичены вместе с кодом.

## 0.1. Промпт для нового (локального) чата

Скопируйте в новый чат Claude Code, открытый в `C:\Projects\VLC\Source`:

```
Продолжаем реализацию редизайна VLC. Прочитай C:\Projects\VLC\HANDOFF.md целиком
(и CLAUDE.md в корне репозитория). Сначала выполни шаг «Первые действия» из раздела 7:
пересобери проект через C:\Projects\VLC\build.bat (инструкция: Source\redesign-dev\BUILD-WINDOWS.md),
запусти run-debug.bat с видео и допроверь пункты из «Не проверено».
Потом переходи к этапу 2 (библиотека). Макеты: C:\Projects\VLC\RedesignSources\FigmaExport.
Общайся со мной по-русски.
```

## 1. Задача

Перенести в VLC 4 (этот репозиторий) комьюнити-редизайн:

- Figma: «VLC Redesign (Community)»,
  https://www.figma.com/design/Xb9N9UxYo7xxr7d9ujuxlV/VLC-Redesign--Community-
- Экспорт всех фреймов в PNG и SVG: `C:\Projects\VLC\RedesignSources\FigmaExport\`.
  Figma MCP упирается в лимит бесплатного плана, поэтому работаем по экспорту.
- Видео автора с объяснениями решений: `RedesignSources\Video.mp4`,
  транскрипция: `RedesignSources\VideoTranscription.txt`.
  Транскрипцию стоит прочитать целиком: в ней объяснено, почему элементы стоят там, где стоят.

Пожелание владельца: сохранить всю функциональность VLC, а UI сделать с нуля.

## 2. Принятые решения

1. **UI пишется с нуля на Qt Quick (QML) отдельным модулем `VLC.Redesign`**
   (`modules/gui/qt/redesign/`). Его корень — `RMainInterface.qml`.
   Старый QML не трогаем. Это даёт два преимущества:
   - используется готовый C++-фасад Qt-модуля: `Player` (PlayerController),
     `MainPlaylistController`, ML-модели, `DialogsProvider`, `MainCtx`;
   - используются готовые композиторы видео (DirectComposition на Windows, X11, Wayland).
     Это самая сложная часть, и переписывать её без Qt пришлось бы месяцами.
2. **Включение:** опция `qt-redesign` (bool, по умолчанию `true`) в `qt.cpp`.
   `--no-qt-redesign` возвращает классический интерфейс.
   Корневой QML выбирается в `maininterface/mainui.cpp`.
3. **Контекстное меню видео:** если включён редизайн, `DialogsProvider` вместо нативного
   QMenu испускает сигнал `contextMenuRequested(bool show)`. QML рисует своё меню (`RContextMenu.qml`).
4. **Иконки:** 206 штук нарезаны из `FigmaExport/Icon.svg` скриптом
   `redesign-dev/tools/split_icons.py`. Основной цвет в файлах — `#FF00FF`, акцентный — `#FF8800`.
   Перекрашивает их **синхронный** провайдер `image://redesignicon/<name>?c=<цвет>&a=<акцент>`
   (`redesign/redesign_icon_provider.cpp`).
   Асинхронный `svgcolor` провайдер не использовать: на машинах с малым числом ядер
   он заводит глобальный QThreadPool в дедлок (растеризатор SVG ждёт потоки того же пула),
   и окно остаётся пустым.
5. **Токены дизайна:** `redesign/qml/Theme.qml` — синглтон, имена повторяют переменные Figma
   (`Dark/BG/A3` → `p.bgA3` и т. д.). Размеры задаются в 1x через `Theme.dp()`.
   По умолчанию тема тёмная, светлая включается схемой «Day».
6. **Сборка:** в обеих системах, meson.build и Makefile.am. Под Windows собираем через meson
   (флаг `-m` в `extras/package/win32/build.sh`), этот путь проверен.
7. **Окончания строк:** рабочая копия на Windows была с CRLF (core.autocrlf не был задан),
   из-за этого `git status` показывал тысячи изменённых файлов. Поставлен `core.autocrlf=true`.
   Скрипты сборки в `redesign-dev/` закреплены через `.gitattributes`
   (`*.sh`/`*.py` всегда LF, `*.bat` всегда CRLF).

## 3. Что сделано (этап 1: плеер)

Файлы в `modules/gui/qt/redesign/qml/`:

| Файл | Что это |
|------|---------|
| `RMainInterface.qml` | корень: DropArea, тултипы, глобальные шорткаты, CSD-ресайз |
| `RPlayerView.qml` | экран плеера: видео во всё окно, бары с автоскрытием, панели, меню |
| `RTopBar.qml`, `RWindowButton.qml` | верхняя панель: конус, меню «…», заголовок, кнопки окна |
| `RControlBar.qml` | нижняя панель: prev/play/next, время, `RSeekBar`, громкость `RVolumeCone`, аудио, субтитры, настройки воспроизведения, очередь |
| `RTracksPopup.qml`, `RTrackPage.qml` | попап Video / Audio / Subtitles: дорожки, устройство вывода, «Show Preferences» |
| `RPlaybackPopup.qml` | скорость, задержки субтитров и звука, A-B, снимок, запись, реверс |
| `RQueuePanel.qml`, `RQueueItem.qml` | правая панель Queue / Bookmarks / Chapters |
| `RMainMenu.qml`, `RContextMenu.qml`, `RMenu*.qml`, `RAction.qml` | меню «…» и меню правой кнопки |
| `RIdleView.qml` | экран без видео: обложка для музыки, конус и «Open media» |
| `RIcon`, `RIconButton`, `RText`, `RToolTip`, `RTabBar`, `RSectionHeader`, `RCheckItem`, `RPanelButton`, `RChip`, `RValueSlider`, `RTimeLabel`, `RTrackList` | базовые компоненты |

### Как проверялось

Linux-сборка в облаке (Ubuntu 24.04, Qt 6.4, meson), запуск под Xvfb + openbox
с `QT_QUICK_BACKEND=software --qt-compositor=dummy`, сверка скриншотов с макетом.
Проверены: idle-экран, плеер с аудио, попап субтитров, очередь, меню «…»,
меню правой кнопки, попап воспроизведения, заливка конуса громкости.

2026-10-12: нативная сборка под Windows (см. раздел 4) собрана и запущена с видео
(`RedesignSources\Video.mp4`): верхняя и нижняя панели видны поверх видео, конус громкости залит,
правый клик открывает новое QML-меню, ошибок QML в логе нет.

### Не проверено

- **Громкость с реальным аудиовыходом**: конус заливается (mmdevice), но изменение громкости мышью не проверялось.
- **Автоскрытие баров, попапы дорожек/воспроизведения, очередь** на Windows не прокликивались.
- Меню правой кнопки на Windows открылось у верхнего края окна, а не под курсором (экран с масштабом 150%) — проверить позиционирование.
- **Сборка через autotools** (Makefile.am правился, но не собирался).

### Известные упрощения этапа 1

- «Customize Player» в меню «…» открывает старое окно VLC (этап 5).
- Пункты Video / Audio / Subtitle в меню правой кнопки открывают попап дорожек, а не подменю.
- Кнопка сайдбара библиотеки и «папка» в верхней панели скрыты
  (`RTopBar.libraryAvailable: false`) до этапа 2.
- В экспорте не было иконки «check» по умолчанию, `check.svg` взят из состояния «active».
  `repeat_one`, `trash`, `media`, `playing`, `tab_*` нарисованы или взяты из других фреймов.

## 3.1. Этапы 3 и 4 (2026-10-13): настройки, горячие клавиши, эффекты, диалоги

| Что | Файлы |
|-----|-------|
| Окно настроек: поиск, 13 категорий, «Advanced Options» со всеми прочими опциями области | `RSettingsWindow.qml`, `RSettings<Категория>.qml`, `RSettingsPage`, `ROption`, `RAdvancedOptions`, контролы `RSwitch`, `RDropdown`, `RSegmented`, `RTickSlider`, `RTextField`, `RColorField`, `RAccentPicker`, `RModuleSwitch` |
| Мост к конфигу VLC (описание опций, значения, поиск, горячие клавиши, нативные диалоги выбора) | `redesign/redesign_settings.*` (синглтон `RedesignSettings`) |
| Окно горячих клавиш | `RShortcutsWindow.qml`, `RKeyField.qml` |
| Живые эффекты видео/аудио в попапе дорожек (кнопки внизу попапа) | `RVideoEffects`, `RAudioEffects`, `RCollapsible`, `REffectSlider`, `RFilterSwitch`, `RCropEditor`, `REqualizerBands`; C++: `redesign/redesign_effects.*` (`RedesignEffects`) |
| Диалоги: сетевой поток, новый плейлист, субтитры к папке | `RDialogWindow`, `RNetworkStreamDialog`, `RNewPlaylistDialog`, `RAddSubtitlesDialog`, `RPlaylistSaver` |
| Запросы окон из любого места | синглтон `RWindows.qml`; окна создаёт `RMainInterface` |

- Тема (тёмная/светлая/системная) и акцент хранятся в Qt-настройках (`Redesign/theme`, `Redesign/accent`), см. `Theme.qml`.
- С редизайном `DialogsProvider::prefsDialog()` открывает новое окно; классическое — `classicPrefsDialog()` (Settings > General).
- Для скриншотов: `vlc --qt-redesign-open=settings:<категория>|shortcuts|network|playlist|subtitles:<url>|effects:video|effects:audio`.
- Canvas в Qt из контрибов нет: пунктир рисует `RDashedLine`.
- Новые QML-файлы добавлять в списки командой `python redesign-dev/tools/sync_qml_lists.py`.
- Не сделано: HDR-опции, профили, онбординг, кастомизация панели (этап 5), библиотека (этап 2).

## 4. Сборка и запуск на Windows

**Подробная инструкция: `redesign-dev/BUILD-WINDOWS.md`.** Сборка нативная, без WSL и MSYS2:
WinLibs GCC 14.3 + meson/ninja из Python venv + готовые контрибы CI VideoLAN (job «win64»)
+ хост-утилиты Qt 6.8.3 из официальной сборки. Скрипты: `redesign-dev/windows/`.

1. `setup.bat` (= `windows\setup.ps1`) — один раз, ≈10 минут: тулчейн и контрибы в `C:\Projects\VLC\build`.
2. `build.bat` (= `windows\build.ps1`) — сборка, первая ≈20 минут, потом инкрементальная.
   `-Reconfigure`, `-Clean`, `-Release`, `-Jobs N`. Результат: `C:\Projects\VLC\build\vlc\vlc.exe`.
3. `run.bat [файл]` — запуск с новым UI. `run-classic.bat` — со старым.
   `run-debug.bat` — с подробным логом (ошибки QML пишутся в `C:\Projects\VLC\build\vlc-log.txt`).

Старый путь через WSL остался в `redesign-dev/wsl/` (`setup-wsl.bat`, `build-wsl.bat`).

Быстрая итерация по QML без сборки под Windows: собрать под Linux/WSL нативно
(`meson setup build -Dqt=enabled -Dlua=disabled`, Qt 6 из apt) и запускать `build/bin/vlc`.
Для запуска из дерева сборки нужны `VLC_PLUGIN_PATH` и `VLC_LIB_PATH=<build>/modules`,
а `vlc-qt-check` должен лежать в `PKGLIBEXECDIR`.

## 5. Следующие этапы

| Этап | Что | Источник в FigmaExport |
|------|-----|------------------------|
| 2 | Сайдбар библиотеки (компактный в плеере и полный экран), Home, Videos/Music/Network/Playlists/Recent, музыкальный плеер, миниплеер, сортировка и вид, «unviewed/viewed» | `Player-1..6.png`, `Player - Music*.png`, `Miniplayer.png`, `Sorting Options`, `View Options`, `*context menu` |
| 3 | Окно настроек (13 категорий, 19 экранов, advanced внизу каждой категории), окно горячих клавиш | `Settings - *.png`, `Keyboard Shortcuts.png` |
| 4 | Диалоги: добавить субтитры к файлу/папке/плейлисту, сетевой поток, новый плейлист, сайдбар эффектов (Video/Audio/Subtitles/Playback с пресетами, EQ, таймлайн субтитров) | `Add Subtitles to Playlist/`, `Open network stream.png`, `new playlist.png`, `Audio - *.png`, `Video - *.png`, `EQ*.png`, `Controls.png` |
| 5 | Онбординг, кастомизация панели drag-and-drop, профили | `Onboarding*.png`, `Player - customize*.png`, `Profiles.png` |

Для библиотеки нужен medialibrary. В облачной Linux-сборке его не было (в Ubuntu 24.04 лежит 0.12, а нужен ≥ 0.13).
В Windows-сборке medialibrary приходит с контрибами.

## 6. Полезное про код VLC

- Все QML-модули Qt-плагина перечислены в `modules/gui/qt/meson.build` (`qml_modules`) и в `Makefile.am`.
  Синглтоны помечаются отдельно. Ресурсы модуля инициализируются в `qt.cpp` (`Q_INIT_RESOURCE(redesign_assets)`).
- Иконки лежат в `assets.qrc` под префиксом `/redesign/icons`. Новую иконку нужно добавить туда
  и в `libqt_plugin_la_RES` в `Makefile.am`.
- Свойства плеера для QML: `modules/gui/qt/player/player_controller.hpp` (Q_PROPERTY и public slots).
  Очередь: `playlist/playlist_controller.hpp`, модель строк: `playlist/playlist_model.hpp`
  (роли `title`, `duration`, `isCurrent`, `artwork`).
- Модели дорожек отдают роли `display` и `checked`. Выбор делается через `model.checked = true`,
  снятие — через `setData(index, false, Qt.CheckStateRole)`.
- Все диалоги вызываются через `DialogsProvider.*` (`dialogs/dialogs_provider.hpp`).

## 7. Первые действия для следующего исполнителя

1. `C:\Projects\VLC\setup.bat`, затем `C:\Projects\VLC\build.bat` (на этой машине уже сделано,
   `build.bat` достаточно для инкрементальной пересборки). При проблемах — таблица в `BUILD-WINDOWS.md`.
2. `C:\Projects\VLC\run-debug.bat <видеофайл>` — допроверить пункты из «Не проверено» выше.
3. Ветка `redesign/stage1` ещё ни разу не пушилась: `git push -u origin redesign/stage1`.
4. Переходить к этапу 2 (библиотека).

## 8. История (кратко)

- Исходники: форк `Geckostya/vlc-Juxtopposed-redesign` (master = VLC 4.0-dev, коммит a5538c5).
- Рассматривали отдельное приложение на libVLC (Avalonia/Rust) — отказались, т.к. владелец хочет полную функциональность VLC; выбран новый QML-интерфейс поверх существующего C++-слоя.
- Иконки и макеты сначала брались через Figma MCP, потом упёрлись в лимит Starter-плана; владелец выгрузил FigmaExport — дальше работаем только по нему.
- Этап 1 собран и проверен скриншотами в облачной Linux-сборке; коммит `f559a5de42` + этот документ в следующем коммите.
