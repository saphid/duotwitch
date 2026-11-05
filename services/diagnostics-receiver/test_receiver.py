"""Synthetic-only real HTTP, storage, rejection and crash/restart checks."""
from contextlib import closing, contextmanager
import http.client
import json
import os
from pathlib import Path
import signal
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

import receiver as r

RUN = 'd42e3296-790a-41c5-9619-1bc20964e272'


def record(sequence=1, run=RUN):
    return dict(schema=1, run=run, sequence=sequence, wallTime=1800000000.0,
                uptime=12.5, event='media.observed', values={'playing': True, 'time': 12.0})


def envelope(item=None):
    item = record() if item is None else item
    return {'streams': [{'stream': dict(app='duotwitch', component='playback', run=item['run']),
                         'values': [[str(int(item['wallTime'] * 1e9)), json.dumps(item)]]}]}


def body(item=None):
    return json.dumps(envelope(item)).encode()


def rows(path):
    with closing(sqlite3.connect('file:' + str(path) + '?mode=ro', uri=True)) as db:
        return db.execute('SELECT run,sequence,timestamp,line FROM records ORDER BY sequence').fetchall()


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = r.Store(Path(self.temp.name) / 'data', headroom=0)
        self.server = r.Server(('127.0.0.1', 0), self.store, deadline=0.4)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': 0.02})
        self.thread.start()
        self.port = self.server.server_address[1]

    def tearDown(self):
        self.server.shutdown()
        self.thread.join()
        self.server.server_close()
        self.store.close()
        self.temp.cleanup()

    def post(self, data=None, path=r.PATH, method='POST', headers=None):
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=2)
        try:
            conn.request(method, path, body() if data is None else data,
                         {'Content-Type': 'application/json'} if headers is None else headers)
            response = conn.getresponse()
            result = response.status, response.read()
            return result
        finally:
            conn.close()

    def raw(self, request, shutdown=True):
        with socket.create_connection(('127.0.0.1', self.port), timeout=2) as sock:
            sock.sendall(request)
            if shutdown:
                sock.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    return b''.join(chunks)
                chunks.append(chunk)

    def test_actual_swift_wire_and_exact_local_readback(self):
        fixture = os.environ.get('DUOTWITCH_WIRE_FIXTURE')
        self.assertIsNotNone(fixture, 'use scripts/test-diagnostic-receiver.sh for the real Swift fixture')
        data = Path(fixture).read_bytes()
        self.assertNotIn(b'must-never-leave', data)
        self.assertEqual(self.post(data), (204, b''))
        expected = r.validate(data)
        self.assertEqual(rows(self.store.path), expected)
        self.assertEqual(self.post(data), (204, b''))
        self.assertEqual(rows(self.store.path), expected)

    def test_duplicate_and_identity_conflict_are_atomic(self):
        self.assertEqual(self.post()[0], 204)
        self.assertEqual(self.post()[0], 204)
        changed = record(); changed['values']['time'] = 99
        mixed = envelope(record(2)); mixed['streams'][0]['values'] += envelope(changed)['streams'][0]['values']
        self.assertEqual(self.post(json.dumps(mixed).encode())[0], 409)
        self.assertEqual(len(rows(self.store.path)), 1)

    def test_exact_post_only_no_query_or_health_route(self):
        for path in ['/', r.PATH + '/', r.PATH + '?query=x', r.PATH + '/query', '/health']:
            self.assertEqual(self.post(path=path)[0], 404)
        for method in ['GET', 'HEAD', 'PUT', 'DELETE', 'OPTIONS']:
            self.assertEqual(self.post(method=method)[0], 501)
        self.assertEqual(rows(self.store.path), [])

    def test_framing_and_header_bounds(self):
        for headers, status in [('', 411), ('Content-Length: -1\r\n', 411),
                                ('Content-Length: 65537\r\n', 413), ('Content-Length: 0\r\n', 413),
                                ('Content-Length: 1\r\nContent-Length: 1\r\n', 411),
                                ('Transfer-Encoding: chunked\r\nContent-Length: 1\r\n', 400),
                                ('Content-Encoding: gzip\r\nContent-Length: 1\r\n', 400),
                                ('Content-Length: 9\r\n', 400)]:
            raw = ('POST ' + r.PATH + ' HTTP/1.0\r\nContent-Type: application/json\r\n' + headers + '\r\nx').encode()
            self.assertIn((' ' + str(status) + ' ').encode(), self.raw(raw))
        self.assertEqual(self.post(headers={'Content-Type': 'text/plain'})[0], 415)
        self.assertIn(b' 431 ', self.raw(('POST ' + r.PATH + ' HTTP/1.0\r\nX: ' + 'x' * 8300 + '\r\n\r\n').encode()))
        self.assertEqual(rows(self.store.path), [])

    def test_absolute_deadline_and_concurrency_slots(self):
        sockets = [socket.create_connection(('127.0.0.1', self.port), timeout=2) for _ in range(4)]
        try:
            for sock in sockets:
                sock.sendall(b'POST /duotwitch-diagnostics HTTP/1.0\r\n')
            # The fifth request cannot create another handler thread.
            self.assertIn(b' 429 ', self.raw(b'GET / HTTP/1.0\r\n\r\n'))
            start = time.monotonic()
            for _ in range(5):
                time.sleep(0.1)
                for sock in sockets:
                    try:
                        sock.sendall(b'X')  # Trickle cannot extend the absolute deadline.
                    except OSError:
                        pass
            self.assertLess(time.monotonic() - start, 1.5)
            for sock in sockets:
                try:
                    self.assertEqual(sock.recv(1024), b'')
                except ConnectionResetError:
                    pass  # Both EOF and reset prove the deadline closed the connection.
        finally:
            for sock in sockets:
                sock.close()
        self.assertEqual(self.post()[0], 204)

    def test_global_rate_limit(self):
        self.server.tokens = 0
        self.assertEqual(self.post()[0], 429)
        self.assertEqual(rows(self.store.path), [])

    def test_storage_failure_never_acknowledges(self):
        for exception in [sqlite3.OperationalError('disk full'), OSError('fsync failed'), r.Rejected(503)]:
            with patch.object(self.store, 'append', side_effect=exception):
                self.assertEqual(self.post(), (503, b''))
        self.assertEqual(rows(self.store.path), [])
        with patch.object(self.store, 'available', side_effect=r.Rejected(503)):
            self.assertEqual(self.post()[0], 503)
        self.assertEqual(rows(self.store.path), [])

    def test_real_commit_and_retention_failures_return_503(self):
        self.assertEqual(self.post()[0], 204)
        def deny_commit(action, first, second, database, trigger):
            return (sqlite3.SQLITE_DENY if action == sqlite3.SQLITE_TRANSACTION and first == 'COMMIT'
                    else sqlite3.SQLITE_OK)
        self.store.db.set_authorizer(deny_commit)
        try:
            self.assertEqual(self.post(body(record(2)))[0], 503)
        finally:
            # Python 3.9 does not support clearing this callback with None.
            self.store.db.set_authorizer(lambda *arguments: sqlite3.SQLITE_OK)
        self.assertFalse(self.store.db.in_transaction, 'failed commit must close its transaction')
        self.assertEqual(len(rows(self.store.path)), 1)
        self.store.db.execute("CREATE TRIGGER refuse_delete BEFORE DELETE ON records BEGIN SELECT RAISE(ABORT,'failure'); END")
        with patch.object(self.store, 'clock', return_value=time.time() + r.TTL + 1):
            self.assertEqual(self.post(body(record(2)))[0], 503)
        self.assertEqual(len(rows(self.store.path)), 1)
        self.store.db.execute('DROP TRIGGER refuse_delete')
        self.assertEqual(self.post(body(record(2)))[0], 204)

    def test_idle_retention_and_maintenance_failure(self):
        self.assertEqual(self.post()[0], 204)
        with patch.object(self.store, 'clock', return_value=time.time() + r.TTL + 1):
            self.server.next_prune = 0
            self.server.service_actions()
        self.assertEqual(rows(self.store.path), [])
        with patch.object(self.store, 'prune', side_effect=sqlite3.OperationalError('failure')):
            self.server.next_prune = 0
            self.server.service_actions()  # Maintenance failure must not kill the listener.
        self.assertEqual(self.post()[0], 204)


class ValidationTests(unittest.TestCase):
    def assert_bad(self, value):
        with self.assertRaises(r.Rejected):
            r.validate(value if isinstance(value, bytes) else json.dumps(value).encode())

    def test_schema_types_strings_numeric_bounds_and_uuid(self):
        for key, value in [('schema', True), ('schema', 2), ('sequence', 0), ('sequence', True),
                           ('sequence', 2**63), ('wallTime', 0), ('uptime', -1), ('event', 'arbitrary.log'),
                           ('run', 'not-uuid'), ('values', []), ('event', {})]:
            item = record(); item[key] = value
            self.assert_bad(envelope(item))
        for values in [{'channel': 'secret'}, {'time': '1'}, {'playing': 1}, {'time': 1e13},
                       {'time': float('nan')}, {'time': float('inf')}, {'version': 'secret'},
                       {'source': 'https://private'}, {'playerSession': 'account'}, {'outputPorts': 'custom-device'},
                       {'outputPorts': ','.join(['Speaker'] * 9)}, {'unknown': False}, {'errorDomain': 'raw error'}]:
            item = record(); item['values'] = values
            self.assert_bad(envelope(item))
        for value in [b'null', b'{}', b'[]', b'{', b'\xff', b'{"streams":[],"streams":[]}', b'[' * 1100]:
            self.assert_bad(value)
        item = record(); item['extra'] = 'secret'; self.assert_bad(envelope(item))
        e = envelope(); e['streams'][0]['stream']['user'] = 'account'; self.assert_bad(e)
        e = envelope(); e['streams'][0]['values'][0][0] = '1800000000000009000'; self.assert_bad(e)
        e = envelope(); e['streams'][0]['values'][0][1] = '{"schema":1,"schema":1}'; self.assert_bad(e)

    def test_batch_and_line_bounds(self):
        e = envelope(); e['streams'] *= 33; self.assert_bad(e)
        e = envelope(); e['streams'][0]['values'] *= 33; self.assert_bad(e)
        e = envelope(); e['streams'][0]['values'][0][1] += ' ' * 4096; self.assert_bad(e)
        e = envelope(); e['streams'][0]['values'] *= 2; self.assert_bad(e)
        e = {'streams': []}
        for seq in range(1, 33):
            e['streams'] += envelope(record(seq))['streams']
        self.assertEqual(len(r.validate(json.dumps(e))), 32)
        e = envelope(); e['streams'][0]['values'] = []
        for seq in range(1, 33):
            line = json.dumps(record(seq)) + ' ' * 700
            e['streams'][0]['values'].append(['1800000000000000000', line])
        self.assert_bad(e)  # Combined record JSON exceeds 24 KiB despite individual lines fitting.

    def test_allowlist_parity_with_swift_source(self):
        source = (Path(__file__).resolve().parents[2] / 'Player/PlaybackDiagnosticRecord.swift').read_text()
        # Detect boundary drift rather than silently widening one implementation.
        import re
        def literals(start, end):
            return set(re.findall(r'"([^"\n]+)"', source.split(start, 1)[1].split(end, 1)[0]))
        self.assertEqual(r.EVENTS, literals('let events:', 'private static let flags:'))
        self.assertEqual(r.FLAGS, literals('let flags:', 'private static let numbers:'))
        self.assertEqual(r.NUMBERS, literals('let numbers:', 'private static let textEnums:'))
        self.assertEqual(r.PORTS, literals('let ports:', 'static func record'))
        enum_source = source.split('let textEnums:', 1)[1].split('private static let ports:', 1)[0]
        swift_enums = {key: set(re.findall(r'"([^"\n]+)"', values))
                       for key, values in re.findall(r'"([^"\n]+)"\s*:\s*\[([^]]*)\]', enum_source)}
        self.assertEqual(r.ENUMS, swift_enums)


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = r.Store(Path(self.temp.name) / 'data', headroom=0)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def test_permissions_sync_mode_and_page_bound(self):
        self.assertEqual(self.store.directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual(self.store.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.store.db.execute('PRAGMA synchronous').fetchone()[0], 3)
        self.assertEqual(self.store.db.execute('PRAGMA journal_mode').fetchone()[0], 'delete')
        self.assertEqual(self.store.db.execute('PRAGMA secure_delete').fetchone()[0], 1)
        self.assertLessEqual(self.store.db.execute('PRAGMA max_page_count').fetchone()[0] * 4096, r.DB_BYTES)

    def test_retention_dedup_does_not_extend_ttl(self):
        data = r.validate(body())
        with patch.object(self.store, 'clock', return_value=100000):
            self.store.append(data)
        with patch.object(self.store, 'clock', return_value=100100):
            self.store.append(data)
        self.assertEqual(self.store.db.execute('SELECT received FROM records').fetchone()[0], 100000)
        with patch.object(self.store, 'clock', return_value=100000 + r.TTL):
            self.store.prune()
        self.assertEqual(rows(self.store.path), [])
        self.assertNotIn(b'media.observed', self.store.path.read_bytes())  # secure_delete scrubbed free pages.

    def test_record_payload_run_bounds_and_rollback(self):
        with patch.object(r, 'MAX_RECORDS', 2):
            for seq in range(1, 4):
                self.store.append(r.validate(body(record(seq))))
            self.assertEqual([x[1] for x in rows(self.store.path)], [2, 3])
        with patch.object(r, 'MAX_PAYLOAD', 1):
            with self.assertRaises(r.Rejected):
                self.store.append(r.validate(body(record(4))))
        self.assertEqual([x[1] for x in rows(self.store.path)], [2, 3])
        with patch.object(r, 'MAX_RUNS', 1):
            other = record(4, 'a42e3296-790a-41c5-9619-1bc20964e272')
            with self.assertRaises(r.Rejected) as error:
                self.store.append(r.validate(body(other)))
            self.assertEqual(error.exception.status, 429)
        self.assertEqual(len(rows(self.store.path)), 2)
        # Real SQLite page exhaustion rolls back, leaving the previously acknowledged records.
        pages = self.store.db.execute('PRAGMA page_count').fetchone()[0]
        self.store.db.execute('PRAGMA max_page_count=%d' % pages)
        with self.assertRaises(sqlite3.OperationalError):
            for seq in range(10, 1000):
                self.store.append(r.validate(body(record(seq))))
        self.assertTrue({2, 3}.issubset({x[1] for x in rows(self.store.path)}))

    def test_retention_failure_rolls_back_and_headroom_floor(self):
        self.store.append(r.validate(body()))
        self.store.db.execute("CREATE TRIGGER refuse_delete BEFORE DELETE ON records BEGIN SELECT RAISE(ABORT,'failure'); END")
        with patch.object(self.store, 'clock', return_value=time.time() + r.TTL + 1):
            with self.assertRaises(sqlite3.Error):
                self.store.prune()
            with self.assertRaises(sqlite3.Error):
                self.store.append(r.validate(body(record(2))))
        self.assertEqual(len(rows(self.store.path)), 1)
        with patch.object(self.store, 'headroom', 10**30):
            with self.assertRaises(r.Rejected):
                self.store.append(r.validate(body(record(2))))
        self.assertEqual(len(rows(self.store.path)), 1)


class ProcessTests(unittest.TestCase):
    def test_sigkill_restart_http_durability_and_dedup(self):
        with tempfile.TemporaryDirectory() as temp:
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 0)); port = probe.getsockname()[1]
            data = Path(temp) / 'data'
            command = [sys.executable, '-B', str(Path(r.__file__).resolve()), '--data-dir', str(data), '--port', str(port)]
            def start():
                process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                for _ in range(100):
                    try:
                        with socket.create_connection(('127.0.0.1', port), timeout=0.05):
                            return process
                    except OSError:
                        if process.poll() is not None:
                            self.fail(process.stderr.read().decode())
                        time.sleep(0.02)
                process.kill(); process.wait(); self.fail('listener did not start')
            process = start()
            try:
                def post():
                    conn = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
                    conn.request('POST', r.PATH, body(), {'Content-Type': 'application/json'})
                    response = conn.getresponse(); result = (response.status, response.read()); conn.close(); return result
                self.assertEqual(post(), (204, b''))
                process.send_signal(signal.SIGKILL)
                self.assertEqual(process.wait(timeout=3), -signal.SIGKILL)
                process.stderr.close()
                self.assertEqual(rows(data / 'records.sqlite3'), r.validate(body()))
                process = start()
                self.assertEqual(post(), (204, b''))
                self.assertEqual(rows(data / 'records.sqlite3'), r.validate(body()))
            finally:
                process.kill(); process.wait(timeout=3); process.stderr.close()


class ServeGuardTests(unittest.TestCase):
    def test_add_remove_and_unrelated_drift(self):
        import copy
        import serve_config as config
        before = {'TCP': {'443': {'HTTPS': True}}, 'Web': {config.HOST: {'Handlers': {'/': {'Proxy': 'http://127.0.0.1:50388'}, '/fleet': {'Proxy': 'http://127.0.0.1:4173'}}}}, 'AllowFunnel': {'other:8443': True}}
        config.check(before)
        after = copy.deepcopy(before)
        after['Web'][config.HOST]['Handlers'][config.PATH] = config.HANDLER.copy()
        config.check(before, after)
        config.check(after, after)  # Idempotent add.
        config.check(after, before, 'removed')
        for changed in [dict(before, AllowFunnel={config.HOST: True}), {'TCP': {}, 'Web': {}}]:
            with self.assertRaises((ValueError, KeyError)):
                config.check(changed)
        drift = copy.deepcopy(after); drift['AllowFunnel'] = {}
        with self.assertRaises(ValueError):
            config.check(before, drift)
        drift = copy.deepcopy(after); drift['Web'][config.HOST]['Handlers']['/']['Proxy'] = 'http://wrong'
        with self.assertRaises(ValueError):
            config.check(before, drift)


class InstallerTests(unittest.TestCase):
    @contextmanager
    def manager(self, home):
        import install
        unit = home / '.config/systemd/user' / install.NAME
        def state():
            return {'LoadState': 'loaded' if unit.exists() else 'not-found',
                    'ActiveState': 'inactive', 'FragmentPath': str(unit) if unit.exists() else '',
                    'DropInPaths': '', 'SourcePath': ''}
        with patch.object(install, 'systemd_unit_paths', return_value=[unit.parent], create=True), \
             patch.object(install, 'systemd_snapshot', side_effect=state, create=True), \
             patch.object(install, 'run') as command, patch.object(install.socket, 'socket'):
            yield command

    def prepare(self, home):
        (home / 'services').mkdir()
        (home / 'pa-agent-data').mkdir()
        (home / '.config/systemd/user').mkdir(parents=True)

    def test_systemd_cli_parsers_use_bounded_commands_and_reject_bad_output(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            executable = Path(temp) / 'systemctl'
            executable.write_text('#!' + sys.executable + '\nprint("LoadState=not-found\\nActiveState=inactive\\nFragmentPath=\\nDropInPaths=\\nSourcePath=")\n')
            executable.chmod(0o700)
            paths = Path(temp) / 'systemd-analyze'
            paths.write_text('#!' + sys.executable + '\nprint("/tmp/units\\n/etc/systemd/user")\n')
            paths.chmod(0o700)
            with patch.dict(os.environ, {'PATH': temp}):
                self.assertEqual(install.systemd_snapshot()['LoadState'], 'not-found')
                self.assertEqual(install.systemd_unit_paths(), [Path('/tmp/units'), Path('/etc/systemd/user')])
                executable.write_text('#!' + sys.executable + '\nprint("LoadState=loaded\\nLoadState=not-found")\n')
                with self.assertRaises(ValueError): install.systemd_snapshot()
                paths.write_text('#!' + sys.executable + '\nprint("relative/path")\n')
                with self.assertRaises(ValueError): install.systemd_unit_paths()
                executable.write_text('#!' + sys.executable + '\nraise SystemExit(1)\n')
                with self.assertRaises(subprocess.CalledProcessError): install.systemd_snapshot()

    def test_effective_foreign_unit_is_refused_before_install(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp).resolve(); self.prepare(home)
            with self.manager(home) as command, patch.object(install, 'systemd_snapshot', return_value={
                    'LoadState': 'loaded', 'ActiveState': 'active', 'FragmentPath': '/etc/systemd/user/foreign.service',
                    'DropInPaths': '', 'SourcePath': ''}, create=True):
                with self.assertRaises(ValueError): install.manage('install', home, Path(r.__file__).parent)
                command.assert_not_called()
                self.assertFalse((home / 'services/duotwitch-diagnostics').exists())

    def test_dropin_and_lower_priority_unit_are_refused(self):
        import install
        for collision in ['exact-dropin', 'prefix-dropin', 'type-dropin', 'other-unit']:
            with self.subTest(collision=collision), tempfile.TemporaryDirectory() as temp:
                home = Path(temp).resolve(); self.prepare(home)
                units = home / '.config/systemd/user'; extra = home / 'extra-units'; extra.mkdir()
                if collision == 'other-unit': (extra / install.NAME).write_text('foreign')
                else:
                    directory = units / {'exact-dropin': install.NAME + '.d', 'prefix-dropin': 'duotwitch-.service.d', 'type-dropin': 'service.d'}[collision]
                    directory.mkdir(); (directory / 'override.conf').write_text('[Service]\nExecStart=/bin/false')
                with self.manager(home) as command, patch.object(install, 'systemd_unit_paths', return_value=[units, extra], create=True):
                    with self.assertRaises(ValueError): install.manage('install', home, Path(r.__file__).parent)
                    command.assert_not_called()

    def test_new_effective_override_blocks_rollback(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp).resolve(); self.prepare(home)
            with self.manager(home) as command:
                install.manage('install', home, Path(r.__file__).parent)
                command.reset_mock()
                with patch.object(install, 'systemd_snapshot', return_value={
                        'LoadState': 'loaded', 'ActiveState': 'active',
                        'FragmentPath': str(home / '.config/systemd/user' / install.NAME),
                        'DropInPaths': '/run/user/1000/systemd/user/override.conf', 'SourcePath': ''}, create=True):
                    with self.assertRaises(ValueError): install.manage('rollback', home, Path(r.__file__).parent)
                command.assert_not_called()
                self.assertTrue((home / '.config/systemd/user' / install.NAME).exists())

    def test_symlink_ancestors_are_refused_before_install(self):
        import install
        for relative in ['services', 'pa-agent-data', '.config', '.config/systemd', '.config/systemd/user']:
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as temp:
                home = Path(temp).resolve(); self.prepare(home)
                target = home / relative
                moved = home / 'moved-parent'; target.rename(moved); target.symlink_to(moved, target_is_directory=True)
                with self.manager(home) as command:
                    with self.assertRaises(ValueError): install.manage('install', home, Path(r.__file__).parent)
                    command.assert_not_called()
                    self.assertFalse((home / 'services/duotwitch-diagnostics').exists())

    def test_changed_ancestor_is_refused_before_rollback(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp).resolve(); self.prepare(home)
            with self.manager(home) as command:
                install.manage('install', home, Path(r.__file__).parent)
                parent = home / 'services'; moved = home / 'moved-services'
                parent.rename(moved); parent.symlink_to(moved, target_is_directory=True)
                command.reset_mock()
                with self.assertRaises(ValueError): install.manage('rollback', home, Path(r.__file__).parent)
                command.assert_not_called()
                self.assertTrue((moved / 'duotwitch-diagnostics/receiver.py').exists())

    def test_install_idempotency_rollback_and_owned_paths_only(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp).resolve()
            (home / 'services').mkdir()
            (home / 'pa-agent-data').mkdir()
            other = home / '.config/systemd/user/other.service'
            other.parent.mkdir(parents=True)
            other.write_text('untouched')
            source = Path(r.__file__).parent
            with self.manager(home) as command:
                install.manage('install', home, source)
                install.manage('install', home, source)
                data = home / 'pa-agent-data/duotwitch-diagnostics'
                self.assertEqual(data.stat().st_mode & 0o777, 0o700)
                (data / 'records.sqlite3').write_bytes(b'preserve')
                install.manage('rollback', home, source)
                install.manage('rollback', home, source)
                self.assertEqual((data / 'records.sqlite3').read_bytes(), b'preserve')
                self.assertEqual(other.read_text(), 'untouched')
                self.assertFalse((other.parent / install.NAME).exists())
                for call in command.call_args_list:
                    self.assertEqual(call.args[:2], ('systemctl', '--user'))
                    self.assertFalse(any('tailscale' in str(x) for x in call.args))

    def test_preexisting_paths_and_drift_fail_closed(self):
        import install
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp).resolve()
            (home / 'services').mkdir()
            (home / 'pa-agent-data').mkdir()
            source = Path(r.__file__).parent
            unit = home / '.config/systemd/user' / install.NAME
            unit.parent.mkdir(parents=True)
            unit.write_text('unowned')
            with self.manager(home) as command:
                with self.assertRaises(ValueError):
                    install.manage('install', home, source)
                command.assert_not_called()
                self.assertEqual(unit.read_text(), 'unowned')
                unit.unlink()
                install.manage('install', home, source)
                unit.write_text('external change')
                command.reset_mock()
                for action in ['install', 'rollback']:
                    with self.assertRaises(ValueError):
                        install.manage(action, home, source)
                command.assert_not_called()
                self.assertEqual(unit.read_text(), 'external change')


if __name__ == '__main__':
    unittest.main()
