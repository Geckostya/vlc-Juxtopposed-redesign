/* qmake6.exe for the prebuilt contribs on a native Windows build.
 *
 * Same job as the contrib/bin/qmake6 shell wrapper of the cross build: runs the host qmake
 * (HOST_QMAKE, set at compile time) with "-qtconf <this dir>\target_qt.conf" and the
 * arguments word-split like the unquoted $* of the shell wrapper (meson passes
 * "-query QT_INSTALL_BINS" as a single argument). */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#ifndef HOST_QMAKE
# error define HOST_QMAKE
#endif
#define WIDEN2(x) L ## x
#define WIDEN(x) WIDEN2(x)

static void append(wchar_t *cmd, size_t size, const wchar_t *tok, size_t len)
{
    wcsncat(cmd, L" \"", size - wcslen(cmd) - 1);
    wcsncat(cmd, tok, len < size - wcslen(cmd) - 1 ? len : size - wcslen(cmd) - 1);
    wcsncat(cmd, L"\"", size - wcslen(cmd) - 1);
}

int wmain(int argc, wchar_t **argv)
{
    static wchar_t self[MAX_PATH], cmd[32768];
    GetModuleFileNameW(NULL, self, MAX_PATH);
    wchar_t *slash = wcsrchr(self, L'\\');
    if (slash)
        slash[1] = 0;

    _snwprintf(cmd, 32768, L"\"%ls\" -qtconf \"%lstarget_qt.conf\"", WIDEN(HOST_QMAKE), self);
    for (int i = 1; i < argc; i++) {
        const wchar_t *p = argv[i];
        while (*p) {
            while (*p == L' ' || *p == L'\t')
                p++;
            const wchar_t *start = p;
            while (*p && *p != L' ' && *p != L'\t')
                p++;
            if (p > start)
                append(cmd, 32768, start, (size_t)(p - start));
        }
    }

    STARTUPINFOW si = { .cb = sizeof(si) };
    PROCESS_INFORMATION pi;
    if (!CreateProcessW(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) {
        fwprintf(stderr, L"qmake6: cannot run %ls\n", WIDEN(HOST_QMAKE));
        return 127;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(pi.hProcess, &code);
    return (int)code;
}
