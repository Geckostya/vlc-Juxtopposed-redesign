#!/usr/bin/env python3
"""Mirror the Windows checkout into the WSL build tree.

The Windows checkout uses CRLF line endings, which breaks the shell scripts of
the build system. Text files are converted to LF on the fly. Only files whose
content changed are rewritten, so incremental builds stay incremental.
"""
import os, subprocess, sys

src, dst = sys.argv[1], sys.argv[2]

files = subprocess.run(
    ['git', '-c', 'core.quotepath=off', '-C', src, 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    check=True, capture_output=True).stdout.split(b'\0')

# executable bits come from the git index (the Windows file system has none)
executables = set()
for entry in subprocess.run(['git', '-c', 'core.quotepath=off', '-C', src, 'ls-files', '-z', '-s'],
                            check=True, capture_output=True).stdout.split(b'\0'):
    if entry.startswith(b'100755'):
        executables.add(entry.split(b'\t', 1)[1].decode('utf-8'))

written = 0
seen = set()
for rel in files:
    if not rel:
        continue
    rel = rel.decode('utf-8')
    s = os.path.join(src, rel)
    if not os.path.isfile(s):
        continue  # deleted in the working tree
    d = os.path.join(dst, rel)
    seen.add(rel)
    with open(s, 'rb') as f:
        data = f.read()
    if b'\0' not in data[:8192]:
        data = data.replace(b'\r\n', b'\n')
    try:
        with open(d, 'rb') as f:
            if f.read() == data:
                continue
    except FileNotFoundError:
        os.makedirs(os.path.dirname(d), exist_ok=True)
    with open(d, 'wb') as f:
        f.write(data)
    if rel in executables or data.startswith(b'#!'):
        os.chmod(d, 0o755)
    written += 1

print(f'synced {len(seen)} files, {written} updated')
