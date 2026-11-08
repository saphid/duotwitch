# App Store approval checkpoint — 8 November 2026

Goal: Apple approval of the exact submitted app/version/build, with manual release. This newer authorization supersedes historical internal-TestFlight-only limits. Approval is not achieved.

Owning spine: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208); cross-app setup background: [#206](https://github.com/saphid/personal-ops/issues/206).

## Live identity and state

- App **6831008730**, bundle **com.saphid.duotwitch**, resolved live by bundle ID.
- iOS App Store **1.0**, version ID **fa4b6291-c62c-4b78-b4fc-54f8ac528bc6**, **PREPARE_FOR_SUBMISSION**. No build attached; no App Review submission yet.
- Changed releaseType from AFTER_APPROVAL to **MANUAL** and verified live. Preserve MANUAL in every later readback; never call release.
- All eight existing processed builds are **INTERNAL_ONLY**. Latest **0.1.0 (202611060726)** remains the current internal beta; no App Store-eligible upload yet.
- Apple accepted and read back public name **Saphid Duo Viewer** and subtitle **Live streams and flexible chat**. The shorter on-device name is Duo Viewer. Twitch trademark guidelines prohibit incorporating Twitch in app names without express permission; bundle/repo/module identity remains unchanged. The first alternative, Duo Viewer, was already taken on Apple.
- Entertainment category, third-party-content declaration, copyright and source-backed listing text saved. Initial free price schedule and Australia-only availability created, automatic new-territory expansion off. These are initial submission settings; no existing price was changed and no paid/legal agreement was accepted.
- Age questionnaire saved for Twitch UGC/ads/chat; live legacy rating **17+**, France/Brazil **18**. Initial prolonged-graphic-violence answer produced UNRATED; corrected to NONE for prohibited extreme/sadistic material, while retaining frequent realistic/cartoon violence, weapons, profanity and mature themes. This is a questionnaire answer, not a guarantee that Twitch UGC has no violations. Review this assumption before final submission.

## Current source candidate

Base HEAD **0e97c07f2541835121f3a741d501cd931330cf80**, uncommitted changes in this checkout. Marketing version now **1.0**; archive must use a new unique build number and **testFlightInternalTestingOnly=false**.

- Native privacy/support links available in Account before sign-in.
- Long-press chat report sheet opens a user-sent email draft; no report sent during development. Local user blocking removes displayed/pending messages, hides later messages, persists across relaunch, and can be undone in Account. Sign-out clears saved block entries. This does not change Twitch’s account block list.
- Guest channel-name navigation uses the official Twitch embed without a native account. Discovery/following/chat still require Twitch authorization. Real broadcaster ID lookup occurs after sign-in. Multiple unresolved guest channels are distinguished by login, not their empty numeric IDs.
- Added required-reason manifest for app preferences and elapsed-time measurement. Local diagnostics use time since the app diagnostic run began; automatic upload projection zeros uptime. Canonical validation rejects old queued records containing raw device uptime. No receiver or shared network route was changed.
- Public support/privacy source in `web-site/`; supporting Pages commits submitted using the Contents API, touching only `apps/duotwitch/`. Shared local website checkout had unrelated changes and was left untouched. HTTP publication remains pending while Pages builds queue; initial URL reads returned404. Do not claim live policy publication until exact HTTP readback succeeds.

## Verification

Evidence root: `build/app-store-approval-20261108/` (ignored; contains protected private contact/auth artifacts—do not upload the whole directory).

- `guest-final-tests.xcresult`, summary and actual exit agree: **119 passed, 0 failed, 0 skipped; exit0**, runtimeWarnings empty. This includes chat safety and guest identity regressions. Earlier39-focused/118-full results are preceding-candidate evidence.
- `simulator/DuoTwitch.app`: exact bundle com.saphid.duotwitch, display Duo Viewer, version1.0, registered public client and owned player origin; strict/deep codesign passes and PrivacyInfo.xcprivacy is bundled.
- `node scripts/test-silent-play.mjs`:6 public-API fail-closed mute cases pass. `isolated-upload-tests.log` and exit: uploader tests pass; these overlap the Simulator suite, not additional distinct tests.
- Xcode wrapper uses private temporary DerivedData with owned cleanup.49GiB was available; the host’s50GiB reserve initially deferred the run. A deliberate20GiB task floor was then used; no shared caches or other jobs were removed. Sibling Frame Control/Duocord build locks were preserved.
- Opus independent review attempt **350ce52f-8746-44d6-8211-808c2c708bb3**, provider **claudeAgent**, model **claude-opus-5-5**, high, final **failed**: Claude API rate limit reached. **No independent review occurred; no findings returned.** Receipt `independent-review-attempt.json`. A second attempt covering the final119-test guest candidate, task **01e795f8-cd53-4403-9941-66844e711681**, same provider/model/high, also failed from the Claude API rate limit with no review or findings. Receipt `independent-review-final-attempt.json`. Continuing under the explicitly authorized best-effort exception.
- Current silent runtime, sustained changing video, authenticated chat/keyboard, physical Duo/fold and final screenshots remain unverified. Historical freezes/spontaneous Twitch Pause remain unresolved; do not transfer prior UI evidence to this candidate.

## Authentication and remaining work

A task-local ASC web cache was isolated under `apple-auth-private/session`; shared auth/config were not modified. The one private trusted-device code card timed out. Bounded login exited1 with no code supplied. Do not reuse that challenge or ask again until Alex is available. Public API-key reads/writes still work. App Privacy publication needs a fresh authenticated web session; neither a published label nor completion is claimed.

- [ ] Final independent review best effort; disclose capacity failure if unavailable.
- [ ] Current-candidate silent Simulator acceptance through Astra and device_list/device_open/agent-device/device_screenshot only; preserve Simulator data/Keychain/preferences. No desktop browser/physical-device authorization.
- [ ] Verify sustained visible video and recovery; investigate a repeatable failure before claiming readiness.
- [ ] Capture honest App Store screenshots from the exact candidate, with documented content rights and no personal accounts/data.
- [ ] Exact live HTTPS support/privacy readback after Pages deployment.
- [ ] Publish accurate App Privacy label using isolated cache after fresh private Apple code input; account/chat data goes to Twitch, diagnostic subset to owned receiver, and embedded Twitch player handles its own advertising/storage.
- [ ] Create review contact/notes using existing Apple review contact read-only from Frame Control; keep private contact artifacts protected. Do not invent demo credentials or claim authenticated coverage.
- [ ] Archive/sign/export/upload eligible1.0 build; attach only after VALID processing; read back export/encryption/identity/build relationship.
- [ ] Re-run `asc review doctor`; resolve actual blockers, retain MANUAL, submit authorized review.
- [ ] Follow live review feedback and resubmit necessary fixes.
- [ ] Complete goal only on live approved state (e.g. PENDING_DEVELOPER_RELEASE) for the exact version/build, with a final evidence receipt.
