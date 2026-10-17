# Phase 8 F3: candidate publisher transport

Implemented 18 October 2026 (Asia/Karachi). F1/F2 and unrelated uncommitted work were present before this milestone and preserved. No applicable AGENTS.md was found in the inspected workspace/source/test and parent locations. The requested backend `docs/phase8_clerk_shared_contract.md` remains absent in `C:\Users\hp\Downloads\SkillSense_backend`. The supplied Downloads contract is still marked as a proposal awaiting B1 freeze.

F3 adds a real, platform-isolated browser publisher socket and candidate transport controls. It does not deploy, implement inference, expose observations/scores, start voice, seal video, or finalize an interview/report. The existing Clerk-authenticated Phase8Service.ticket method and ApiClient SDK token supplier are reused unchanged. No login, token cache, refresh workflow, provider, auth store or package was added.

## Activation and required B1 contract additions

`PHASE8_CONTRACT_CONFIRMED` remains **false by default**. No ticket or socket attempt is made while disabled. After backend agreement, enable with `--dart-define=PHASE8_CONTRACT_CONFIRMED=true`. A live camera preview and explicit **Connect / retry frame transport** action are also required; reconnects do not silently reacquire camera permissions.

The proposal does not freeze an authorization lease envelope, orientation, independent width/height limits or error codes. The following are explicit **required contract changes**, not assertions about implemented backend behavior:

```json
{
  "type": "ready",
  "protocol_version": 1,
  "connection_generation": "unique-server-issued-generation",
  "target_fps": 3,
  "max_message_bytes": 307200,
  "max_jpeg_bytes": 204800,
  "max_pixels": 921600,
  "max_width": 640,
  "max_height": 480,
  "frame_orientation": "unmirrored_browser_video",
  "authorization_expires_at": "2026-10-18T10:05:00Z"
}
```

Ready parsing remains compatible with the original F1 proposal, but **F3 will not transmit without all four additions**: max_width, max_height, frame_orientation and authorization_expires_at. Width/height must be positive integers. Orientation must confirm the F2 convention: CSS-mirrored preview, unmirrored browser-decoded JPEG pixels, no additional rotation/crop. The UTC authorization expiry must leave more time than the configured renewal lead. Ticket expires_at is only a redemption deadline and is never reused as an established socket lease.

Proposed accepted-socket error envelope remains `{type: "error", code: "..."}`. Required B1 code agreement:

| Code | Client action |
| --- | --- |
| authorization_expired, authorization_renewal_required | Stop admission/output and attempt bounded recovery with a fresh Clerk-authenticated ticket |
| permission_denied, account_inactive | Terminal transport state; ask user to check authorization |
| session_ended, session_ineligible | Terminal transport state; no client finish request or assumption of report readiness |
| publisher_conflict | Terminal transport state; check other tabs |
| capacity, temporarily_unavailable | Bounded recovery |
| Unknown code | Terminal unsupported-protocol feedback; never reflect arbitrary server text |

B1 must confirm status/error meanings, clock tolerance, lease binding to verified Clerk credentials, server grace policy, generation uniqueness, replay rejection and account/revocation enforcement. Client reconnect is not a substitute for server enforcement. Raw ticket query parameters must be redacted in proxy/APM/server logs; ticket HTTP responses must use no-store. No endpoints were added or renamed.

## Protocol and state behavior

- Each connection attempt obtains a new publisher ticket through the existing Clerk HTTP client. The SDK token supplier runs for each request, including proactive renewal. HTTP 401 is terminal after that normal SDK path and offers sign-in recovery; there is no second refresh mechanism.
- The socket uses the returned canonical session path on the same configured backend authority, with an encoded ticket query parameter. It cannot use a ticket-supplied arbitrary origin. HTTPS maps to WSS; HTTP is allowed only for localhost/loopback. An HTTPS page cannot open the HTTP/WS configuration.
- The current application API base remains the existing ApiClient.baseUrl (localhost in this checkout). A real HTTPS deployment must configure the existing API client consistently; F3 does not introduce a second independent socket host setting. The optional URI constructor argument is an integration/test seam, not a ticket-controlled destination.
- Ready/limits must precede every transmission. Each connection uses the server-issued generation, starts sequence at zero, and increments only for an attempted send. An immediate repeated generation is rejected; the backend must guarantee uniqueness across all generations. Sequence is never reset by a drop, error, buffer skip or duplicate acknowledgement. Reconnection requires a new ready/generation. The frame JSON is exactly the supplied v1 shape: type, protocol_version, sequence, capture_ts, data. Generation is connection context rather than an invented frame field.
- A maximum of one outstanding acknowledgement is tracked, with constant-size metadata only. A matching accepted ack means **admitted for processing**, not analyzed/durably reported. A dropped ack is counted separately. Duplicate/late old acknowledgements are ignored; acknowledgements for unsent future sequences fail closed. Wrong-generation acknowledgements cannot release the current pending slot.
- Binary, oversized, malformed, incompatible-version or restricted recruiter messages stop transmission. Unknown optional event types after ready are ignored; unknown optional JSON fields are tolerated. Missing required limits/identity are never filled with successful-looking defaults.
- The candidate UI displays sent/admitted/server-dropped/local-skipped transport totals and health, with live-region status text. These are transport counts, not observations, behavioral scores, coverage or report readiness. Media-panel copy distinguishes local test samples from separately enabled private-backend frame transmission.

## Bounds and policy configuration

PublisherPolicy is a typed constructor configuration; the UI uses these defaults:

| Policy | Default |
| --- | --- |
| Additional reconnect attempts | 5; initial attempt plus at most five retries before explicit user action |
| Backoff ceiling | 500 ms times 2^retry, capped at 15 s |
| Jitter | Uniform 50%-100% of the current ceiling using Random.secure; capped after jitter |
| Recovery scheduling window | 60 s from the first recoverable failure; delayed retry callbacks recheck it |
| Ticket-response and ready timeouts | 10 s each; a ticket timeout cancels its HTTP request and fences late results |
| Frame admission ack timeout | 10 s |
| Maximum local authorization lease | 5 minutes, capped further by the explicit server expiry |
| Renewal lead | 5 seconds before the effective lease deadline |
| Maximum local frame age | 1 s; future/stale timestamps are rejected |
| Outbound socket budget | 262,144 bytes |
| Incoming publisher event budget | 16,384 UTF-8 bytes |

F2 capture settings remain in force: default 640x480, 307,200 pixels, 100,000 JPEG bytes, quality 0.75 and `CAMERA_CAPTURE_INTERVAL_MS=500`. Server width/height, pixel/JPEG/message ceilings and target FPS further restrict these defaults. Exact serialized UTF-8 frame size is checked against both server max_message_bytes and the local socket budget after base64 encoding.

The sampler checks a canCapture admission predicate **before encoding and again before delivery**. The controller rechecks account, attempt epoch, camera availability, socket readiness, buffer, lease and freshness immediately before send. While an ack is pending or browser bufferedAmount is nonzero, current opportunities are skipped without encoding. There is no frame queue and nothing to replay after recovery. Browser buffer growth is checked before send; if bufferedAmount is unavailable, the one-pending-ack rule and per-message cap still bound application output. Native publishing is explicitly unsupported rather than simulated.

Backoff does not reset merely on ready: it resets after a valid accepted acknowledgement demonstrates useful progress. Thus a server repeatedly accepting a handshake and immediately closing cannot create an unlimited fast loop. HTTP 429/5xx/network failures use the bounded backoff; HTTP 4xx other than 429 terminate with safe, human-readable status-based feedback. A generic socket error/close never claims credentials expired: the next HTTP ticket response, a recognized accepted-socket error, or exhausted recovery determines the user-facing action. Retry-After header scheduling is not implemented; retries remain capped.

Browser WebSocket close cannot recall bytes already handed to the browser/network. Logout stops new sends, cancels capture scheduling and closes the socket, but server permission/generation/lease checks must reject any already-in-flight stale work. No client-only immediate server revocation guarantee is made. See [MDN bufferedAmount](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/bufferedAmount) and [MDN WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket).

## Cleanup and lifecycle

Attempt epochs fence socket messages, disconnects, ticket futures, lease/handshake/ack/retry timers and encoded frame callbacks. SessionScope invalidation additionally fences account changes and clears session-specific transport counters and credentials. Replacing the screen's interview/session identity disposes the old publisher before constructing the new one; keyed panels recreate preview/transport ownership for the new controller.

Camera stop/backgrounding pauses transport. Route coverage, pop, deactivation, logout and disposal cancel requests/timers, stop the sampler, and close the current socket. Returning from a covered route requires explicit restart. Ordinary socket disconnect leaves local camera, voice state and report state independent and attempts bounded recovery while camera remains available.

The publisher has **no finish-video call**. Ordinary disconnects, lease renewal, pauses and transient navigation disposal never seal admission or mark the interview/report complete. Explicit end coordination remains separate future work through the existing finish-video service; server grace expiry is a server decision and appears only as an explicit terminal transport/session response.

## Integration dependencies and limitations

1. B1 must freeze the additions above and expose the proposed ticket and publisher WS routes. The inspected backend lacks these routes and candidate session discovery/resumption. Feature activation remains blocked by that agreement, not hidden behind fixtures.
2. B3/B4 must enforce one-use tickets, ownership/purpose, generations, account/Clerk lease policy, frame validation, bounded admission and finalization/grace semantics on the private backend. HTTP success does not prove a real socket/model/report pipeline exists.
3. HTTPS/WSS reverse proxy routing, origin policy, query redaction, timeout/size controls and clock tolerance need deployment validation. Current localhost API configuration is for local use.
4. F4 owns the actual voice SDK; no audio is routed through this publisher. Report fetching/readiness is unchanged.
5. Idle liveness heartbeats are not invented because their schema is unfrozen. ACK timeout detects stalled active admission and proactive lease renewal bounds connections; neither proves an idle network path is healthy. F2's unresolved encoder-callback limitation remains.

## Changed files in F3

- `.gitignore`: include the publisher test and its test-only fixture.
- `lib/models/phase8_contract.dart`: typed optional ready additions, mandatory at the F3 send boundary.
- `lib/services/publisher/publisher_socket.dart`, `publisher_socket_factory.dart`, `publisher_socket_stub.dart`, `publisher_socket_web.dart`: isolated real browser socket port and explicit native unsupported behavior.
- `lib/services/publisher/candidate_publisher_controller.dart`: ticket/handshake/admission, limits, retry/lease, cleanup and callback fencing.
- `lib/services/media/bounded_frame_sampler.dart`: admission predicate before encoding/delivery.
- `lib/services/media/interview_media_controller.dart`, `lib/widgets/interview_media_panel.dart`: clarify which local sample checks upload nothing while transport may run separately.
- `lib/widgets/candidate_publisher_panel.dart`: candidate-only health/actions plus route/app lifecycle cleanup.
- `lib/screens/candidate/candidate_interview_session_screen.dart`: wire real session identity/media into the publisher and recreate ownership on identity changes.
- `test/phase8_publisher_test.dart`, `test/fixtures/phase8/publisher_fixtures.dart`: test-only ports/payloads and reliability tests; no production fixture fallback.
- `docs/phase8_f3.md`: this handoff. Prior milestones and unrelated modifications remain preserved.

## Manual checks not performed

No real Clerk token/provider/revocation checks, one-use backend redemption, camera-to-private-backend frame transmission, actual server ACKs/admission, WebSocket lease enforcement, network/proxy interruptions, two-tab conflicts, browser buffer behavior, camera permissions/device teardown, server grace expiry, finalization or model/report verification were performed. Chrome/Safari/Firefox/mobile manual checks and full native application builds were not performed. The earlier browser-test runner limitation is recorded in phase8_f2.md; F3 does not claim it was resolved. No deployment occurred.

## Actual validation results

- **54 passed, 0 failed**: `flutter test --no-pub test/phase8_contract_test.dart test/phase8_session_test.dart test/phase8_media_test.dart test/phase8_publisher_test.dart`. This includes 25 F1/F2 regression checks and 29 F3 checks for handshake gating, exact v1 serialization, sequence/generation changes, accepted/dropped distinction, buffer pressure and unknown buffer fallback, acknowledgement timeout, capped jitter retries, fresh/reused/expired tickets, HTTP 403/401/429 behavior, current Clerk token acquisition at renewal, malformed/restricted messages, late encoding/tickets/events across stop/logout/disposal/session replacement, server authorization/session expiry, no finish-video calls, and route cleanup.
- **No issues found** in scoped analysis of all F3-modified source/tests (publisher directory, shared contract, sampler/media controller, both relevant panels, session screen, publisher tests and fixture).
- **Web debug build passed**: `flutter build web --debug --no-pub --no-web-resources-cdn`; Flutter also reported a successful Wasm dry run. This is a compilation result, not real socket, camera, Clerk, backend or provider verification. The build used default disabled feature configuration and was not deployed.
- Formatting and tracked-file whitespace checks passed. Test/fixture allowlist entries keep the new tests reviewable despite the repository's general test ignore rules.
- Initial test-only issues were corrected: harness cleanup had to run before Flutter's pending-timer invariant, assertions were moved out of the mock request interceptor, and the renewal test now isolates lease timing from the separate ACK timeout. No failing checks are omitted from the history; the final complete suite passed.
- Broader recruiter suites and browser runtime tests were not rerun for F3. Native stub behavior is covered by VM tests; full native builds and all manual browser/backend acceptance checks above remain unperformed.
