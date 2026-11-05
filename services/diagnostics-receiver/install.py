#!/usr/bin/env python3
"""Run on lxso1 only after review. Touches only this service; never Tailscale."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import stat
import subprocess

NAME = 'duotwitch-diagnostics.service'


def run(*args):
    subprocess.run(args, check=True, timeout=30)


def write(path, content, mode):
    temporary = path.with_suffix(path.suffix + '.tmp')
    with temporary.open('xb') as stream:
        os.chmod(temporary, mode)
        stream.write(content)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def fail(message):
    raise ValueError(message)


def systemd_unit_paths():
    result = subprocess.run(('systemd-analyze', '--user', 'unit-paths'),
                            check=True, capture_output=True, text=True, timeout=10)
    paths = [Path(line) for line in result.stdout.splitlines() if line]
    if not paths or any(not path.is_absolute() for path in paths):
        fail('invalid systemd search path response')
    return paths


def systemd_snapshot():
    keys = ('LoadState', 'ActiveState', 'FragmentPath', 'DropInPaths', 'SourcePath')
    result = subprocess.run(('systemctl', '--user', 'show', NAME, '--no-pager',
                             *('--property=' + key for key in keys)),
                            check=True, capture_output=True, text=True, timeout=10)
    values = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.partition('=')
        if not separator or key not in keys or key in values:
            fail('invalid systemd unit response')
        values[key] = value
    if set(values) != set(keys):
        fail('incomplete systemd unit response')
    return values


def check_paths(home, directories, files):
    if not home.is_absolute() or home.resolve() != home:
        fail('home must be an absolute path without symlink ancestors')
    for directory in directories:
        relative = directory.relative_to(home)
        current = home
        for part in (None, *relative.parts):
            if part is not None:
                current = current / part
            if current.is_symlink():
                fail('symlink directory ancestor; refusing mutation')
            if current.exists():
                info = current.stat()
                if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
                    fail('directory ownership or type changed; refusing mutation')
                if info.st_mode & 0o022:
                    fail('writable directory ancestor; refusing mutation')
    for path in files:
        if path.is_symlink():
            fail('symlink at owned file; refusing mutation')
        if path.exists():
            info = path.stat()
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                fail('owned file ownership or type changed; refusing mutation')


def check_systemd(unit, owned):
    # Search-path collisions include lower-priority units and type/prefix drop-ins.
    for directory in systemd_unit_paths():
        candidate = directory / NAME
        if candidate.exists() or candidate.is_symlink():
            if candidate != unit or not owned:
                fail('unowned unit in systemd search path')
        for dropin in (NAME + '.d', 'duotwitch-.service.d', 'service.d'):
            path = directory / dropin
            if path.is_symlink() or (path.exists() and (
                    not path.is_dir() or any(path.glob('*.conf')))):
                fail('applicable systemd drop-in; refusing mutation')
    state = systemd_snapshot()
    if state['DropInPaths'] or state['SourcePath']:
        fail('effective systemd overrides or generated source; refusing mutation')
    if owned:
        if state['LoadState'] != 'loaded' or state['FragmentPath'] != str(unit):
            fail('effective systemd unit is not the owned fragment')
    elif (state['LoadState'] != 'not-found' or state['FragmentPath'] or
          state['ActiveState'] != 'inactive'):
        fail('pre-existing effective systemd unit; refusing mutation')


def manage(action, home, source):
    os.umask(0o077)
    root = home / 'services/duotwitch-diagnostics'
    data = home / 'pa-agent-data/duotwitch-diagnostics'
    unit = home / '.config/systemd/user' / NAME
    manifest = root / 'install-manifest.json'
    check_paths(home, (root, data, unit.parent), (manifest, root / 'receiver.py', unit))
    desired = {root / 'receiver.py': (source / 'receiver.py').read_bytes(),
               unit: (source / NAME).read_bytes()}
    hashes = {str(p): hashlib.sha256(b).hexdigest() for p, b in desired.items()}
    check_systemd(unit, manifest.exists())
    if action == 'install':
        if manifest.exists():
            if json.loads(manifest.read_text()) != hashes:
                fail('different release already installed; preserve it and plan an explicit upgrade')
            for path, body in desired.items():
                if path.is_symlink() or path.read_bytes() != body:
                    fail('installed source drift; refusing overwrite')
        else:
            if root.exists() or unit.exists() or unit.is_symlink() or data.exists():
                fail('unowned existing path; refusing overwrite')
            # Fail before writes if port is occupied; no process is stopped to free it.
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 18792))
            root.mkdir(mode=0o700)
            data.mkdir(mode=0o700)
            unit.parent.mkdir(parents=True, exist_ok=True)
            for path, body in desired.items():
                write(path, body, 0o600)
            write(manifest, (json.dumps(hashes, sort_keys=True) + '\n').encode(), 0o600)
        run('systemctl', '--user', 'daemon-reload')
        check_paths(home, (root, data, unit.parent), (manifest, root / 'receiver.py', unit))
        check_systemd(unit, True)
        run('systemctl', '--user', 'enable', '--now', NAME)
        run('systemctl', '--user', 'is-active', '--quiet', NAME)
    else:
        if not manifest.exists():
            if root.exists() or unit.exists():
                fail('no ownership manifest; refusing mutation')
            return  # Already rolled back. Retain records for SSH readback.
        installed = json.loads(manifest.read_text())
        if set(installed) != {str(p) for p in desired}:
            fail('unexpected ownership manifest')
        for path in desired:
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != installed[str(path)]:
                fail('installed source drift; refusing rollback')
        check_paths(home, (root, data, unit.parent), (manifest, root / 'receiver.py', unit))
        check_systemd(unit, True)
        run('systemctl', '--user', 'disable', '--now', NAME)
        unit.unlink()
        (root / 'receiver.py').unlink()
        manifest.unlink()
        root.rmdir()  # Fail if unexpected files exist; never recursively remove.
        run('systemctl', '--user', 'daemon-reload')
        print('Rolled back own unit/source; retained protected data directory. No Serve changes.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'rollback'])
    args = parser.parse_args()
    if socket.gethostname().split('.')[0] != 'lxso1' or Path.home() != Path('/home/saphid'):
        parser.error('only run as saphid on lxso1')
    manage(args.action, Path.home(), Path(__file__).resolve().parent)


if __name__ == '__main__':
    main()
