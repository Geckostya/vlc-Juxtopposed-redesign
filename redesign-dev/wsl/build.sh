#!/bin/bash
# Builds VLC for Windows (x86_64) inside WSL and installs it into <repo>\..\build\vlc
#   build.sh            incremental build (full build the first time)
#   build.sh --full     rerun contribs + bootstrap + configure
#   build.sh --release  release build (always a full build)
set -e

REPO=$(cd "$(dirname "$0")/../.." && pwd)
SRC_WIN=$REPO
SRC=$HOME/vlc-src
OUT=$(dirname "$REPO")/build/vlc
JOBS=${JOBS:-$(nproc)}

FULL=""
RELEASE=""
for a in "$@"; do
    case "$a" in
        --full) FULL=1 ;;
        --release) RELEASE=-r; FULL=1 ;;
    esac
done

echo "== Syncing sources from $SRC_WIN"
mkdir -p "$SRC"
python3 "$(dirname "$0")/sync-sources.py" "$SRC_WIN" "$SRC"
# the build system reads the version from git when available
[ -d "$SRC/.git" ] || git -C "$SRC" init -q

cd "$SRC"
mkdir -p "$OUT"

# meson build: the redesign is developed and tested with it
if [ -z "$FULL" ] && [ -f win64-meson/build.ninja ]; then
    echo "== Incremental build"
    export PATH="$SRC/extras/tools/build/bin:$PATH"
    meson compile -C win64-meson -j "$JOBS"
    meson install -C win64-meson --strip --no-rebuild
else
    echo "== Full build (tools, prebuilt contribs, Qt host tools, configure, compile)"
    JOBS=$JOBS ./extras/package/win32/build.sh -a x86_64 -p -m $RELEASE -o "$OUT"
fi

echo
echo "== Done: $(wslpath -w "$OUT")\\vlc.exe"
