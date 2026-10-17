# Phase 8 F2: local browser media

Implemented 17 October 2026. This milestone adds local camera preview, microphone permission/track checks, and bounded JPEG capture. It does not connect a publisher socket, upload images, invoke a model/provider, start Retell audio, or complete an interview.

## Repository and contract inspection

Current git status was inspected before edits. F1 and substantial unrelated uncommitted work were present and preserved. No applicable AGENTS.md was found in the inspected workspace/parent paths or relevant source/test trees. The requested backend `docs/phase8_clerk_shared_contract.md` remains absent in `C:\Users\hp\Downloads\SkillSense_backend`. The supplied `C:\Users\hp\Downloads\phase8_clerk_shared_contract.md` remains a proposal awaiting B1 freeze; its JPEG, pixel, FPS and message limits informed the capture boundary. No backend files or endpoints were added, and Clerk/ApiClient authentication was unchanged.

## UI and readiness

The lobby requests devices only after explicit button actions. Camera readiness requires permission, an enabled, live, unmuted video track, successful playback and nonzero decoded video dimensions. A mirrored local preview displays that stream. Track mute/end makes sampling unavailable and requires an explicit restart. Camera selection uses deduplicated, nonempty device IDs after permission where browser policy permits enumeration. Selection changes release the previous camera before acquisition.

Microphone checking requests audio only, verifies an enabled, live, unmuted audio track, and releases every track in a finally block. It does not record speech, verify audible signal quality, retain an audio stream, or claim voice-provider readiness. The UI states this explicitly. F4 must call `handoffToVoice()` before SDK acquisition and `voiceReleasedMicrophone()` after SDK teardown; local microphone checks are disabled while the voice client owns audio. Handoff stops all local test media first. No Retell SDK is introduced by F2.

Lobby entry requires actual camera readiness, a completed microphone permission/track check, and a real backend session identity. Voice and frame transport availability remain separate; the session does not imply that either is connected. Lobby streams are released before navigation; the session requests its own camera from another explicit action. Camera checks can run locally even while B1 session discovery is unavailable.

The shared panel uses labeled standard keyboard-accessible buttons and a labeled device selector, with live-region status/error text. Denied permissions, missing devices, contention/OS failures, constraint failures, insecure origins, interrupted tracks, backgrounding, and unsupported targets have distinct useful recovery text. A browser permission prompt cannot be cancelled programmatically: cancellation fences its result and stops all tracks if a grant arrives later. A pending prompt must be allowed or dismissed before another request for that device can start. No permission acquisition timeout is used that could leak a late granted stream.

## Capture limits and backpressure

| Setting | Default / behavior |
| --- | --- |
| Camera acquisition | Video only; ideal 640x480 at 15 FPS, maximum requested 1280x720 at 30 FPS; browser still must grant/produce the stream |
| Encoded frame | At most 640x480 and 307,200 pixels; preserve aspect ratio, never upscale |
| JPEG | Quality 0.75; maximum 100,000 JPEG bytes; reject rather than retry/queue an oversize sample |
| Local message budget | 150,000 bytes by default; account for base64 expansion plus a conservative 512-byte envelope reserve |
| Sampling interval | `--dart-define=CAMERA_CAPTURE_INTERVAL_MS=500`; sampler rejects nonpositive values at start |
| Negotiated limits | `CaptureLimits.fromReady` takes the minimum of local defaults and server max_pixels/max_jpeg_bytes/target_fps, uses server max_message_bytes, and accepts explicit width/height ceilings |

`WebCameraAdapter.encodeJpeg` draws a resized video image onto a bounded canvas before calling asynchronous toBlob. Only one encode operation can be in flight on an adapter, including across stop/restart. No timeout releases that guard while browser encoding is still pending. The sampler independently permits at most one encode/delivery operation, drops ticks while busy and validates sample size/dimensions/freshness. There is no frame queue. Canvas storage is cleared after encoding and stale results are discarded. F3 must validate the exact serialized WebSocket message size immediately before sending; the reserve is not proof of an arbitrary envelope's size.

The panel's local sample action encodes one JPEG, discards the bytes, and shows transport-neutral feedback. No images are sent to a network endpoint, voice client, hosted API, analytics or logs. Repeated sampling is exposed as a service boundary for F3 and is not started by the UI before a real socket negotiates limits. Test-only frames/streams exist exclusively under test/.

## Image orientation: agreement required before transport

The preview uses CSS `scaleX(-1)` for familiar self-view. The encoding canvas applies **no horizontal flip and no additional rotation**: JPEGs use the browser-decoded video orientation with the same aspect ratio and no crop. Preview mirroring never changes the canvas pixels. B1/private vision must confirm this unmirrored transmitted convention, along with independent maximum width/height, before F3 sends a frame. The supplied proposal does not freeze those fields. No claim of bilateral agreement or real vision verification is made.

## Cleanup, lifecycle and platform behavior

`InterviewMediaController` owns local device state and a sampler, separately from F1 voice/socket/report state. Existing SessionScope invalidation stops media synchronously on logout/account change. Device acquisition, local sample results and sampler callbacks are fenced by generations. Stop/disposal releases held tracks, detaches preview sources, cancels timers, and rejects late results. A pending browser promise may remain unresolved until the user answers it, but a late stream is stopped before use. Local stop is also the release boundary for a future explicit-finish flow; server finish/finalization coordination remains outside F2.

A registered RouteObserver stops devices when another route covers the flow, in addition to pop, deactivation and disposal. Hidden/paused/detached app states and browser visibilitychange/pagehide stop local media. Mere inactive/focus changes are excluded because permission UI can cause them. Returning to the page never silently reacquires devices or emits cached frames; the user restarts the check. Network disconnect does not end the interview.

DOM code is isolated behind a conditional factory using the existing package:web dependency. Native targets compile against an explicit unsupported adapter, never synthetic readiness. Full native application builds were not performed. No dependency or permission-manifest changes were required.

## Integration dependencies and limitations

- B1: candidate-owned local session discovery/resumption, confirmed schema, camera notice/acknowledgement policy, negotiated width/height and orientation, limits, lease and privacy/retention decisions. The F1 `PHASE8_CONTRACT_CONFIRMED` flag remains false by default and is independent of local device checks.
- F3: real socket readiness, exact message envelope validation, ticket renewal and send backpressure. The sampler consumer must check the current generation at the actual send boundary.
- F4: actual voice SDK microphone ownership, live audio quality/metering and teardown coordination. A microphone permission check is not an audible-signal test or voice readiness.
- Browser policy/OS: HTTPS or localhost, enabled devices, permission/iframe policy and autoplay behavior. Safari/Firefox/mobile differences require real checks.
- An unresolved browser JPEG callback intentionally blocks further encodes on that adapter, preserving the one-operation bound; restarting the entire flow is the recovery if a browser never calls back.

## Manual browser acceptance not performed

No physical camera/microphone permission, denial/recovery, device-in-use, unplugging, camera switching, camera-indicator release, real Clerk login/logout, Safari/Firefox/mobile preview, screen-reader/keyboard audit, hidden-tab hardware behavior, or provider verification was performed. No real camera frames were captured during automated checks. Browser adapter tests use injected or canvas-generated streams only. Production acceptance must use HTTPS or localhost and record these checks separately.

## Changed files for F2

- `.gitignore`: narrowly include the two new media test files.
- `lib/main.dart`: register the media route observer alongside existing navigation behavior.
- `lib/services/media/camera_adapter.dart`, `camera_adapter_factory.dart`, `camera_adapter_stub.dart`, `camera_adapter_web.dart`: platform interface, errors, limits and real web implementation.
- `lib/services/media/bounded_frame_sampler.dart`, `interview_media_controller.dart`, `interview_media_route_observer.dart`: bounded scheduling, local state/lifecycle and cleanup boundary.
- `lib/widgets/interview_media_panel.dart`: preview, explicit device actions and accessible feedback.
- `lib/screens/candidate/candidate_interview_lobby_screen.dart`, `candidate_interview_session_screen.dart`: real local media integration and released-device handoff.
- `test/phase8_media_test.dart`, `test/phase8_media_browser_test.dart`: test-only adapter/lifecycle/encoding checks; `test/phase8_session_test.dart`: update F1 expectations for the real media panel.
- `docs/phase8_f2.md`: this handoff. Prior F1 notes remain historical.

## Actual check results

- Final focused command: `flutter test --no-pub test/phase8_contract_test.dart test/phase8_session_test.dart test/phase8_media_test.dart`. The completed run passed **25 tests, 0 failures** (11 existing F1 checks plus 14 F2 checks). This covers limit math, explicit native unsupported behavior, useful browser error mappings, user-triggered acquisition, local sample discard, voice microphone ownership, late grants after cancel/logout/disposal, permission failures, one operation in flight across restart, slow-consumer backpressure, stale/oversize drops, route cover cleanup, active-device logout, lobby gating and release before handoff.
- Scoped Flutter analysis includes all media files, panel, lobby/session, main.dart and three relevant test files. Only the existing unused `_buildTopBar` declaration in the lobby remains; no new diagnostics were reported.
- Dart formatting and tracked-file whitespace checks were run. No package additions, backend changes or deployment occurred.
- Browser suite: `flutter test --no-pub --platform chrome test/phase8_media_browser_test.dart` was **not successfully completed**. The bundled Flutter snapshot referenced a missing archive/build-machine path for `test-1.26.2/.../host.dart.js`. Running the installed Flutter tool source avoided that initial path error but remained at test loading; the run was cancelled. No browser test assertions are claimed as passed. The browser-only tests are retained for a working runner and cover late grants, microphone stream release, DOM error mapping, canvas-stream JPEG resize/encoding and track stop. They use no real hardware.
- Initial attempts are not hidden: a browser test outside test/ failed import resolution and was moved to the standard test directory; an F1 widget assertion initially matched both the summary and panel and was made specific. The subsequent 25-test run passed.
- The broader recruiter navigation/scheduling suites were not rerun for F2. Their earlier F1 failures remain documented in phase8_f1.md; unrelated working-tree changes were preserved.

Browser API reference used for secure-origin, permission and error behavior: [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia).
