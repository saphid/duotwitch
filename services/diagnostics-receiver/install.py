#!/usr/bin/env python3
"""Run on lxso1 only after review. Touches only this service; never Tailscale."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess

NAME = 'duotwitch-diagnostics.service'


def run(*args):
    subprocess.run(args, check=True)


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


def manage(action, home, source):
    os.umask(0o077)
    root = home / 'services/duotwitch-diagnostics'
    data = home / 'pa-agent-data/duotwitch-diagnostics'
    unit = home / '.config/systemd/user' / NAME
    manifest = root / 'install-manifest.json'
    if root.is_symlink() or data.is_symlink() or manifest.is_symlink():
        fail('symlink at an owned path; refusing mutation')
    desired = {root / 'receiver.py': (source / 'receiver.py').read_bytes(),
               unit: (source / NAME).read_bytes()}
    hashes = {str(p): hashlib.sha256(b).hexdigest() for p, b in desired.items()}
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
