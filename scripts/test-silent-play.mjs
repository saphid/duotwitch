// Offline public-API fixture. No browser, network or audio.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../Player/PlaybackSession.swift', import.meta.url), 'utf8');
const script = source.match(/static let publicPlayScript = """\n([\s\S]*?)\n\s*"""/)?.[1]
  ?? source.match(/callAsyncJavaScript\("""\n([\s\S]*?)\n\s*""", arguments:/)?.[1];
assert.ok(script, 'Production public Play script exists');
const execute = new (Object.getPrototypeOf(async function(){}).constructor)('session', 'muteForTesting', script);
let calls = [];
function fixture({ muted = false, acknowledge = true, methods = true } = {}) {
  calls = [];
  globalThis.location = { href: 'https://owned.invalid/player?session=current' };
  globalThis.window = { duoPlayer: { play() { calls.push('play'); } } };
  if (methods) {
    window.duoPlayer.setMuted = value => { calls.push('setMuted'); if (acknowledge) muted = value; };
    window.duoPlayer.getMuted = () => { calls.push('getMuted'); return muted; };
  }
}
fixture({ acknowledge: false });
assert.equal(await execute('current', true), false, 'Unconfirmed mute must refuse Play');
assert.ok(!calls.includes('play'));
fixture();
assert.equal(await execute('current', true), true);
assert.equal(calls.at(-1), 'play');
assert.ok(calls.indexOf('getMuted') > calls.indexOf('setMuted'));
fixture({ methods: false });
assert.equal(await execute('current', true), false);
assert.ok(!calls.includes('play'));
fixture({ methods: false });
assert.equal(await execute('current', false), true, 'Ordinary playback does not require the test gate');
fixture();
assert.equal(await execute('stale', true), false);
assert.deepEqual(calls, []);
fixture();
window.duoPlayer.getMuted = () => { location.href = 'https://owned.invalid/player?session=replaced'; return true; };
assert.equal(await execute('current', true), false);
assert.ok(!calls.includes('play'));
console.log('PASS: 6 silent Play API cases; unconfirmed, missing and stale mute cannot start playback.');
