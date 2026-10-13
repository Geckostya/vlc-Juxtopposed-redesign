# Редизайн VLC: передача работы

> **Начните отсюда.** Документ описывает всё, чтобы продолжить работу без предыдущей переписки.
> Копии: `C:\Projects\VLC\HANDOFF.md` и `Source\redesign-dev\HANDOFF.md` (в git).
> Состояние на 2026-10-13, ветка `redesign/stage1` запушена в `origin`
> (https://github.com/Geckostya/vlc-Juxtopposed-redesign).

## 0. Где что лежит

```
C:\Projects\VLC\
├── HANDOFF.md              ← этот документ
├── setup.bat               ← разовая установка окружения сборки (нативно, без WSL/MSYS)
├── build.bat               ← сборка (вызывает Source\redesign-dev\build.bat → windows\build.ps1)
├── run.bat                 ← запуск с новым интерфейсом
├── run-classic.bat         ← запуск с классическим интерфейсом VLC 4
├── run-debug.bat           ← запуск с подробным логом в build\vlc-log.txt
├── build\                  ← тулчейн, контрибы, деревья сборки (в git не входит)
│   ├── win64-native\       ← дерево сборки meson (debugoptimized)
│   ├── vlc\                ← собранный VLC (vlc.exe)
│   ├── win64-release\, vlc-release\, dist\   ← release-сборка и zip релиза
├── release-src\            ← снимок коммита, из которого собран релиз 0.1.0 (можно удалить)
├── RedesignSources\
│   ├── Figma-Link.txt
│   ├── FigmaExport\        ← PNG + SVG всех фреймов макета (главный источник)
│   ├── Video.mp4, VideoTranscription.txt
└── Source\                 ← git-репозиторий VLC 4 (форк), ветка redesign/stage1
    ├── CLAUDE.md           ← короткая памятка для Claude Code
    ├── modules\gui\qt\redesign\   ← новый интерфейс: qml\, icons\, C++ мосты
    └── redesign-dev\       ← скрипты сборки (windows\, старый wsl\), BUILD-WINDOWS.md,
                              tools\ (нарезка иконок, sync_qml_lists.py), этот документ
```

## 0.1. Промпт для нового чата

Скопируйте в новый чат Claude Code, открытый в `C:\Projects\VLC\Source`:

```
Продолжаем реализацию редизайна VLC. Прочитай C:\Projects\VLC\HANDOFF.md целиком
(и CLAUDE.md в корне репозитория). Пересобери проект через C:\Projects\VLC\build.bat
(инструкция: Source\redesign-dev\BUILD-WINDOWS.md), затем продолжай с раздела 7
«Следующие шаги». Макеты: C:\Projects\VLC\RedesignSources\FigmaExport.
Общайся со мной по-русски.
```

## 1. Задача

Перенести в VLC 4 (этот репозиторий) комьюнити-редизайн:

- Figma: «VLC Redesign (Community)»,
  https://www.figma.com/design/Xb9N9UxYo7xxr7d9ujuxlV/VLC-Redesign--Community-
- Экспорт всех фреймов в PNG и SVG: `C:\Projects\VLC\RedesignSources\FigmaExport\`
  (Figma MCP упирается в лимит бесплатного плана, работаем по экспорту).
- Видео автора с объяснениями решений: `RedesignSources\Video.mp4`,
  транскрипция `RedesignSources\VideoTranscription.txt` — стоит прочитать целиком.

Пожелание владельца: сохранить всю функциональность VLC, а UI сделать с нуля.
Владелец общается по-русски, проверяет сборки сам на этой машине и присылает списки багов.

## 2. Принятые решения

1. **UI пишется с нуля на Qt Quick (QML) модулем `VLC.Redesign`** (`modules/gui/qt/redesign/qml/`),
   корень — `RMainInterface.qml`. Старый QML не трогаем. Используем готовый C++-фасад Qt-модуля
   (`Player`, `MainPlaylistController`, ML-модели, `DialogsProvider`, `MainCtx`) и готовые
   композиторы видео (DirectComposition на Windows).
2. **Включение:** опция `qt-redesign` (по умолчанию `true`), `--no-qt-redesign` — классический UI.
   Корневой QML выбирается в `maininterface/mainui.cpp`.
3. **Окна и диалоги — отдельные QML `Window`** (настройки, горячие клавиши, диалоги), без рамки ОС,
   со своим заголовком и перетаскиванием. Их создаёт `RMainInterface` по сигналам синглтона
   `RWindows.qml` (`settingsRequested`, `shortcutsRequested`, `networkStreamRequested`,
   `newPlaylistRequested`, `addSubtitlesRequested`, `effectsRequested`).
4. **Перехват классических диалогов:** при редизайне `DialogsProvider::prefsDialog()` испускает
   `redesignSettingsRequested()`; классическое окно — `classicPrefsDialog()`. Контекстное меню видео:
   `DialogsProvider` испускает `contextMenuRequested(bool)`, QML рисует `RContextMenu.qml` в точке
   `MainCtx.cursorPos()` (над видео HoverHandler курсор не видит).
5. **Иконки:** 206 штук нарезаны из `FigmaExport/Icon.svg` (`redesign-dev/tools/split_icons.py`),
   основной цвет `#FF00FF`, акцент `#FF8800`, перекрашивает **синхронный** провайдер
   `image://redesignicon/<name>?c=&a=` (асинхронный `svgcolor` дедлочит QThreadPool).
6. **Токены дизайна:** синглтон `Theme.qml`, имена как в Figma (`p.bgA3` …), размеры через `Theme.dp()`.
   Тема `dark|light|system` и акцент — в Qt-настройках (`Redesign/theme`, `Redesign/accent`).
7. **Мосты C++ для QML** (`redesign/*.cpp`, регистрируются синглтонами в `mainui.cpp`, uri `VLC.MainInterface`):
   - `RedesignSettings` — конфиг VLC: `option(name)` (тип, текст, longtext, значение, choices, min/max),
     `setValue`, `advancedOptions(subcats, exclude)`, `search`, горячие клавиши, нативные пикеры
     файла/папки/цвета/шрифта, `listFiles`, `inheritedString` (значение с учётом командной строки).
   - `RedesignEffects` — живые фильтры видео/аудио (как классический «Effects and Filters»: на
     текущем vout/aout + в конфиг), пресеты эквалайзера, `enqueueWithSubtitles`.
8. **Advanced Options на каждой странице настроек** — все остальные опции «области» (подкатегории
   `vlc_config_subcat`), сгруппированные по модулю. Так ничего из классических «All» не теряется.
9. **Сборка:** нативно под Windows (раздел 4). Списки QML-файлов в `meson.build` и `Makefile.am`
   генерирует `python redesign-dev/tools/sync_qml_lists.py` — запускать после добавления файла.
   Новые QML-файлы получают GPL-заголовок, как остальные.
10. **Подводные камни QML в этой сборке:** нет `Canvas` (пунктир — `RDashedLine`), нет
    `QtQuick.Dialogs` (пикеры через C++), `default property alias` в корне компонента ловит и
    собственных детей файла — в таких компонентах дети объявлены явным списком `data: [...]`.

## 3. Что сделано

### Этап 1: плеер
`RPlayerView` (видео во всё окно, бары с автоскрытием), `RTopBar` (конус, меню «…», заголовок,
кнопки окна; в полноэкранном режиме меню открывает весь левый верхний угол), `RControlBar`
(prev/play/next, время, `RSeekBar`, конус громкости, аудио, субтитры, настройки воспроизведения,
очередь), `RTracksPopup` (дорожки Video/Audio/Subtitles), `RPlaybackPopup` (скорость, задержки,
A-B, снимок, запись, реверс), `RQueuePanel` (Queue/Bookmarks/Chapters), `RMainMenu`, `RContextMenu`,
`RIdleView`, базовые компоненты.

### Этап 3: настройки и горячие клавиши
- `RSettingsWindow` + страницы `RSettings<General|Interface|Privacy|Controls|Playback|Video|Audio|Subtitles|Library|Network|Performance|Recording|Extensions>.qml`,
  поиск по всем опциям (`RSettingsSearchPage`), Advanced Options (`RAdvancedOptions`).
- Строка, привязанная к опции VLC: `ROption { name: "..."; title: qsTr("...") }` — контрол
  выбирается по типу (switch, dropdown, slider, text, path+Browse, color). Опции, которых нет в
  сборке, прячутся сами.
- Контролы: `RSwitch`, `RDropdown` (с иконками у пунктов), `RSegmented`, `RTickSlider`, `RTextField`,
  `RColorField`, `RAccentPicker`, `RModuleSwitch` (модуль в списке вроде `audio-filter`/`extraintf`),
  `RButton`, `RSettingRow` (подпись + «i» с описанием).
- `RShortcutsWindow` + `RKeyField`: поиск, обычные и глобальные клавиши, снятие конфликтов,
  Save/Cancel (применяется после перезапуска VLC).

### Этап 4: эффекты и диалоги
- Эффекты — внизу попапа дорожек («Video effects» / «Audio effects and equalizer»), также из
  попапа воспроизведения: `RVideoEffects` (картинка, резкость, бандинг, зерно, цвета, поворот,
  кадрирование `RCropEditor`), `RAudioEffects` (эквалайзер `REqualizerBands` с пресетами,
  компрессор, спатиалайзер, стерео-расширение, высота тона, прочие фильтры), `RCollapsible`,
  `REffectSlider`, `RFilterSwitch`.
- Диалоги (`RDialogWindow` — общая рамка): `RNetworkStreamDialog` (несколько URL, плейлист в
  медиатеке), `RNewPlaylistDialog` (drag-and-drop), `RAddSubtitlesDialog` (пары видео ↔ субтитры
  по имени или S01E05, «Play with subtitles»), `RPlaylistSaver` (грузится Loader'ом: модуль
  `VLC.MediaLibrary` есть только с медиатекой).

### Этап 2: библиотека и миниплеер
- `RLibraryView` (сайдбар `RLibrarySidebar`, шапка `RLibraryHeader`: назад/вперёд, хлебные крошки,
  сортировка, сетка/список, поиск, меню), маршрут `{page, title, params, crumbs}` и своя история.
- Страницы: `RLibHomePage` (Continue Watching, Play Again, New Music, Video Folders),
  `RLibVideosPage` (папки → видео, «All videos»), `RLibMusicPage` (альбомы/артисты/треки/жанры),
  `RLibNetworkPage` (компьютер, устройства, сеть → папки), `RLibPlaylistsPage`, `RLibRecentPage`.
- `RMediaView` — общая сетка плиток 16:9 (или квадратных) с прогрессом / компактный список;
  `RMediaMenu` — ПКМ (воспроизвести, в очередь, отметить просмотренным).
- Вход: кнопка сайдбара и «папка» в верхней панели плеера. В библиотеке играющее видео
  показывает миниплеер `RMiniPlayer`: сам `RPlayerView` переносится в прямоугольник карточки
  (`mini: true`), клик по видео возвращает в плеер.
- Модули медиатеки грузятся только при включённой медиатеке (`RLibraryFolders`, `RLibraryRescan`
  и страницы через Loader); без неё работает только Network.
- `--qt-redesign-open=library:<page>` открывает библиотеку при старте.
- Не сделано по макетам: вложенные папки (медиатека отдаёт плоский список папок), музыкальный
  плеер `Player - Music`, «Sorting/View Options» как отдельные попапы, полноэкранный сайдбар.

### Этап 5 (часть): онбординг и кастомизация
- `ROnboarding` — при первом запуске редизайна (флаг `Redesign/onboardingDone` в Qt-настройках):
  приветствие и папка медиатеки, тема и акцент, основные клавиши (из конфига горячих клавиш).
- `RCustomizeDialog` («Customize Player» в меню «…»): перетаскивание контролов из коробки в
  полосу панели, перестановка, удаление перетаскиванием обратно. Список хранится в
  `Redesign/controlbarExtras` (синглтон `RBarCatalog`), контролы рисует `RBarItem` в `RControlBar`
  между громкостью и кнопкой аудио.
- Хуки: `--qt-redesign-open=onboarding|customize|extras:id1,id2` (последний — без сохранения).
- Qt-настройки на Windows лежат в `%APPDATA%\vlc\vlc-qt-interface.ini` (путь берётся из
  `config_GetUserDir`, подмена `APPDATA` для теста не помогает).
- Не сделано: профили (меню «Profile» с наборами настроек), верхняя панель в кастомизации.

### Сборка, релиз
- Нативная сборка под Windows, раздел 4.
- **Релиз vlc-redesign-0.1.0 (Windows x64) опубликован** владельцем:
  https://github.com/Geckostya/vlc-Juxtopposed-redesign/releases/tag/vlc-redesign-0.1.0
  (собран из коммита `8c99ab68f2` — только этап 1).
  **Релиз 0.2.0 опубликован** (2026-10-13, коммит `59d52482b9`: этапы 1–5 без профилей):
  https://github.com/Geckostya/vlc-Juxtopposed-redesign/releases/tag/vlc-redesign-0.2.0
  (сборка из снимка `git archive HEAD` в `C:\Projects\VLC\release-src`, чтобы не брать
  незакоммиченное; `build.ps1 -Release -Clean` оттуда, затем `package.ps1 -Version X -Commit <hash>`). Следующий релиз: `build.bat -Release`,
  затем `redesign-dev\windows\package.ps1 -Version 0.2.0`, черновик через `gh release create --draft`;
  публикует владелец.

### Проверено вживую (Windows, 2026-10-12/13)
Видео с панелями поверх, конус громкости, меню ПКМ под курсором (подтвердил владелец), все
13 страниц настроек и их Advanced Options, окно горячих клавиш, три диалога, панели эффектов,
полноэкранное меню. Проверка — скриншотами через `PrintWindow` и опцию `--qt-redesign-open`.

### Не проверено / известные упрощения
- Управление громкостью мышью, автоскрытие баров при обычном использовании — проверяет владелец.
- Живые эффекты проверены только на открытие панелей, не на слух/глаз.
- Пункты Video/Audio/Subtitle в ПКМ открывают
  попап дорожек, а не подменю.
- HDR-опции и профили не сделаны.
- Сборка через autotools не проверялась (Makefile.am поддерживается).

## 4. Сборка и запуск на Windows

**Подробно: `redesign-dev/BUILD-WINDOWS.md`.** WinLibs GCC 14.3 + meson/ninja из Python venv +
готовые контрибы CI VideoLAN (job «win64») + хост-утилиты Qt 6.8.3. Скрипты: `redesign-dev/windows/`.

1. `setup.bat` — один раз (~10 мин): всё в `C:\Projects\VLC\build`.
2. `build.bat` — сборка (первая ~20 мин, потом инкрементальная). Флаги: `-Reconfigure` (после
   добавления QML-файлов — обязательно, qrc генерируется при конфигурации), `-Clean`, `-Release`.
   Перед сборкой закройте VLC, иначе установка упадёт (файлы заняты).
3. `run.bat [файл]`, `run-classic.bat`, `run-debug.bat` (лог `build\vlc-log.txt`).

Отладка падений: `build\toolchain\mingw64\bin\gdb.exe -batch -ex run -ex bt --args build\vlc\vlc.exe ...`

Открыть окно редизайна при старте (для скриншотов и тестов):
`vlc --qt-redesign-open=settings[:категория[:advanced]]|shortcuts|network|playlist|subtitles:<url>|effects:video|effects:audio`
(`--qt-pin-controls` держит панели видимыми).

## 5. Полезное про код VLC

- QML-модули Qt-плагина: `modules/gui/qt/meson.build` (`qml_modules`) и `Makefile.am`.
- Иконки: `assets.qrc` под `/redesign/icons` + `libqt_plugin_la_RES` в `Makefile.am`.
- Плеер для QML: `player/player_controller.hpp`; очередь: `playlist/playlist_controller.hpp`
  (`prev()` — предыдущий файл, `prevOrReset()` — перемотка в начало); модель строк
  `playlist/playlist_model.hpp`.
- Дорожки: роли `display`, `checked`; выбор `model.checked = true`.
- Медиатека в QML: модуль `VLC.MediaLibrary` (`MediaLib`, `MLPlaylistListModel.create(name, urls)`,
  `MLRecentMediaModel` и др.), регистрируется только если медиатека включена.
- Подкатегории конфига: `include/vlc_plugin.h` (`SUBCAT_*`); у некоторых нет имени —
  `vlc_config_subcat_GetName()` тогда падает, используйте `vlc_config_subcat_Find()`.
- `config_GetType()` возвращает `VLC_VAR_*`, а не `CONFIG_ITEM_*`.

## 6. История (кратко)

- Исходники: форк `Geckostya/vlc-Juxtopposed-redesign` (master = VLC 4.0-dev, коммит a5538c5).
- Отказались от отдельного приложения на libVLC — нужна полная функциональность VLC.
- Этап 1 сделан и проверен в облачной Linux-сборке; затем нативная сборка под Windows,
  релиз 0.1.0, этапы 3 и 4, раунд исправлений по отзывам владельца (краш Advanced Options,
  эквалайзер в попапе, меню «…» в полноэкранном режиме, ПКМ → новые настройки, «Предыдущий»).

## 6.1. В работе (2026-10-13, последняя сессия с ограниченным лимитом)

План на остаток лимита, по порядку. Если сессия оборвалась, всё, что не отмечено [x],
не сделано (проверьте `git log` ветки `redesign/stage1`):

- [ ] «Open Recent» — подменю в меню «…» (Figma `Profiles.png`): последние 10 медиа
      (`MLRecentMediaModel`, только при медиатеке), пункт «Clear».
- [ ] Профили — подменю «Profile (<имя>)» в меню «…» (Figma `Profiles.png`): Movies / Shows /
      Music / Work + «New». Профиль = снимок настроек редизайна из Qt-настроек (тема, акцент,
      `controlbarExtras`) в группе `Redesign/profiles/<имя>`; переключение применяет снимок,
      текущий сохраняется перед переключением. Опции VLC (vlcrc) профиль пока не трогает.
- [ ] Обновить этот документ и запушить.

## 7. Следующие шаги

| Этап | Что | Источник в FigmaExport |
|------|-----|------------------------|
| 2+ | Остатки библиотеки: музыкальный плеер, попапы сортировки и вида, контекстные меню плейлистов/папок по макету, отдельный миниплеер-окно | `Player - Music*.png`, `Miniplayer.png`, `Sorting Options`, `View Options`, `*context menu.png` |
| 5+ | Профили, кастомизация верхней панели, сверка светлой темы с `Player - Light`, «hide UI» | `Profiles.png`, `Player - customize-1..8.png`, `Player - Light.png`, `Player - hide UI.png` |
| 4+ | Остатки эффектов: HDR-опции, пресеты настроек («Setting Preset»), визуализатор, таймлайн субтитров | `HDR Options.png`, `Setting Preset.png`, `Audio Visualizer.png`, `sub filename.png`, `subtitle one/multiple.png` |

Медиатека в Windows-сборке есть (приходит с контрибами).
