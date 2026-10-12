#!/usr/bin/env python3
"""Prepares the prebuilt VideoLAN contribs for a native Windows build (no WSL, no MSYS).

  prepare_contrib.py --tarball <vlc-contrib-*.tar.zst> --build <build dir> --gcc <mingw64 dir> --qt <host Qt dir>

* extracts the tarball into <build>/contrib/x86_64-w64-mingw32 (symlinks become copies),
* replaces the @@CONTRIB_PREFIX@@ placeholder like contrib/src/change_prefix.sh does,
* replaces the shell qmake wrappers with qmake6.exe (qmake6-wrapper.c) that runs the native
  host qmake (Qt host tools from the official Qt build of the same version) with target_qt.conf,
* writes <build>/native.ini, the meson machine file for the build.
"""

import argparse
import os
import shutil
import subprocess
import tarfile

import zstandard

HOST = 'x86_64-w64-mingw32'
PLACEHOLDER = b'@@CONTRIB_PREFIX@@'
BINARY_EXT = {'.a', '.lib', '.dll', '.exe', '.o', '.obj', '.png', '.jpg', '.sofa', '.ttf', '.otf', '.zip', '.pdb'}

# same flags as extras/package/win32/build.sh for a msvcrt gcc build
CPPFLAGS = ['-D__MSVCRT_VERSION__=0x700', '-D_WIN32_WINNT=0x0601', '-DWINVER=0x0601']


def fwd(path):
    return os.path.abspath(path).replace('\\', '/')


def extract(tarball, dest):
    os.makedirs(dest, exist_ok=True)
    links = []
    with open(tarball, 'rb') as f:
        reader = zstandard.ZstdDecompressor().stream_reader(f)
        with tarfile.open(fileobj=reader, mode='r|') as tar:
            for member in tar:
                if member.issym() or member.islnk():
                    links.append(member)
                    continue
                tar.extract(member, dest, filter='data')
    # Windows has no reliable symlinks without admin rights: copy the targets instead
    for link in links:
        path = os.path.join(dest, link.name)
        if link.issym():
            target = os.path.join(os.path.dirname(path), link.linkname)
        else:
            target = os.path.join(dest, link.linkname)
        if os.path.isfile(target):
            shutil.copyfile(target, path)


def change_prefix(prefix):
    new = fwd(prefix).encode()
    count = 0
    for root, _, files in os.walk(prefix):
        for name in files:
            if os.path.splitext(name)[1].lower() in BINARY_EXT:
                continue
            path = os.path.join(root, name)
            with open(path, 'rb') as f:
                data = f.read()
            if name.endswith('.pc') and (b' -lssp' in data or b' -lgcc_s' in data):
                # -lssp: VLC already links libssp; with --prefer-static meson would add libssp.a
                # next to the import library and the link fails with duplicate symbols.
                # -lgcc_s (x265, srt, libgme): meson resolves it to the import library of
                # libgcc_s_seh-1.dll, which vlc.exe cannot load; -static-libgcc covers it.
                data = data.replace(b' -lssp', b'').replace(b' -lgcc_s', b'')
                if PLACEHOLDER not in data:
                    with open(path, 'wb') as f:
                        f.write(data)
            if PLACEHOLDER in data:
                with open(path, 'wb') as f:
                    f.write(data.replace(PLACEHOLDER, new))
                count += 1
    print(f'prefix replaced in {count} files')


def setup_qmake(prefix, qt):
    bindir = os.path.join(prefix, 'bin')
    # the shell wrappers point to /opt/tools/bin/qmake6 in the CI image
    for name in ('qmake', 'qmake6'):
        p = os.path.join(bindir, name)
        if os.path.exists(p):
            os.remove(p)
    with open(os.path.join(bindir, 'target_qt.conf'), 'w', newline='\n') as f:
        f.write(f'''[Paths]
Prefix={fwd(prefix)}
Documentation=doc
Headers=include
Libraries=lib
LibraryExecutables=bin
Binaries=bin
Plugins=plugins
QmlImports=qml
ArchData=.
Data=.
Translations=translations
Examples=examples
Tests=tests
Settings=etc/xdg
HostPrefix={fwd(qt)}
HostBinaries=bin
HostLibraries=lib
HostLibraryExecutables=bin
HostData={fwd(prefix)}
Sysroot=
SysrootifyPrefix=false
TargetSpec=win32-g++
HostSpec=win32-g++
''')

def build_qmake_wrapper(prefix, qt, gcc):
    qmake = fwd(os.path.join(qt, 'bin', 'qmake.exe'))
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'qmake6-wrapper.c')
    out = os.path.join(prefix, 'bin', 'qmake6.exe')
    subprocess.run([os.path.join(gcc, 'bin', 'gcc.exe'), '-O2', '-municode', '-static',
                    f'-DHOST_QMAKE="{qmake}"', src, '-o', out], check=True)


def write_machine_file(build, prefix, gcc):
    gbin = os.path.join(gcc, 'bin')
    pyscripts = os.path.dirname(shutil.which('meson') or os.path.join(build, 'pyenv', 'Scripts', 'meson.exe'))
    binaries = {
        'c': fwd(os.path.join(gbin, 'gcc.exe')),
        'cpp': fwd(os.path.join(gbin, 'g++.exe')),
        'ar': fwd(os.path.join(gbin, 'gcc-ar.exe')),
        'ranlib': fwd(os.path.join(gbin, 'gcc-ranlib.exe')),
        'strip': fwd(os.path.join(gbin, 'strip.exe')),
        'windres': fwd(os.path.join(gbin, 'windres.exe')),
        'pkg-config': fwd(os.path.join(pyscripts, 'pkg-config.exe')),
        'qmake6': fwd(os.path.join(prefix, 'bin', 'qmake6.exe')),
        'luac': fwd(os.path.join(prefix, 'bin', 'luac.exe')),
        'flex': fwd(os.path.join(build, 'toolchain', 'winflexbison', 'win_flex.exe')),
        'bison': fwd(os.path.join(build, 'toolchain', 'winflexbison', 'win_bison.exe')),
    }
    flags = ', '.join(f"'{x}'" for x in CPPFLAGS + ['-g'])
    ldflags = ', '.join(f"'{x}'" for x in static_runtime_ldflags(build, gcc))
    with open(os.path.join(build, 'native.ini'), 'w', newline='\n') as f:
        f.write('# Generated by redesign-dev/windows/prepare_contrib.py\n\n[binaries]\n')
        for k, v in binaries.items():
            f.write(f"{k} = '{v}'\n")
        f.write(f"\n[built-in options]\nc_args = [{flags}]\ncpp_args = [{flags}]\n")
        f.write(f"c_link_args = [{ldflags}]\ncpp_link_args = [{ldflags}]\n")


def static_runtime_ldflags(build, gcc):
    """Link the GCC runtime statically.

    vlc.exe restricts the DLL search to System32 (SetDefaultDllDirectories in bin/winvlc.c),
    so the plugins cannot load libstdc++-6.dll, libgcc_s_seh-1.dll, libwinpthread-1.dll or
    libssp-0.dll from the VLC folder. -static-libgcc/-static-libstdc++ cover the first two;
    for winpthread and ssp a directory holding only the static archives is searched first,
    so -lpthread/-lwinpthread/-lssp never pick the .dll.a import libraries."""
    libdir = os.path.join(build, 'toolchain', 'static-runtime')
    os.makedirs(libdir, exist_ok=True)
    gcclib = os.path.join(gcc, 'lib', 'gcc', 'x86_64-w64-mingw32')
    gcclib = os.path.join(gcclib, next(d for d in sorted(os.listdir(gcclib), reverse=True)
                                       if os.path.exists(os.path.join(gcclib, d, 'libssp.a'))))
    mingwlib = os.path.join(gcc, 'x86_64-w64-mingw32', 'lib')
    for src, dst in ((os.path.join(mingwlib, 'libwinpthread.a'), 'libwinpthread.a'),
                     (os.path.join(mingwlib, 'libwinpthread.a'), 'libpthread.a'),
                     (os.path.join(gcclib, 'libssp.a'), 'libssp.a'),
                     (os.path.join(gcclib, 'libssp_nonshared.a'), 'libssp_nonshared.a')):
        shutil.copyfile(src, os.path.join(libdir, dst))
    # meson adds g++'s implicit libraries (-lgcc_s) when a C plugin links a C++ contrib
    # (x265, srt, libgme) and resolves them to absolute paths inside the toolchain, so the
    # import library of libgcc_s_seh-1.dll there is replaced by the static unwinder.
    gcc_s = os.path.join(mingwlib, 'libgcc_s.a')
    if not os.path.exists(gcc_s + '.dll-import'):
        shutil.move(gcc_s, gcc_s + '.dll-import')
        shutil.copyfile(os.path.join(gcclib, 'libgcc_eh.a'), gcc_s)
    return ['-L' + fwd(libdir), '-static-libgcc', '-static-libstdc++']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tarball')
    ap.add_argument('--build', required=True)
    ap.add_argument('--gcc', required=True)
    ap.add_argument('--qt', required=True)
    args = ap.parse_args()

    prefix = os.path.join(args.build, 'contrib', HOST)
    if args.tarball:
        if os.path.exists(prefix):
            shutil.rmtree(prefix)
        print(f'extracting {args.tarball}')
        extract(args.tarball, os.path.join(args.build, 'contrib'))
        change_prefix(prefix)
        setup_qmake(prefix, args.qt)
    build_qmake_wrapper(prefix, args.qt, args.gcc)
    write_machine_file(args.build, prefix, args.gcc)
    print('contribs ready in', prefix)


if __name__ == '__main__':
    main()
