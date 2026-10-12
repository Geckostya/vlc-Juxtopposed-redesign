#!/bin/bash
# Installs everything the Windows cross build of VLC needs inside WSL (Ubuntu 24.04).
# Same tool set as the official VideoLAN docker image (vlc-debian-win64-posix).
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -qqy \
    git wget bzip2 file unzip libtool libtool-bin libltdl-dev pkg-config ant \
    build-essential automake texinfo yasm p7zip-full autopoint \
    gettext cmake zip nsis curl gperf flex bison \
    libcurl4-gnutls-dev python3 python3-setuptools python3-mako python3-requests python3-venv python3-pip \
    gcc make procps ca-certificates nasm jq gnupg autoconf ninja-build zstd rsync \
    gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix mingw-w64-tools

# use the posix threading flavour of mingw-w64 (needed by the prebuilt contribs)
update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix
update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# VLC 4 requires a recent meson
if ! meson --version 2>/dev/null | grep -qE '^1\.(1[0-9]|[2-9][0-9])'; then
    python3 -m venv /opt/meson-venv
    /opt/meson-venv/bin/pip install -q 'meson>=1.10'
    ln -sf /opt/meson-venv/bin/meson /usr/local/bin/meson
fi

git config --global --add safe.directory "*"

echo
echo "WSL build environment is ready."
