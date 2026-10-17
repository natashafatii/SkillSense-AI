# Phase 8 F4: candidate voice and completion lifecycle

Implemented 18 October 2026. Existing uncommitted F1–F3 and unrelated application changes were preserved. No backend source was changed, no deployment was performed, and Clerk/ApiClient token refresh and account cleanup remain the only authentication mechanism. No applicable AGENTS.md was found in inspected parent, workspace, source, or test locations.

## Integration status: backend work is required

The requested backend `docs/phase8_clerk_shared_contract.md` is absent. `C:\Users\hp\Downloads\phase8_clerk_shared_contract.md` is a proposal awaiting B1 freeze, not an instruction to invent routes. Inspection of `interview_system/views.py`, `integrations/retell_client.py`, `retell_webhook.py`, and `session_completion.py` found:

* Candidate-authorized `GET /api/interviews/` and `GET /api/interviews/{id}/` exist. Retrieve includes approved/unapproved questions; the client filters approved questions. The separate questions action is recruiter-only and is not used.
* Existing `POST /api/interviews/{id}/start-voice-session/` is recruiter-owned. It returns `interview_session_id` and nullable `retell_session_id`, discards the provider access token, and does not accept/persist an explicit `video_required` input. Its current default session mode is audio-only.
* Candidate voice read, stop, sync, and session/credential recovery routes were not found. Candidate start permission was not found.

Consequently the real start/finish acceptance gate **has not been met** against this backend. Production shows an unavailable state, not fake credentials, a substitute provider call, guessed URLs, or successful-looking fixtures. Local device checks and existing audio-only routes remain supported. The new controller also supports authoritative `video_required:false` sessions without camera or video-finish requests.

## Required contract changes, not existing backend behavior

Freeze candidate permission and ownership rules, routes, schemas, error responses, and the following behavior before activation:

1. Extend the existing start action to authorize the candidate and validate/persist `{"video_required":true}` **before** creating an InterviewSession/provider call. Return the authoritative snapshot below. Keep false valid for audio-only callers. Make creation idempotent per interview, so uncertain HTTP responses and reloads do not produce duplicate provider calls.
2. Provide a candidate-owned read/discovery route that can resolve the existing session by interview ID after reload and return the same session/provider call identity. Session-specific reads must reject mismatches. Define expiry/rejoin policy: issue credentials only for the backend-selected existing call, never replace it silently. Specify `transport` explicitly; credentials are ephemeral and never persisted in client storage.
3. Provide an idempotent candidate stop control that durably records **explicit finish intent** and requests backend/provider termination. Require a response `{"session_id":"...","stop_requested":true}` only after that intent is accepted. This receipt is not proof that provider audio ended. Persist the intent even if provider termination must be retried server-side.
4. Provide a sync control that fetches trusted provider state/webhook completion and returns an authoritative snapshot. Neither client transcripts nor SDK call_ended events are completion evidence. Network interruption must not set finish intent. Specify genuine provider-driven end versus disconnect and server grace expiry explicitly.
5. Coordinate the F1 idempotent finish-video action, trusted audio-ended state, durable finish intent, and authoritative interview DONE state. Server grace expiry/recovery must remain possible when a browser disappears; there is no unload-only completion scheme. Expose report availability separately and increment a monotonic session revision for state changes.
6. Return human-readable candidate-safe HTTP auth/permission/session errors through the existing Clerk contract. Freeze F1–F3 ticket/limits/orientation/lease additions described in their handoffs as well.

Proposed start/read/sync snapshot (strict required fields; extra optional fields ignored):

```json
{
  "interview_id": "backend-interview-id",
  "interview_session_id": "backend-session-id",
  "revision": 1,
  "video_required": true,
  "video_sealed": false,
  "finish_requested": false,
  "interview_status": "LIVE",
  "audio_ended_at": null,
  "report_ready": false,
  "analysis_status": "processing",
  "retell_session_id": "backend-call-id",
  "provider": {
    "call_id": "backend-call-id",
    "access_token": "ephemeral-backend-issued-token",
    "transport": "gateway",
    "expires_at": "2026-10-18T12:00:00Z"
  }
}
```

`provider`, `retell_session_id`, `analysis_status`, and `audio_ended_at` may be null/absent. Provider credentials require a matching call ID, explicit gateway/livekit transport, and UTC expiry. LiveKit may include an optional secure `wss` URL without embedded credentials. Ended audio cannot also issue join credentials. A completed snapshot requires durable `finish_requested:true`, `interview_status:"DONE"`, a provider call ID, trusted audio_ended_at, and video sealing when required. Missing fields never become successful defaults. Report readiness does not follow implicitly from DONE. Align this proposal with the frozen backend schema before enabling; these names do not assert backend support.

## Configuration and SDK

All lifecycle calls use the existing Clerk-authenticated ApiClient; no login, refresh, password, JWT store, API key, or client provider-call creation was added.

* `PHASE8_CONTRACT_CONFIRMED` defaults false (existing F1 guard).
* `PHASE8_VOICE_READ_PATH`, `PHASE8_VOICE_STOP_PATH`, `PHASE8_VOICE_SYNC_PATH` default empty. Set only backend-frozen API-relative paths, with `{interview_id}` and optionally `{session_id}` placeholders. Read/discovery must also work when no session ID is known. Stop/sync may use session ID. There are intentionally no production route defaults.
* `PHASE8_CANDIDATE_START_AUTHORIZED` defaults false. Enable only after the existing start action actually supports candidate ownership and explicit video mode.
* Existing F2 `CAMERA_CAPTURE_INTERVAL_MS` and F3 ticket/limits/lease policy remain in force. Camera frames only enter the Phase 8 publisher, never the voice SDK, transcripts, logs, analytics, or hosted vision.
* HTTP/SDK deadlines are 20 seconds; completion/report polling is bounded to 12 attempts, two seconds apart. Timers cancel on logout/disposal and polling pauses on navigation/background. Retry/status remains available after bounded polling ends.

The locally bundled npm SDK is pinned to **retell-client-js-sdk 3.0.2**, with esbuild **0.28.2** and a lockfile. Official package source was checked on implementation day: [exports](https://github.com/RetellAI/retell-client-js-sdk/blob/main/src/index.ts), [compatibility client](https://github.com/RetellAI/retell-client-js-sdk/blob/main/src/legacy/retell-web-client.ts), [transport options](https://github.com/RetellAI/retell-client-js-sdk/blob/main/src/transport.ts), and [session events](https://github.com/RetellAI/retell-client-js-sdk/blob/main/src/session/events.ts). Installed package declarations were also inspected. Version 3.0.2 exports RetellWebClient.startCall/stopCall/startAudioPlayback and the supported call/talking/error events. This compatibility export is deprecated for removal in v4; it is pinned intentionally because it joins **backend-issued existing-call credentials**. The newer RetellClient.createWebCall creates a provider call and is not invoked. Migration requires a documented supported join-existing-call interface before updating the major version.

Rebuild bundle: `npm ci --prefix tooling/voice_sdk --ignore-scripts`, then `npm run build --prefix tooling/voice_sdk`. `web/index.html` loads the local ES module; missing SDK/module has an explicit unavailable state. No CDN or browser API key is required. Serving must include `web/vendor/skillsense_retell.mjs` with a JavaScript MIME type. Use HTTPS or localhost with provider network access, microphone permissions, and audio playback allowed. Native targets use the unsupported voice adapter while compiling the platform-neutral lifecycle.

## Behavior and ownership

The lobby releases test streams before start/rejoin. New video sessions explicitly request video mode, and navigation uses backend-issued interview/session identities. An uncertain start response blocks blind creation retry and offers existing-session lookup instead. Cancellation fences late responses and cancels HTTP work. Server idempotency remains required because cancellation cannot undo a server-side create.

The session uses real camera preview/F3 transport and approved backend question data. Provider audio controls the interview; the UI displays real provider connection/talking events and an approved-question count, not fabricated current-question progression, waveforms, or transcripts. No recruiter observations or behavioral scores are displayed. The SDK receives only an allowlisted audio join configuration. Local microphone tests release their tracks before Retell takes ownership; camera ownership remains independent.

Explicit finish immediately stops local provider audio, capture, and socket output. It independently requests backend voice stop and video sealing, retains acknowledged steps, and retries only missing controls. Double-clicks share one in-flight finish. Control receipts never cause optimistic completion/navigation. Authoritative DONE and report-processing/availability are separate UI states; no report contents are shown to the candidate. Unknown session mode is read before deciding whether video sealing is needed.

Provider error/call_ended stops local resources and syncs authoritative state. It never requests backend voice stop or video sealing merely because audio/network disconnected. A verified backend finish intent plus trusted audio end can trigger video sealing. Route coverage, backgrounding, disposal, and logout release local resources without a completion request. Rejoin is explicit, retrieves fresh backend credentials, and is fenced by account/session generation. Refreshing an active session releases its existing provider connection before rejoin. Lower revisions cannot revive an ended session or supply stale join credentials.

## Files in F4 scope

* Added `lib/models/voice/voice_contract.dart` and `lib/services/voice/{voice_lifecycle_backend,interview_lifecycle_controller,retell_voice_client,retell_voice_client_factory,retell_voice_client_stub,retell_voice_client_web}.dart`.
* Added `lib/widgets/interview_lifecycle_panel.dart`; updated candidate lobby/session screens.
* Updated `lib/services/media/{camera_adapter,camera_adapter_web,interview_media_controller}.dart` for independently cancellable microphone handoff.
* Added `tooling/voice_sdk/{package.json,package-lock.json,bridge.js,retell_entry.js,bridge.test.js}` and generated local `web/vendor/skillsense_retell.mjs`; updated `web/index.html` and `.gitignore`.
* Added `test/fixtures/phase8/voice_fixtures.dart`, `test/phase8_voice_test.dart`, and this handoff; updated `test/phase8_session_test.dart` for the new real-data HTTP boundary. Fixtures are imported only from test code and excluded from the production SDK entry/bundle. SDK sources/tests live under tooling, outside Flutter's copied web assets.

## Verification

Actual automated results:

* Full F1–F4 regression suite: **74 passed** across phase8_contract, phase8_session, phase8_media, phase8_publisher, and phase8_voice tests. This includes 20 voice contract/lifecycle tests.
* Focused voice suite after the final trusted-audio-end media lockout: **20 passed**. Audio-only explicit finish still records durable intent after unrequested audio end and never requests video sealing.
* Node bridge suite: **4 passed** (audio allowlist, no fabricated events, stale callbacks, late connect cleanup). Pinned esbuild bundle generation passed.
* Scoped analysis of new voice contracts, lifecycle, media, session UI, and test files: **no issues**. Including the lobby reports one pre-existing unused `_buildTopBar` warning; that broader analyzer command exits 1. No new analyzer issues remain.
* Debug web compilation passed with `flutter build web --debug --no-pub --no-web-resources-cdn --no-wasm-dry-run`. SDK sources, node_modules, and bridge tests are outside shipped web assets; only the generated module is copied.
* `git diff --check` passed for tracked F4 UI/index/test edits. Backend git status remained clean.

The initial regression run caught a lifecycle deadline surviving disposal. Cancellable deadline cleanup was added, and the session widget test now mocks its new approved-data HTTP boundary and drains Dio event-queue work. Earlier failures were corrected before the passing results above. Check logs are under `verification/phase8_f4_{tests,voice,analyze,analyze_new,build}.log` (the broader analyzer log intentionally records the existing warning).

Real provider calls, actual camera/microphone permissions/tracks, browser playback/autoplay recovery, token reissue/rejoin on a live provider call, live network/proxy interruption, real backend partial failures, webhook delivery, report generation, and physical native builds have **not** been verified. Prior F2 browser runner limitations are recorded in its handoff. Mock successes are not hardware/provider verification.

Manual acceptance still required after backend freeze: HTTPS/localhost permission acquisition and denial recovery; real preview and microphone handoff without a competing stream; accepted publisher traffic with agreed unmirrored pixels; audible Retell interview with real event-driven state; double-click/partial finish retry and separate report processing; reload/rejoin preserving session/call identity; provider error/network/background interruptions without automatic finish; logout/back-navigation releasing all tracks/sockets/audio; audio-only regression and native unsupported-state checks. Verify SDK stop during connect against actual hardware/browser as well as the automated bridge fixture.
