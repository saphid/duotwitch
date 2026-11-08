# App Store approval checkpoint — 8 November 2026

Goal: Apple approval of the exact submitted app/version/build, with manual release. This newer authorization supersedes historical internal-TestFlight-only limits. Approval is not achieved.

Owning spine: [personal-ops #208](https://github.com/saphid/personal-ops/issues/208); cross-app setup background: [#206](https://github.com/saphid/personal-ops/issues/206).

## Live identity and state

- App **6831008730**, bundle **com.saphid.duotwitch**, resolved live by bundle ID.
- iOS App Store **1.0**, version ID **fa4b6291-c62c-4b78-b4fc-54f8ac528bc6**, **PREPARE_FOR_SUBMISSION**. Build **1.0 (202611080727)** is attached; no App Review submission yet.
- Changed releaseType from AFTER_APPROVAL to **MANUAL** and verified live. Preserve MANUAL in every later readback; never call release.
- Build ID **7a460d32-7c81-48d9-9a4c-a2e851560e13** is **VALID / APP_STORE_ELIGIBLE**, with non-exempt encryption false. Its prerelease relationship confirms **1.0 / IOS**. The eight older processed builds are INTERNAL_ONLY; **0.1.0 (202611060726)** remains the current internal beta.
- Fresh live receipt `resume-state.json` records the exact app/version/build relationship and MANUAL release at **2026-11-08T07:39:32Z**; source API responses are `resume-{app,version,build}-readback.json`.
- Apple accepted and read back public name **Saphid Duo Viewer** and subtitle **Live streams and flexible chat**. The shorter on-device name is Duo Viewer. Twitch trademark guidelines prohibit incorporating Twitch in app names without express permission; bundle/repo/module identity remains unchanged. The first alternative, Duo Viewer, was already taken on Apple.
- Entertainment category, third-party-content declaration, copyright and source-backed listing text saved. Initial free price schedule and Australia-only availability created, automatic new-territory expansion off. These are initial submission settings; no existing price was changed and no paid/legal agreement was accepted.
- Age questionnaire saved for Twitch UGC/ads/chat; live legacy rating **17+**, France/Brazil **18**. Initial prolonged-graphic-violence answer produced UNRATED; corrected to NONE for prohibited extreme/sadistic material, while retaining frequent realistic/cartoon violence, weapons, profanity and mature themes. This is a questionnaire answer, not a guarantee that Twitch UGC has no violations. Review this assumption before final submission.

## Current source candidate

Executable candidate committed and pushed on `app-store-approval-20261108` at [029339d](https://github.com/saphid/duotwitch/commit/029339df86e87f4347aac2193f3c8abb15e37d8a). Marketing version **1.0**; signed archive build **202611080727**, exported with **testFlightInternalTestingOnly=false**. Later checkpoint-only documentation commits do not alter this executable candidate.

- Native privacy/support links available in Account before sign-in.
- Long-press chat report sheet opens a user-sent email draft; no report sent during development. Local user blocking removes displayed/pending messages, hides later messages, persists across relaunch, and can be undone in Account. Sign-out clears saved block entries. This does not change Twitch’s account block list.
- Guest channel-name navigation uses the official Twitch embed without a native account. Discovery/following/chat still require Twitch authorization. Real broadcaster ID lookup occurs after sign-in. Multiple unresolved guest channels are distinguished by login, not their empty numeric IDs.
- Added required-reason manifest for app preferences and elapsed-time measurement. Local diagnostics use time since the app diagnostic run began; automatic upload projection zeros uptime. Canonical validation rejects old queued records containing raw device uptime. No receiver or shared network route was changed.
- Public support/privacy source in `web-site/`; supporting Pages commits submitted using the Contents API, touching only `apps/duotwitch/`. Shared local website checkout had unrelated changes and was left untouched. Pages deployment completed at [21711ff](https://github.com/saphid/saphid.github.io/commit/21711ff9c87dbf8a6294510bf08d5fc32bbbe346). Exact-byte HTTPS readback succeeded for [support](https://saphid.app/apps/duotwitch/) and [privacy](https://saphid.app/apps/duotwitch/privacy/); hashes and byte lengths are in `site-http-readback.json`.

## Verification

Evidence root: `build/app-store-approval-20261108/` (ignored; contains protected private contact/auth artifacts—do not upload the whole directory).

- `guest-final-tests.xcresult`, summary and actual exit agree: **119 passed, 0 failed, 0 skipped; exit0**, runtimeWarnings empty. This includes chat safety and guest identity regressions. Earlier39-focused/118-full results are preceding-candidate evidence.
- `simulator/DuoTwitch.app`: exact bundle com.saphid.duotwitch, display Duo Viewer, version1.0, registered public client and owned player origin; strict/deep codesign passes and PrivacyInfo.xcprivacy is bundled.
- `node scripts/test-silent-play.mjs`:6 public-API fail-closed mute cases pass. `isolated-upload-tests.log` and exit: uploader tests pass; these overlap the Simulator suite, not additional distinct tests.
- Xcode wrapper uses private temporary DerivedData with owned cleanup.49GiB was available; the host’s50GiB reserve initially deferred the run. A deliberate20GiB task floor was then used; no shared caches or other jobs were removed. Sibling Frame Control/Duocord build locks were preserved.
- Opus independent review attempt **350ce52f-8746-44d6-8211-808c2c708bb3**, provider **claudeAgent**, model **claude-opus-5-5**, high, final **failed**: Claude API rate limit reached. **No independent review occurred; no findings returned.** Receipt `independent-review-attempt.json`. A second attempt covering the final119-test guest candidate, task **01e795f8-cd53-4403-9941-66844e711681**, same provider/model/high, also failed from the Claude API rate limit with no review or findings. Receipt `independent-review-final-attempt.json`. Continuing under the explicitly authorized best-effort exception.
- Current silent runtime, sustained changing video, authenticated chat/keyboard, physical Duo/fold and final screenshots remain unverified. Historical freezes/spontaneous Twitch Pause remain unresolved; do not transfer prior UI evidence to this candidate.
- Astra task **868aafe1-9a54-4a02-b648-31a930be270a**, Codex / **gpt-6-astra / high**, completed after a device-tool blocker. Exact **39/39 source hashes**, **13/13 bundle files**, strict/deep signature exit0 before/after; these are file checks only. `device_open` returned “No device 72007DD0-BEB6-4009-A64A-9FFE372AA22F on 'This machine' (hostId local). Call device_list for current ids.” Refresh and one retry returned the same error. **No install, launch, playback, screenshots, or installed-bundle verification.** Report/receipt: `proof/`. No other session was reused and no device-tool bypass attempted. Alex subsequently explicitly authorized the existing app-owned **DuoTwitch Playback Investigation**, local / **35246E77-9341-4D0D-9150-8A579EDFFF25**, preserving saved data. Fresh `device_list` confirms it is discoverable/booted and no Device panel session is open; a new bounded Astra pass may use that target.
- Signed archive/upload supervisor receipt is terminal success (archive, signature and upload exits0); upload resource COMPLETE, processed VALID, exact build attached. `archive-202611080727/` contains archive, logs and identity receipts. `validation-only-archive.ipa` packages unchanged signed archive contents for validation; it is **not** a retained copy of the originally uploaded IPA.
- Review contact and **2061-character** notes created and read back, review-detail ID **e97ea6d5-efaf-42aa-9fd1-199b3844123f**. Existing live contact reused without printing it; private receipts0600. Notes explain guest entry, Twitch-dependent features, safety/reporting, optional diagnostics and manual release. `demoAccountRequired=false`; no dedicated Twitch reviewer account or authenticated runtime coverage is claimed.
- `deep-validation.json`: **1 blocking error** (no screenshot sets), **1 warning** (no cached web session); MANUAL confirmed, App Privacy publication unverified. No other API-detectable blockers. Keyword overlap warnings resolved. This validation does not establish runtime readiness.

## Authentication and remaining work

A task-local ASC web cache was isolated under `apple-auth-private/session`; shared auth/config were not modified. The one private trusted-device code card timed out. Bounded login exited1 with no code supplied. That challenge was not reused. Public API-key reads/writes still work. After Alex returned, a second fresh challenge succeeded with private input. Isolated auth is true, passwordStored false; shared auth/config remain unchanged. Live catalog/pull now succeed. Current declaration is DATA_NOT_COLLECTED and **published=false**, so do not publish it. A live-token-validated incomplete draft and source-backed inventory are in [privacy preparation](APP_STORE_PRIVACY.md). Embedded-player collection/tracking assessment remains open; no accurate published label or completion is claimed.

- [x] Final independent review best effort attempted twice; both failed from Opus capacity. No independent review occurred.
- [ ] Current-candidate silent Simulator acceptance through Astra and device_list/device_open/agent-device/device_screenshot only; preserve Simulator data/Keychain/preferences. No desktop browser/physical-device authorization.
- [ ] Verify sustained visible video and recovery; investigate a repeatable failure before claiming readiness.
- [ ] Capture honest App Store screenshots from the exact candidate, with documented content rights and no personal accounts/data.
- [x] Exact live HTTPS support/privacy readback after Pages deployment.
- [ ] Resolve privacy inventory and embedded-player collection/tracking assessment in [privacy preparation](APP_STORE_PRIVACY.md); complete the live-token draft, plan/apply/publish accurate label in the now-authenticated isolated cache. No label has been published or claimed.
- [x] Create/read back review contact and accurate guest-route notes; keep private contact artifacts protected. No invented credentials or authenticated coverage.
- [x] Archive/sign/export/upload eligible1.0 build; attach after VALID processing; read back export/encryption/identity/build relationship.
- [ ] Re-run `asc review doctor`; resolve actual blockers, retain MANUAL, submit authorized review.
- [ ] Follow live review feedback and resubmit necessary fixes.
- [ ] Complete goal only on live approved state (e.g. PENDING_DEVELOPER_RELEASE) for the exact version/build, with a final evidence receipt.
