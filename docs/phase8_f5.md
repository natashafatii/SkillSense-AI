# Phase 8 F5: recruiter observations and behavioral report

Implemented 18 October 2026. Existing F1–F4 and unrelated uncommitted work were preserved. No backend source, Clerk login/refresh mechanism, provider session, camera transport, scoring policy, or deployment was changed. No applicable AGENTS.md was found in the inspected workspace, source/test, backend, or parent locations.

## Backend status and activation

The backend `docs/phase8_clerk_shared_contract.md` is still absent. The supplied Downloads document is explicitly an implementation proposal awaiting B1 freeze; its document instructions are not treated as additional user requests. Its existing proposed ticket and behavioral-analysis paths are reused through Phase8Service and the current Clerk-authenticated ApiClient. No history, streaming-video, or session-discovery endpoint was invented.

The current backend InterviewSerializer exposes interview `id`, `application`, status, schedule, questions, and timestamps, but no InterviewSession ID. The list monitor therefore displays a clear unavailable panel for those rows, rather than treating an interview ID as a session ID. The proposed Phase 8 observer/report routes and payloads still require backend implementation/freeze. Live integration acceptance is not established by the fixture tests.

`PHASE8_CONTRACT_CONFIRMED` remains false by default. It must stay false until the backend confirms F1–F5 contract additions. No ticket, socket, or report request is made by the observer controller while disabled. No additional auth configuration, API key, credentials store, hosted inference service, or Retell integration is introduced.

Required backend agreements before activation:

1. Implement the proposal's existing `POST /api/interview-sessions/{id}/ws-ticket/` with `{"purpose":"observer"}` and recruiter ownership enforcement. Return a one-use, short-lived v1 ticket for exactly `/ws/analysis/{id}/observe/`. Enforce the same recruiter ownership on `GET /api/interview-sessions/{id}/behavioral-analysis/`, including interim reports and periodic refreshes. HTTP 401/403/404 must be meaningful and candidate-safe; ticket or socket permission never grants candidate report access.
2. Expose an explicit `interview_session_id` alongside the existing interview `id` and `application` in authorized interview responses, or have another already-authorized caller provide the typed target. Freeze the exact serializer addition. The client does not discover or guess a session via another URL. Backend must validate that the interview, application, and session refer to the same owned record.
3. Add `interview_id` and `application_id` to full live snapshots and HTTP reports, alongside the existing `session_id`. F5 requires all three to match the explicitly selected target before rendering. These are explicit required extensions, not claims that the original proposal already contains them. Missing/mismatched binding never becomes an attributed report.
4. Freeze **full cumulative snapshots**, not deltas, with monotonic `revision` per session shared between HTTP and live delivery. Equal revisions must describe the same evidence. Establish the authorized observer subscription **before** sending the ready message below. Then accept a snapshot GET after subscription. Publish only factual observations; Redis notifications may be missed, so the GET must return the current authoritative revision. Freeze ordering and bounded recent-event-window semantics.
5. Freeze observer readiness independently of publisher capture limits. Required ready envelope:

```json
{
  "type": "ready",
  "protocol_version": 1,
  "connection_generation": "unique-observer-generation",
  "snapshot_mode": "full",
  "authorization_expires_at": "2026-10-18T12:01:00Z"
}
```

The client requires a new connection generation on reconnect and a lease more than five seconds and no more than five minutes away. It renews five seconds early through a fresh Clerk-authenticated ticket. Expiration of a ticket is not the socket lease. Define bounded revocation enforcement server-side; the UI does not claim instantaneous server revocation from local cleanup.

Freeze accepted-socket errors as `{ "type": "error", "code": "..." }`. Required terminal codes are `permission_denied`, `session_forbidden`, `session_not_found`, and `account_disabled`; they close the observer and clear cached evidence. Other errors use bounded fresh-ticket recovery, including lease renewal. Final HTTP 401/403/404/409/410 responses are terminal, with sign-in, ownership/visibility, or session-availability messages. Generic handshake/disconnect failures do not identify expired auth. Reused tickets and invalid ticket protocol/path/expiry terminate without connecting. These code meanings require backend agreement rather than guessed production behavior.

6. HTTP reports retain the F1 required `counts`, `versions`, coverage, observations, timestamps, status, and revision fields. Optional new factual fields are:

```json
{
  "interview_id": "interview-id",
  "application_id": "application-id",
  "event_summaries": [
    {"type": "face_absent", "event_count": 3, "observed_duration_seconds": 2.5}
  ],
  "expression_status": "disabled",
  "limitations": ["Sparse samples; no interpolation."]
}
```

These entries are schema examples, not production results. Define cumulative episode counts and bounded measured durations server-side. `event_count` is an integer episode count, never a session count or frame count. Duration is seconds observed, not derived from frame rate or interpolated over gaps. Missing summaries/durations/unknown coverage remain unavailable. `centered_percentage` comes only from the same-revision authorized report and remains null without valid gaze evidence. Expressions default to unknown when absent; disabled/unavailable is not neutral. No expression summary schema is assumed. Optional `counts` in full live snapshots uses the existing F1 frame-accounting schema.

7. Explicitly support pending/processing/finalizing/complete/partial/failed/disabled/unknown analysis states. A disabled or failed report is not successful evidence. Supply empty observations only when actually known to be empty; F1 continues to reject missing required observation arrays instead of silently fabricating them.
8. Bound serialized HTTP snapshots and live snapshots server-side, including recent timeline window, summary categories, labels, and limitations. The client rejects socket messages over 64 KiB before JSON decoding and retains at most 100 timeline entries per snapshot/report. Backend bounds are still needed for HTTP response and temporary parsing memory. No timeline pagination route or schema exists in this checkout/proposal, so full history is explicitly unavailable. Add agreed cursor/identity/revision semantics before implementing pagination; do not guess a URL.

## Client behavior

RecruiterObservationController follows the existing ChangeNotifier and SessionScope conventions. It checks the current verified recruiter role on start, every async callback, and exposed evidence getters. The existing RoleGuard verifies protected content before constructing the observation body; its new optional inline rendering supports embedded scrollable panels without a nested Scaffold. Default route-guard behavior is preserved. Candidate routes are unchanged and do not import or fetch this report. Auth failures clear previously displayed restricted evidence and cancel the socket, HTTP requests, and timers.

Automatic connection ordering is ticket → observer subscription/ready → authorized HTTP report. Live updates can win the HTTP race; lower revisions and duplicate live revisions are ignored. A newer live revision invalidates older report-only values (including percentages and finalization metadata). If a manual HTTP refresh was already in flight before subscription became ready, one coalesced follow-up read is guaranteed after it completes. There is at most one snapshot request in flight and one pending refresh flag, not an event backlog.

Every healthy live subscription reconciles with HTTP every 15 seconds, recovering even a missed final notification with no subsequent event to reveal a revision gap. Reconnect always redeems a fresh ticket, subscribes, and recovers the latest snapshot. Retries use capped exponential base delays (500 ms to 15 seconds) with jitter and at most five retries per recovery run; explicit reconnect resets the run. Snapshot success resets the failure count. Ticket/ready and HTTP waits are bounded to 15 seconds. Recovery exhaustion preserves only the explicitly labeled possibly stale evidence; authorization/session denial clears it completely. Generic socket failure is never diagnosed as expired Clerk credentials.

Hidden/background/covered routes pause and cancel observation work. Foreground/route return reconnects and reconciles; session switching cancels the prior generation and clears evidence before loading the next target. Logout/account change and disposal clear state and fence late HTTP/socket callbacks. The controller never captures images, starts voice, sends socket messages, calls finish-video, submits transcripts, or finalizes an interview. Native targets without the existing web socket adapter can manually retrieve authorized reports, with live transport explicitly unsupported.

The monitor removes integrity-score/risk mappings, camera snapshot URLs, video-stream links, transcript guesses, and legacy alerts from this feature. It renders separate frame accounting, valid/unknown evidence coverage, server-supplied cumulative event counts/durations, a bounded recent timeline, server timestamp/revision, and report finalization/version details. It never derives percentages from absent evidence, episodes from timeline length, durations from frame counts, or aggregate scores from observations. The panel uses wrapping native controls, labeled dropdowns, readable status text, and screen-reader live regions. History truncation and sampling limitations are visible.

## Navigation and file scope

Existing `/recruiter/live-monitor` and `/recruiter/candidate-report` named routes now accept **RecruiterObservationTarget** as `settings.arguments`, containing validated interview/session identity and application ID. The monitor's report button passes that exact target. Missing arguments keep the existing list/resume-report behavior; a page reload without serialized target arguments must reselect a session rather than showing another person's report. No candidate route accepts or renders observation targets. Resume report behavior/scoring is preserved; only its unsupported integrity-timeline empty-state copy was corrected.

Changed/added files in F5:

* `lib/models/phase8_contract.dart`: observer readiness, disabled state, optional factual summaries/binding/limitations, bounded snapshot/report copies, typed recruiter target.
* `lib/services/phase8_service.dart`: prevent starting a request after cancellation while the existing Clerk client resolves.
* `lib/services/recruiter_observation_controller.dart`: new read-only observer controller.
* `lib/widgets/recruiter_observation_panel.dart`, `lib/screens/hr/recruiter_observation_screen.dart`: new protected observation/report UI and route/media lifecycle cleanup.
* `lib/screens/hr/live_monitor_screen.dart`: replace unsupported results/video assumptions, require explicit session identity, preserve responsive list/empty states, and invalidate list work after account change.
* `lib/widgets/role_guard.dart`: optional inline verification presentation using the existing auth flow.
* `lib/main.dart`: typed target arguments for existing recruiter routes.
* `lib/screens/hr/candidate_report_screen.dart`: one empty-state copy correction; no resume scoring/report logic changed.
* `test/fixtures/phase8/observer_fixtures.dart`, `test/phase8_observer_test.dart`: test-only transport, contract, ownership, recovery, role, UI, and cleanup fixtures/tests.
* `test/live_monitor_empty_state_test.dart`: legacy unsupported-data assertions now verify those fields are not rendered; existing responsive/empty/error checks retained.
* `.gitignore`: allowlist new/relevant tests and fixtures; `docs/phase8_f5.md`: this handoff. No test fixture is imported by production code.

## Verification and remaining limits

Final F1–F5 contract/media/publisher/voice/observer and monitor regression suite: **113 passed** (74 F1–F4, 33 F5 observer tests, six existing monitor UI tests). Final focused monitor suite after adding removed-selection recovery: **seven passed**. Existing default login/RoleGuard regression: **one passed**. Cases include authenticated observer-purpose requests, backend-bound identity, unknown optional fields, role verification in an embedded scroll view, candidate denial, ownership errors, subscribe/read races, missed final events, out-of-order revisions, fresh tickets/replay rejection, lease renewal, capped recovery, native socket unavailability, bounded timeline, partial/empty/disabled/processing/failed/unknown states, session switching, logout, and disposal. Scoped static analysis across 11 F5 source/test/route paths: **no issues found**. `git diff --check` passed; backend git status remained clean.

Additional resume-report suite: **one passed and four failed** on expected score text (`63`, `74`, `26.63`) and old empty-state copy (`Choose an application`). F5 does not change resume-report calculations or record-loading behavior; the separately modified resume UI and those tests remain intact. This wider suite is not reported as green. The mixed-suite failures are retained in `verification/phase8_f5_observer.log`; passing results are in `verification/phase8_f5_{tests,monitor,guard,analyze}.log`. Debug web build passed with `flutter build web --debug --no-pub --no-web-resources-cdn --no-wasm-dry-run`; the final rebuild including selection recovery is recorded in `verification/phase8_f5_build.log`.

No live backend observer connection, real ownership enforcement, multi-account browser run, proxy interruption, real model observations, report finalization, cursor history, physical native build, real camera/provider call, or manual screen-reader/browser verification was performed. Fixtures demonstrate client behavior only. End-to-end reconnect/authorization acceptance depends on the frozen backend additions above.

Manual checks after backend implementation: two recruiter accounts and one candidate account; wrong-owner ticket/report denial; active permission revocation within the agreed server lease; reconnect and reload/reselection after a missed final event; concurrent HTTP/live revisions and session switches; 390 px and desktop layouts with large text; keyboard tab order, dropdown/button labels, focus after retry, and screen-reader announcements; partial/failed/disabled/no-evidence cases; background/foreground and navigation cleanup; stale-cache labeling during proxy outage; exact application/session attribution and recent-window/history limits.
