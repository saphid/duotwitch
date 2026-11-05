#!/usr/bin/env python3
"""Read-only guard for additive Serve changes. Never executes Tailscale."""
import argparse
import copy
import json
from pathlib import Path

HOST = 'lxso1.tail4e5636.ts.net:443'
PATH = '/duotwitch-diagnostics'
HANDLER = {'Proxy': 'http://127.0.0.1:18792/duotwitch-diagnostics'}


def check(before, after=None, action='added'):
    handlers = before['Web'][HOST]['Handlers']
    if before.get('AllowFunnel', {}).get(HOST):
        raise ValueError('443 has public Funnel enabled; do not add diagnostics here')
    if '/' not in handlers or before['TCP']['443'] != {'HTTPS': True}:
        raise ValueError('expected existing 443 HTTPS root is absent')
    if PATH in handlers and handlers[PATH] != HANDLER:
        raise ValueError('diagnostics route already belongs to another target')
    if after is None:
        return
    expected = copy.deepcopy(before)
    if action == 'added':
        expected['Web'][HOST]['Handlers'][PATH] = HANDLER
    else:
        if handlers.get(PATH) != HANDLER:
            raise ValueError('refusing removal of unowned route')
        del expected['Web'][HOST]['Handlers'][PATH]
    if expected != after:
        raise ValueError('Serve drift: unrelated configuration changed or diagnostics target differs')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['preflight', 'added', 'removed'])
    parser.add_argument('before', type=Path)
    parser.add_argument('after', nargs='?', type=Path)
    args = parser.parse_args()
    if args.action != 'preflight' and args.after is None:
        parser.error('comparison requires an after snapshot')
    check(json.loads(args.before.read_text()), json.loads(args.after.read_text()) if args.after else None, args.action)
    print('PASS: 443 root, other routes, TCP and AllowFunnel preserved; expected diagnostics change only.')


if __name__ == '__main__':
    main()
