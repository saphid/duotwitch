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

## Existing-simulator attempt and remaining runtime boundary

Astra task **55745e97-e34b-47c2-92b1-49baa62b1467** completed after a tool-ownership blocker, actual provider **codex**, model **gpt-6-astra**, actual effort **medium** (not the requested high). `target.options` was empty; refreshed capabilities identify the required next-run setting as **reasoningEffort=high**. No high-effort runtime claim is made. A further pass must specify that option explicitly and must wait for the owning session to release the device.

The target panel opened, candidate installed in place, and candidate/installed exact13-file sets, hashes, identities and strict/deep signatures matched; all39source hashes matched before/after. The pinned launch with the silent argument failed before launch:

> Error (DEVICE_IN_USE): the authorized iOS simulator is owned by another session.

This is a sanitized summary; the exact owning session/workspace and full error are preserved in the app-local runtime report. The owner belongs to a different project; do not publish its session details or interfere with it.

The advised `device status` also failed because that command reads local claims and is unavailable through the pinned host command. The task stopped, left the owner's claim untouched, restored/verifiably matched **744/744** saved preference files (including correcting for app-container relocation), and closed its own panel without shutdown. No app launch, playback, silent-gate proof, recording or screenshots occurred. Runtime/media readiness remains unproven. Evidence: `proof-existing-simulator/report.md`, `receipt.json`, `preference-final.json`; private preference backups must remain local. No task remains running from this pass. Do not bypass the repeated device-tool failure with direct simctl/SSH UI or close/reuse the other session.

[Current Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) require an iPhone Dynamic Island **medium-display** screenshot; iPhone18Pro is explicitly listed, with1179×2556 or1206×2622 portrait sizes (and corresponding landscape). Thus the authorized existing target is a suitable device class; still verify actual captured dimensions/slot delivery. The signed archive has UIDeviceFamily **[1]** (iPhone only), so iPad screenshots are not required. No screenshot was generated or uploaded. Official source fetches are in `privacy-research/metadata-source-readback.json`.

Fresh `age-rating-final-audit.json` confirms prohibited graphic-sex/prolonged-sadistic-violence answers NONE, frequent realistic/cartoon violence, weapons, profanity/mature themes, and no native parental-control/age-assurance claim. The [Apple definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) and [Twitch Community Guidelines](https://safety.twitch.tv/articles/en_US/Knowledge/Community-Guidelines) were reviewed. Twitch prohibits content focused on extreme/gratuitous gore and violence; this supports the intended content-policy distinction, not a guarantee about every UGC violation. No answer was changed during this audit, and final submission still needs a truthful platform-content assessment.

## Authenticated readiness follow-up

`deep-validation-authenticated.json` now confirms **2 blocking errors**: screenshots missing and **App Privacy unpublished**; release MANUAL remains verified. No subscriptions exist. The agreement warning was inspected with `asc web agreements status --developer-team NJZUMEA4BN`: both visible Developer agreements are active/accepted and no pending agreement ID is identified. The ASC contract message is the **EU trader-status** notice. Current app availability is Australia-only; do not invent an unpaid agreement blocker or accept/reaccept a legal contract. Protected source receipt: `apple-auth-private/agreements-status.json`. EU availability/compliance is outside the present territory setup.

## Authentication and remaining work

A task-local ASC web cache was isolated under `apple-auth-private/session`; shared auth/config were not modified. The one private trusted-device code card timed out. Bounded login exited1 with no code supplied. That challenge was not reused. Public API-key reads/writes still work. After Alex returned, a second fresh challenge succeeded with private input. Isolated auth is true, passwordStored false; shared auth/config remain unchanged. Live catalog/pull now succeed. Current declaration is DATA_NOT_COLLECTED and **published=false**, so do not publish it. A live-token-validated incomplete draft and source-backed inventory are in [privacy preparation](APP_STORE_PRIVACY.md). Embedded-player collection/tracking assessment remains open; no accurate published label or completion is claimed.

- [x] Final independent review best effort attempted twice; both failed from Opus capacity. No independent review occurred.
- [ ] Owning session must release the conflicting existing-simulator claim before further runtime attempts. Do not close/reuse it or bypass the tool failure. Then run Astra with explicit reasoningEffort=high through device_list/device_open/agent-device/device_screenshot; preserve data/Keychain/preferences. No desktop-browser/physical-device authorization.
- [ ] Verify sustained visible video and recovery; investigate a repeatable failure before claiming readiness.
- [ ] Capture honest App Store screenshots from the exact candidate, with documented content rights and no personal accounts/data.
- [x] Exact live HTTPS support/privacy readback after Pages deployment.
- [ ] Resolve privacy inventory and embedded-player collection/tracking assessment in [privacy preparation](APP_STORE_PRIVACY.md); complete the live-token draft, plan/apply/publish accurate label in the now-authenticated isolated cache. No label has been published or claimed.
- [x] Create/read back review contact and accurate guest-route notes; keep private contact artifacts protected. No invented credentials or authenticated coverage.
- [x] Archive/sign/export/upload eligible1.0 build; attach after VALID processing; read back export/encryption/identity/build relationship.
- [ ] Re-run `asc review doctor`; resolve actual blockers, retain MANUAL, submit authorized review.
- [ ] Follow live review feedback and resubmit necessary fixes.
- [ ] Complete goal only on live approved state (e.g. PENDING_DEVELOPER_RELEASE) for the exact version/build, with a final evidence receipt.
