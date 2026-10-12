# Сборка и запуск VLC на Windows (нативно, без WSL и MSYS2)

Сборка идёт прямо в Windows: компилятор MinGW-w64 GCC (WinLibs), meson + ninja из Python,
готовые библиотеки-зависимости (контрибы) с CI VideoLAN. Linux-слой не нужен.

Пути ниже даны для раскладки `C:\Projects\VLC\Source` (репозиторий). Всё, что скачивается
и собирается, лежит рядом, в `C:\Projects\VLC\build`, и в git не попадает.

## Что нужно заранее

| Что | Проверка | Где взять |
|-----|----------|-----------|
| Python 3.10+ в `PATH` | `python --version` | https://www.python.org/downloads/ (галка «Add python.exe to PATH») |
| Git в `PATH` | `git --version` | https://git-scm.com/download/win |
| ~12 ГБ на диске | | |
| Интернет на первом шаге | | GitHub, download.qt.io, artifacts.videolan.org |

Visual Studio, WSL, MSYS2, Cygwin не нужны.

## 1. Разовая подготовка (≈10 минут)

PowerShell:

```powershell
cd C:\Projects\VLC\Source
powershell -ExecutionPolicy Bypass -File redesign-dev\windows\setup.ps1
```

или cmd / двойной клик: `C:\Projects\VLC\setup.bat`.

Скрипт ставит в `C:\Projects\VLC\build`:

| Папка | Содержимое |
|-------|------------|
| `pyenv\` | Python venv: meson, ninja, pkgconf, aqtinstall |
| `toolchain\mingw64\` | WinLibs GCC 14.3 (posix threads, msvcrt): тот же ABI, что у контрибов CI (GCC 14 posix) |
| `toolchain\winflexbison\` | нативные flex и bison (нужны JSON-парсеру внешнего препарсера) |
| `toolchain\qt\6.8.3\mingw_64\` | официальный Qt 6.8.3; из него берутся только хост-утилиты `moc`, `rcc`, `uic`, `qsb`, `qmake` |
| `toolchain\static-runtime\` | статические `libwinpthread.a` и `libssp.a`, чтобы VLC не зависел от DLL рантайма GCC |
| `contrib\x86_64-w64-mingw32\` | готовые контрибы (ffmpeg, Qt 6.8.3 static и т. д.) из job «win64» CI VideoLAN, ровно под текущий коммит |
| `native.ini` | machine-файл meson с путями к компилятору и утилитам |

Скрипт можно запускать повторно: скачанное не скачивается заново.
`setup.ps1 -Force` скачивает и распаковывает всё заново.
Если в ветке поменяются `contrib/`, `extras/tools/`, `extras/ci/` или `extras/package/win32/`,
скрипт сам скачает контрибы под новый коммит.

## 2. Сборка

```powershell
cd C:\Projects\VLC\Source
powershell -ExecutionPolicy Bypass -File redesign-dev\windows\build.ps1
```

или `C:\Projects\VLC\build.bat`.

- Первый раз: конфигурация meson и полная компиляция (≈2300 целей, на 16 потоках около 20–30 минут).
- Дальше сборка инкрементальная: пересобирается только изменённое (правка QML — секунды).
- Результат: `C:\Projects\VLC\build\vlc\vlc.exe` (+ `plugins\`, `libvlc.dll`, `libvlccore.dll`, lua, кэш плагинов).
- Дерево сборки meson: `C:\Projects\VLC\build\win64-native`.

Параметры `build.ps1`:

| Параметр | Что делает |
|----------|-----------|
| `-Reconfigure` | перезапустить `meson setup` в том же дереве (после обновления контрибов или опций), собранное не теряется |
| `-Clean` | удалить дерево сборки и собрать всё с нуля |
| `-Release` | сборка `release` вместо `debugoptimized` |
| `-Jobs N` | число параллельных задач (по умолчанию все ядра) |

Из cmd параметры передаются так же: `build.bat -Reconfigure`.

Ручной вызов meson (если нужен), в PowerShell:

```powershell
$B = 'C:\Projects\VLC\build'
$env:PATH = "$B\toolchain\mingw64\bin;$B\pyenv\Scripts;$B\contrib\x86_64-w64-mingw32\bin;$env:PATH"
meson compile -C $B\win64-native
meson install -C $B\win64-native --no-rebuild
```

## 3. Запуск

| Команда | Что |
|---------|-----|
| `C:\Projects\VLC\run.bat [файл]` | новый интерфейс (редизайн) |
| `C:\Projects\VLC\run-classic.bat [файл]` | классический интерфейс VLC 4 |
| `C:\Projects\VLC\run-debug.bat [файл]` | новый интерфейс, подробный лог в `C:\Projects\VLC\build\vlc-log.txt` (ошибки QML тоже) |

Напрямую из PowerShell:

```powershell
& C:\Projects\VLC\build\vlc\vlc.exe --qt-redesign "D:\Videos\movie.mkv"
& C:\Projects\VLC\build\vlc\vlc.exe --no-qt-redesign
& C:\Projects\VLC\build\vlc\vlc.exe -vv --qt-verbose --file-logging --logfile=C:\Projects\VLC\build\vlc-log.txt
```

## Как это устроено (если что-то сломается)

- Контрибы CI собраны в Linux под кросс-компиляцию. `windows\prepare_contrib.py` подменяет плейсхолдер
  `@@CONTRIB_PREFIX@@` на локальный путь (как `contrib/src/change_prefix.sh`).
- Вместо shell-обёртки `contrib\...\bin\qmake6` собирается крошечный `qmake6.exe`
  (`windows\qmake6-wrapper.c`): он запускает нативный `qmake.exe` из Qt 6.8.3 с `target_qt.conf`.
  Через него meson находит статический Qt из контрибов, а `moc`/`rcc`/`qsb` берутся из официального Qt той же версии.
  Версия Qt в `setup.ps1` (`$QtVersion`) должна совпадать с `QTBASE_VERSION` в `contrib/src/main.mak`.
- Рантайм GCC линкуется статически (`-static-libgcc -static-libstdc++` + статические winpthread и ssp).
  Иначе плагины не грузятся: `vlc.exe` разрешает поиск DLL только в System32
  (`SetDefaultDllDirectories` в `bin/winvlc.c`), так что класть `libstdc++-6.dll` рядом бесполезно.
  По той же причине в копии WinLibs `libgcc_s.a` (импорт-библиотека `libgcc_s_seh-1.dll`) заменена
  статическим `libgcc_eh.a`; оригинал сохранён как `libgcc_s.a.dll-import`.
- Из `.pc`-файлов контрибов убираются `-lssp` и `-lgcc_s` (та же причина, плюс двойное определение `__stack_chk_fail`).
- Инсталляторы (MSI/NSIS) отключены: им нужны `cygpath` и `wine`.
- После установки `build.ps1` запускает `vlc-cache-gen.exe` (кэш плагинов `plugins\plugins.dat`).
- Правки исходников, без которых нативная сборка не работала (на Linux они ничего не меняют):
  - `modules/lua/meson.build`: пути нормализуются на `/`, на Windows `full_path()` возвращает обратные слэши;
  - `modules/gui/qt/scripts/genqrc.py`, `genqmldir.py`: префиксы ресурсов QML всегда через `/`
    (иначе в `qmldir` попадал `:/qt/qml\VLC\Widgets/`, и QML не находил свои типы).
- Не собираются (нет утилит): переводы (`msgfmt`) и Chromecast (`protoc`). Для редизайна это не важно.

## Частые проблемы

| Симптом | Что делать |
|---------|-----------|
| `meson setup failed` после обновления ветки | `build.ps1 -Reconfigure` |
| ошибки линковки с контрибами после смены коммита | `setup.ps1` (скачает контрибы под новый коммит), затем `build.ps1 -Reconfigure`; если не помогло, `build.ps1 -Clean` |
| «running scripts is disabled on this system» | запускать через `powershell -ExecutionPolicy Bypass -File ...` или `.bat`-обёртки |
| «VLC media player could not start» | какой-то плагин не грузится: `vlc.exe -vv` покажет `cannot load plug-in ... (error 126)`. Проверить импорты: `build\toolchain\mingw64\bin\objdump.exe -p <dll>`, в списке `DLL Name` не должно быть `libgcc_s`, `libstdc++`, `libwinpthread` |
| в логе `interface "default" initialization failed` | не собрался `plugins\misc\libpreparserserializer_json_plugin.dll` (нет flex/bison): `setup.ps1`, затем `build.ps1 -Reconfigure` |
| окно пустое / ошибки QML | `run-debug.bat`, смотреть `build\vlc-log.txt`, строки `qrc:/qt/qml/VLC/Redesign/...` |

## Старый путь через WSL

Скрипты кросс-сборки в WSL (Ubuntu 24.04) остались в `redesign-dev\wsl\` (`setup-wsl.bat`, `build-wsl.bat`),
но основной путь теперь нативный.
