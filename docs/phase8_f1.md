# Phase 8 F1 foundation

Implemented 17 October 2026. No deployment or real provider/device verification.

## Contract provenance and activation

No applicable AGENTS.md was found in either workspace or its searched parents/subdirectories. The requested backend `docs/phase8_clerk_shared_contract.md` does not exist in the inspected backend checkout. The supplied `C:\Users\hp\Downloads\phase8_clerk_shared_contract.md` is explicitly an implementation proposal awaiting B1 freeze. It supplies route proposals and ticket, ready, ack and update examples; it does not freeze status, finish, error, observation or report wire schemas. This implementation is a reviewable F1 foundation, not confirmation that B1 or integration is complete.

`Phase8Service` is disabled by default. `--dart-define=PHASE8_CONTRACT_CONFIRMED=true` enables the proposed API calls only after backend agreement on the schemas below. Disabled calls throw a StateError before HTTP. Missing routes, authorization failures and malformed responses propagate as errors; there is no success fallback. No additional packages, auth store or refresh flow was added. The service defaults to ApiClient, which obtains the current Clerk SDK bearer token per request and rejects obsolete account responses. Injected clients and JSON fixtures are test seams only.

## Required B1 decisions / proposed contract additions

These names and shapes are client proposals requiring explicit backend agreement, **not frozen backend guarantees**:

| Surface | Proposed v1 schema beyond the attachment |
| --- | --- |
| analysis-status GET | `{session_id, status, video_state}`; status uses lower case analysis states; video_state carries the server lifecycle string |
| finish-video POST | Empty body; response uses the same schema as status, confirming admission sealing rather than final report completion |
| accepted socket error | `{type: "error", code: nonempty reason string}`; candidate UI displays generic transport feedback, never raw server messages |
| observation | `{type: nonempty label, started_at: UTC timestamp, duration_seconds: nullable finite nonnegative number}`; unknown labels are retained without inferring intent |
| coverage | Required `processed` and `valid_gaze` integer counts; optional nullable `unknown` count. Coverage denominator/unknown meanings must be frozen |
| behavioral-analysis GET | Revisioned full snapshot matching analysis.update (session_id, revision, server_ts, status, coverage, required observations array), plus counts, nullable centered_percentage, nullable finalization_reason/finalized_at and versions |
| counts | Required nonnegative integers received, admitted, processed, dropped, failed, expired. B1 must settle treatment of superseded admitted frames and ensure no double counting |
| versions | Object of string version labels (pipeline/model/rule expected from B1); expression summary and episode-count wire schemas remain deferred until measured fields are frozen |
| navigation identity | Internal typed route argument holds separate interviewId and sessionId. JSON conversion requires interview_id and interview_session_id; it is not an invented HTTP response |

The parser accepts only protocol v1 negotiated by ticket. Ready requires its own explicit version; ack, error and update may omit version because the attachment examples omit it. Any explicit incompatible version is rejected. Unknown event types become a typed unknown event; unknown analysis states remain unknown. Missing observations never silently become an empty list. Unknown optional object fields are ignored. Candidate publisher parsing rejects analysis.update before exposing observations. Ticket paths must match the requested local session and publisher/observer purpose exactly; ticket diagnostics are redacted.

Additional B1 decisions: observer ready shape (the foundation currently recognizes the attachment's ready shape), full snapshot versus delta semantics, timestamp formats, reason enums, maximum width/height, bounded event window/message sizes, authorization lease/renewal, expiry and takeover policy, retention, camera notice and expression-analysis policy. Later socket integration must subscribe then reconcile highest revisions and obtain a fresh ticket for every reconnect. No socket connection is implemented in F1.

## Inspected backend dependencies

`interview_system/urls.py` has no interview-sessions router for the four proposed Phase 8 HTTP routes. Existing `/api/interviews/{id}/start-voice-session/` is recruiter-owned, creates the local session and returns interview_session_id plus nullable retell_session_id. It does not expose a candidate session lookup, browser voice access token or video_required request mode. `InterviewSerializer` lists interview IDs but no local session ID. The frontend must never treat a Retell call ID or an interview ID as that session ID, nor invoke the recruiter start action as the candidate. B1 must define authorized session discovery/resumption and video-required start behavior before F2/F3/F4 integration. No backend files were edited.

Named lobby/session routes accept `InterviewSessionIdentity`. Missing session-route identity renders an explicit unavailable screen. The lobby fetches the existing candidate-owned interview list and matches an explicitly supplied interview ID; otherwise it shows an actual scheduled/live interview. It does not fabricate the missing session ID. Entry remains unavailable because F1 does not perform real camera, voice or socket checks. Existing mock session questions, waveform, camera-ready badge and fabricated completion/report navigation were replaced with an honest availability shell using existing colors, fonts and top bar.

## State and cleanup boundary

Camera, voice, frame socket and report states are independent. SessionScope now emits synchronous invalidation notifications from the existing AuthService cleanup path. InterviewSessionController clears status, notices and connection generation, cancels Dio requests, and invokes registered stop/close callbacks on invalidation or disposal. Every new resource attempt uses bind with its own resource key, invalidating callbacks from the previous attempt. Resource adapters must route all asynchronous callbacks (including disconnect) through bind and register stop/close callbacks that immediately stop local capture/admission. A disposed or invalidated controller cannot be reused. A network disconnect does not call finish-video, end voice or mark a report complete. F1 has no camera frame buffer, model output generation, capture, voice or WebSocket network implementation.

## Validation and manual follow-up

Fixtures live only in test/fixtures/phase8/v1.json. They include explicitly test-only credentials/version labels and are never imported by production code. Contract tests cover required identity, versions, no-evidence nulls, unknown optional fields, publisher privacy, API methods and Clerk token acquisition, unavailable endpoints, generation cleanup and reconnect/disposal fencing. Session tests exercise the actual AuthService signOut cleanup path and honest lobby/session rendering.

Manual browser checks **not performed**: real Clerk login/refresh/account switching, camera permission denial and track release, voice SDK access and audio teardown, real publisher/observer handshakes, ticket replay/expiry, reconnect leases/two-tab conflicts, packet loss, frame limits/backpressure, recruiter authorization/snapshot reconciliation, backend finalization and eventual report readiness. These require B1-B4 routes and a configured private analysis environment; mocked tests establish none of them.

## Actual check results (17 October 2026)

- Focused contract/lifecycle run: 8 passed.
- Combined F1 + recruiter navigation + scheduling run: 36 passed, 5 failed. All 11 F1 tests passed. Failures in the existing working-tree suites: `403 scheduling error is shown under the candidate row`, `400 scheduling validation stays inline with the row` (tap hit a different control and route `/recruiter/rankings` was not registered in the harness); `inline edits PATCH one field and validate phone locally` (missing AK avatar text); `Create Role reflows as the recruiter rail animates` (missing NEW JOB POSTING); `mobile menu exposes recruiter destinations` (missing recruiter-menu key). These files already had uncommitted changes when F1 began; this run does not establish their baseline. They were left unchanged.
- Scoped Flutter analysis across nine F1 source/test files: one warning, existing unused `_buildTopBar` in the lobby. Confirmed that declaration was already present in HEAD. No new analyzer diagnostics remain.
- Tracked-file whitespace check passed. Dart formatting applied to new models/services/session shell/tests; the existing main.dart changes were edited locally to preserve unrelated uncommitted work.
- Flutter required access to its installed SDK cache lockfile outside the workspace; validation succeeded with that access. No package additions, backend edits or deployment were performed.

Changed files for this milestone: `.gitignore` (narrow exceptions because test/ and *_test.dart were globally ignored), `lib/main.dart` (candidate route arguments only), `lib/models/phase8_contract.dart`, `lib/services/phase8_service.dart`, `lib/services/interview_session_controller.dart`, `lib/services/session_scope.dart`, `lib/screens/candidate/candidate_interview_lobby_screen.dart`, `lib/screens/candidate/candidate_interview_session_screen.dart`, `test/phase8_contract_test.dart`, `test/phase8_session_test.dart`, `test/fixtures/phase8/v1.json`, and this document. Other pre-existing modifications/deletions remain intact.
- Final focused rerun after the SessionScope notifier fix: **11 passed, 0 failed** (`flutter test --no-pub test/phase8_contract_test.dart test/phase8_session_test.dart`).
