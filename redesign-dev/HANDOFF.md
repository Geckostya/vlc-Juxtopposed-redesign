# Редизайн VLC: передача работы

Документ для следующего исполнителя (человека или локального чата Claude).
В нём всё, что нужно, чтобы продолжить без предыдущей переписки.

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

### Не проверено

- **UI поверх видео.** В headless X11 без композитора окон видео перекрывает интерфейс
  (классический UI ведёт себя там так же). Первое, что нужно сделать на Windows:
  запустить с видео и проверить, что бары и попапы видны поверх него.
- **Сборка под Windows** (`redesign-dev/build.bat`) ни разу не доведена до конца.
  Проверку в облаке остановила сеть песочницы: прокси вернул 403 на загрузку ninja с GitHub.
  Сам скрипт до этого шага отработал (sync исходников, extras/tools).
- **Громкость с реальным аудиовыходом.** Тестовый вывод отдаёт `volume = -1`.
- **Сборка через autotools** (Makefile.am правился, но не собирался).

### Известные упрощения этапа 1

- «Keyboard Shortcuts» и «Customize Player» в меню «…» открывают старые окна VLC.
- Пункты Video / Audio / Subtitle в меню правой кнопки открывают попап дорожек, а не подменю.
- Кнопка сайдбара библиотеки и «папка» в верхней панели скрыты
  (`RTopBar.libraryAvailable: false`) до этапа 2.
- В экспорте не было иконки «check» по умолчанию, `check.svg` взят из состояния «active».
  `repeat_one`, `trash`, `media`, `playing`, `tab_*` нарисованы или взяты из других фреймов.

## 4. Сборка и запуск на Windows

Всё лежит в `redesign-dev/`. Сборка идёт в WSL (Ubuntu 24.04) кросс-компиляцией mingw-w64,
как в официальном CI VideoLAN, с готовыми (prebuilt) контрибами.

1. `setup.bat` — один раз: ставит WSL и Ubuntu 24.04, затем зависимости (`wsl/setup-deps.sh`).
2. `build.bat` — сборка. Первый запуск идёт 1–2 часа: tools, prebuilt-контрибы,
   хост-инструменты Qt, configure. Потом сборка инкрементальная.
   `build.bat --full` — пересобрать с нуля, `build.bat --release` — релизная сборка.
   - Исходники копируются в `~/vlc-src` внутри WSL (`wsl/sync-sources.py`, с CRLF→LF).
     Файл перезаписывается, только если изменилось его содержимое, поэтому сборка остаётся инкрементальной.
   - Результат: `C:\Projects\VLC\build\vlc\vlc.exe`.
3. `run.bat [файл]` — запуск с новым UI. `run-classic.bat` — со старым.
   `run-debug.bat` — с подробным логом (ошибки QML пишутся в `C:\Projects\VLC\build\vlc-log.txt`).

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
