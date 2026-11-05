#!/usr/bin/env python3
"""DuoTwitch-only validated JSON records in bounded SQLite. No HTTP read API."""
import argparse
from contextlib import contextmanager
import http.client
import http.server
import json
import math
import os
from pathlib import Path
import re
import shutil
import socket
import socketserver
import sqlite3
import threading
import time
import uuid

PATH = '/duotwitch-diagnostics'
MAX_BODY = 64 * 1024
MAX_LINE = 4096
MAX_RECORDS = 10000
MAX_RUNS = 128
MAX_PAYLOAD = 4 * 1024 * 1024
DB_BYTES = 8 * 1024 * 1024  # DELETE journal may transiently double this; <32 MiB total.
HEADROOM = 1024 * 1024 * 1024
TTL = 86400
EVENTS = set('''app.launch app.scene diagnostics.export player.created channel.open playback.state
 audio.deactivation audio.transition.begin audio.transition.complete audio.transition.failed native.play.requested
 native.play.result native.pause.requested native.pause.result video.hidden video.fit video.geometry media.pause.begin
 media.pause.callback media.pause.result web.navigation.finished web.navigation.provisionalFailed web.navigation.failed
 web.process.terminated host.received host.applied web.load.sent media.observed audio.notification web.window.changed
 web.host.attach watch.enter watch.leave'''.split())
FLAGS = set('''playing requestingPlay audioReady fits hostReady needsLoad failed windowAttached forceReload sameChannel
 requestedPlaying activating allowed accepted stale confirmed newFits paused ended muted hidden systemSource hasInterruption'''.split())
NUMBERS = set('''pendingPauses loadCount appState webWidth webHeight width height errorCode video time volume ready network
 rate error decoded dropped reason type routeReason'''.split())
ENUMS = {
    'source': 'app system systemIdle', 'audioOwner': 'webKit', 'phase': 'active inactive background',
    'cause': 'user insufficientSpace watchHidden audioInterruption other',
    'event': 'READY PLAYING PAUSE ONLINE OFFLINE PLAYBACK_BLOCKED ENDED',
    'kind': 'observerReady attached detached sample play playing pause waiting stalled ended error emptied loadedmetadata visibility',
    'errorDomain': 'NSURLErrorDomain WKErrorDomain AVFoundationErrorDomain NSOSStatusErrorDomain other',
    'notification': 'AVAudioSessionDidBecomeInactiveNotification AVAudioSessionInterruptionNotification AVAudioSessionRouteChangeNotification AVAudioSessionMediaServicesWereLostNotification AVAudioSessionMediaServicesWereResetNotification',
    'category': 'AVAudioSessionCategoryAmbient AVAudioSessionCategorySoloAmbient AVAudioSessionCategoryPlayback AVAudioSessionCategoryRecord AVAudioSessionCategoryPlayAndRecord AVAudioSessionCategoryMultiRoute',
    'mode': 'AVAudioSessionModeDefault AVAudioSessionModeMoviePlayback AVAudioSessionModeSpokenAudio AVAudioSessionModeVoiceChat AVAudioSessionModeVideoChat AVAudioSessionModeMeasurement AVAudioSessionModeGameChat AVAudioSessionModeVideoRecording AVAudioSessionModeVoicePrompt',
}
ENUMS = {k: set(v.split()) for k, v in ENUMS.items()}
PORTS = set('''Speaker Receiver MicrophoneBuiltIn AirPlay BluetoothA2DPOutput BluetoothHFP BluetoothLE BuiltInReceiver
 BuiltInSpeaker BuiltInMic CarAudio DisplayPort HDMIOutput Headphones HeadsetMic LineIn LineOut USBAudio Virtual AVB PCI
 FireWire Thunderbolt ContinuityCaptureMicrophone'''.split())


class Rejected(Exception):
    def __init__(self, status):
        self.status = status


def require(condition):
    if not condition:
        raise Rejected(400)


def is_uuid(value):
    return (isinstance(value, str) and re.fullmatch(r'[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', value)
            is not None and str(uuid.UUID(value)) == value.lower())


def number(value, low, high):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


def decode(text):
    return json.loads(text, object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(Rejected(400)))


def validate(body):
    """Keep the client's stable Loki envelope, but accept no arbitrary log lines."""
    try:
        payload = decode(body)
        require(type(payload) is dict and set(payload) == {'streams'})
        streams = payload['streams']
        require(type(streams) is list and 1 <= len(streams) <= 32)
        records, identities, total = [], set(), 0
        for stream in streams:
            require(type(stream) is dict and set(stream) == {'stream', 'values'})
            labels, values = stream['stream'], stream['values']
            require(type(labels) is dict and set(labels) == {'app', 'component', 'run'})
            require(labels['app'] == 'duotwitch' and labels['component'] == 'playback' and is_uuid(labels['run']))
            require(type(values) is list and 1 <= len(values) <= 32)
            for pair in values:
                require(type(pair) is list and len(pair) == 2 and all(type(x) is str for x in pair))
                stamp, line = pair
                require(re.fullmatch(r'[0-9]{18,19}', stamp) is not None)
                size = len(line.encode('utf-8'))
                total += size
                require(size <= MAX_LINE and total <= 24 * 1024 and len(records) < 32)
                r = decode(line)
                require(type(r) is dict and set(r) == {'schema', 'run', 'sequence', 'wallTime', 'uptime', 'event', 'values'})
                require(type(r['schema']) is int and r['schema'] == 1)
                require(is_uuid(r['run']) and r['run'] == labels['run'])
                require(type(r['sequence']) is int and 1 <= r['sequence'] <= 9223372036854775807)
                require(number(r['wallTime'], 946684800, 4102444800) and number(r['uptime'], 0, 1e12))
                # Swift converts Double seconds to integer ns. Allow rounding at the binary float boundary.
                require(abs(int(stamp) - r['wallTime'] * 1_000_000_000) <= 1024)
                require(type(r['event']) is str and r['event'] in EVENTS and type(r['values']) is dict)
                for key, value in r['values'].items():
                    valid = ((key in FLAGS and type(value) is bool)
                             or (key in NUMBERS and number(value, -1e12, 1e12)))
                    if type(value) is str:
                        valid = ((key in {'playerSession', 'command', 'appearance'} and is_uuid(value))
                                 or (key in {'version', 'build', 'os'} and re.fullmatch(r'[0-9.]{1,32}', value) is not None)
                                 or (key in ENUMS and value in ENUMS[key])
                                 or (key == 'outputPorts' and len(value) <= 256 and len(value.split(',')) <= 8
                                     and all(p in PORTS for p in value.split(','))))
                    require(valid)
                identity = (r['run'].lower(), r['sequence'])
                require(identity not in identities)
                identities.add(identity)
                # Reserialize validated fields only. Never store the raw HTTP body or headers.
                clean = json.dumps(r, sort_keys=True, separators=(',', ':'), ensure_ascii=True)
                records.append((*identity, stamp, clean))
        return records
    except (ValueError, TypeError, KeyError, OverflowError, RecursionError, UnicodeError):
        raise Rejected(400) from None


class Store:
    def __init__(self, directory, *, clock=time.time, headroom=HEADROOM):
        self.directory = Path(directory)
        self.clock, self.headroom = clock, headroom
        self.lock = threading.Lock()
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.directory.is_symlink():
            raise ValueError('data directory must not be a symlink')
        os.chmod(self.directory, 0o700)
        self.path = self.directory / 'records.sqlite3'
        if self.path.is_symlink():
            raise ValueError('database must not be a symlink')
        if self.path.exists() and self.path.stat().st_size > DB_BYTES:
            raise ValueError('database exceeds size cap')
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o600)
        os.fchmod(fd, 0o600)
        os.close(fd)
        self.db = sqlite3.connect(self.path, timeout=2, check_same_thread=False)
        self.db.execute('PRAGMA journal_mode=DELETE')
        self.db.execute('PRAGMA synchronous=EXTRA')  # FULL plus journal-unlink directory sync.
        self.db.execute('PRAGMA secure_delete=ON')
        page_size = self.db.execute('PRAGMA page_size').fetchone()[0]
        self.db.execute('PRAGMA max_page_count=%d' % (DB_BYTES // page_size))
        self.db.execute('CREATE TABLE IF NOT EXISTS records (run TEXT NOT NULL, sequence INTEGER NOT NULL, '
                        'timestamp TEXT NOT NULL, line TEXT NOT NULL, received REAL NOT NULL, '
                        'PRIMARY KEY(run,sequence))')
        self.db.execute('CREATE INDEX IF NOT EXISTS received_idx ON records(received)')
        self.db.commit()
        # Sync the initial directory entry as well as SQLite's synced commits.
        fd = os.open(self.directory, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
        self.prune()

    def available(self):
        if shutil.disk_usage(self.directory).free < self.headroom:
            raise Rejected(503)

    def expire(self):
        now = self.clock()
        self.db.execute('DELETE FROM records WHERE received <= ? OR received > ?', (now - TTL, now + 3600))

    @contextmanager
    def transaction(self):
        # Explicit cleanup also covers Python versions whose connection context
        # manager leaves a transaction open when COMMIT itself is rejected.
        try:
            yield
            self.db.commit()
        except BaseException:
            self.db.rollback()
            raise

    def prune(self):
        with self.lock:
            self.available()
            with self.transaction():
                self.expire()

    def append(self, records):
        with self.lock:
            self.available()
            with self.transaction():
                self.expire()
                for run, sequence, stamp, line in records:
                    old = self.db.execute('SELECT timestamp,line FROM records WHERE run=? AND sequence=?',
                                          (run, sequence)).fetchone()
                    if old:
                        if old != (stamp, line):
                            raise Rejected(409)  # Stable identity cannot be overwritten.
                        continue
                    self.db.execute('INSERT INTO records VALUES (?,?,?,?,?)', (run, sequence, stamp, line, self.clock()))
                runs = self.db.execute('SELECT COUNT(DISTINCT run) FROM records').fetchone()[0]
                if runs > MAX_RUNS:
                    raise Rejected(429)
                count, size = self.db.execute('SELECT COUNT(*),COALESCE(SUM(length(line)),0) FROM records').fetchone()
                # Evict only previous batches; never acknowledge a batch we immediately evicted.
                incoming = {(r[0], r[1]) for r in records}
                if count > MAX_RECORDS or size > MAX_PAYLOAD:
                    for run, seq, length in self.db.execute('SELECT run,sequence,length(line) FROM records ORDER BY received, rowid').fetchall():
                        if count <= MAX_RECORDS and size <= MAX_PAYLOAD:
                            break
                        if (run, seq) not in incoming:
                            self.db.execute('DELETE FROM records WHERE run=? AND sequence=?', (run, seq))
                            count, size = count - 1, size - length
                    if count > MAX_RECORDS or size > MAX_PAYLOAD:
                        raise Rejected(503)
            # Context manager has completed SQLite's synchronous durable COMMIT before caller sends 204.

    def close(self):
        self.db.close()


class HeaderBudget:
    def __init__(self, raw):
        self.raw, self.remaining = raw, 8192

    def readline(self, size=-1):
        line = self.raw.readline(min(size if size >= 0 else 8193, self.remaining + 1))
        self.remaining -= len(line)
        if self.remaining < 0:
            raise http.client.LineTooLong('headers')
        return line

    def read(self, size):
        return self.raw.read(size)

    def close(self):
        self.raw.close()


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = 'DuoTwitch'
    sys_version = ''

    def setup(self):
        super().setup()
        self.rfile = HeaderBudget(self.rfile)

    def log_message(self, *args):
        pass  # No IPs, paths, user agents, errors, request lines or payload logging.

    def send_error(self, code, message=None, explain=None):
        self.reply(code)

    def reply(self, code):
        self.close_connection = True
        self.send_response(code)
        self.send_header('Content-Length', '0')
        self.send_header('Connection', 'close')
        if code in (429, 503):
            self.send_header('Retry-After', '60')
        self.end_headers()

    def do_POST(self):
        try:
            if self.path != PATH:
                raise Rejected(404)
            lengths = self.headers.get_all('Content-Length', [])
            if self.headers.get_all('Transfer-Encoding') or self.headers.get_all('Content-Encoding'):
                raise Rejected(400)
            if len(lengths) != 1 or re.fullmatch(r'[0-9]{1,6}', lengths[0]) is None:
                raise Rejected(411)
            length = int(lengths[0])
            if not 0 < length <= MAX_BODY:
                raise Rejected(413)
            if self.headers.get_all('Content-Type', []) != ['application/json']:
                raise Rejected(415)
            body = self.rfile.read(length)
            if len(body) != length:
                raise Rejected(400)
            self.server.store.append(validate(body))
            self.reply(204)
        except Rejected as error:
            self.reply(error.status)
        except (sqlite3.Error, OSError):
            self.reply(503)


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = False
    block_on_close = True
    request_queue_size = 8
    allow_reuse_address = True

    def __init__(self, address, store, *, deadline=5):
        self.store, self.deadline = store, deadline
        self.slots = threading.BoundedSemaphore(4)
        self.tokens, self.last_token = 20.0, time.monotonic()
        self.next_prune = time.monotonic() + 60
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        now = time.monotonic()
        self.tokens = min(20, self.tokens + (now - self.last_token) * 2)  # Global 120/min, no peer tracking.
        self.last_token = now
        if self.tokens < 1 or not self.slots.acquire(blocking=False):
            try:
                request.settimeout(0.1)
                request.sendall(b'HTTP/1.0 429 Too Many Requests\r\nContent-Length: 0\r\nRetry-After: 60\r\nConnection: close\r\n\r\n')
            except OSError:
                pass
            self.shutdown_request(request)
            return
        self.tokens -= 1
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        def end_request():
            try:
                request.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
        # Absolute deadline covers slow trickle headers/body, not only idle reads.
        timer = threading.Timer(self.deadline, end_request)
        request.settimeout(self.deadline)
        timer.start()
        try:
            super().process_request_thread(request, client_address)
        finally:
            timer.cancel()
            timer.join()
            self.slots.release()

    def handle_error(self, request, client_address):
        pass  # Never emit tracebacks containing request or peer information.

    def service_actions(self):
        if time.monotonic() >= self.next_prune:
            self.next_prune = time.monotonic() + 60
            try:
                self.store.prune()
            except (sqlite3.Error, OSError, Rejected):
                pass  # Storage failures also fail ingest closed; systemd remains the liveness probe.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data-dir', type=Path, required=True)
    parser.add_argument('--port', type=int, default=18792)
    args = parser.parse_args()
    os.umask(0o077)
    store = Store(args.data_dir)
    try:
        with Server(('127.0.0.1', args.port), store) as server:
            server.serve_forever()
    finally:
        store.close()


if __name__ == '__main__':
    main()
