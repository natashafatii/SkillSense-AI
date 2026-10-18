import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/interview_analysis_contract.dart';
import '../../models/voice/voice_contract.dart';
import '../media/interview_media_controller.dart';
import '../interview_analysis_service.dart';
import '../publisher/candidate_publisher_controller.dart';
import '../session_scope.dart';
import 'retell_voice_client.dart';
import 'retell_voice_client_factory.dart';
import 'voice_lifecycle_backend.dart';

enum InterviewLifecycleState {
  idle,
  loading,
  joining,
  live,
  interrupted,
  finishing,
  awaitingCompletion,
  completed,
  unavailable,
}

class InterviewLifecycleController extends ChangeNotifier {
  InterviewLifecycleController(
    this.identity,
    this.media,
    this.publisher, {
    VoiceLifecycleBackend? backend,
    InterviewAnalysisService? analysis,
    RetellVoiceClient? voice,
    VoiceSessionSnapshot? initialSnapshot,
    this.pollInterval = const Duration(seconds: 2),
    this.maxPolls = 12,
    this.requestTimeout = const Duration(seconds: 20),
  }) : backend = backend ?? VoiceLifecycleBackend(),
       analysis = analysis ?? InterviewAnalysisService(),
       voice = voice ?? createRetellVoiceClient(),
       _account = SessionScope.generation {
    if (initialSnapshot != null) _apply(initialSnapshot);
    SessionScope.invalidations.addListener(_logout);
  }
  final InterviewSessionIdentity identity;
  final InterviewMediaController media;
  final CandidatePublisherController publisher;
  final VoiceLifecycleBackend backend;
  final InterviewAnalysisService analysis;
  final RetellVoiceClient voice;
  final Duration pollInterval, requestTimeout;
  final int maxPolls, _account;
  final CancelToken _requests = CancelToken();
  bool _disposed = false,
      _invalid = false,
      _paused = false,
      _joining = false,
      _finishWanted = false;
  bool _audioStopConfirmed = false,
      _finishIntentConfirmed = false,
      _videoSealConfirmed = false,
      _agentTalking = false;
  int _voiceEpoch = 0, _polls = 0;
  Timer? _pollTimer;
  final Map<Timer, void Function()> _deadlines = {};
  Future<void>? _finishFlight, _restoreFlight, _readFlight;
  VoiceSessionSnapshot? _snapshot;
  CandidateInterviewData? _interview;
  InterviewLifecycleState _state = InterviewLifecycleState.idle;
  String _notice =
      'Voice has not joined. Backend completion and report readiness are checked separately.';
  String? _dataError;
  VoiceSessionSnapshot? get snapshot => _snapshot;
  CandidateInterviewData? get interview => _interview;
  InterviewLifecycleState get state => _state;
  String get notice => _notice;
  String? get dataError => _dataError;
  bool get agentTalking => _agentTalking;
  bool get finishRequested => _finishWanted;
  bool get finishing => _finishFlight != null;
  bool get audioStopAcknowledged => _audioStopConfirmed;
  bool get videoSealAcknowledged => _videoSealConfirmed;
  bool get isCurrent =>
      !_disposed && !_invalid && _account == SessionScope.generation;
  bool get videoRequired => _snapshot?.videoRequired ?? true;
  bool get canUseMedia =>
      isCurrent &&
      !_finishWanted &&
      _snapshot?.audioEndedAt == null &&
      _state != InterviewLifecycleState.completed;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<T> _bounded<T>(Future<T> operation) {
    final completion = Completer<T>();
    late final Timer timer;
    timer = Timer(requestTimeout, () {
      _deadlines.remove(timer);
      completion.completeError(
        TimeoutException('Lifecycle request timed out.'),
      );
    });
    _deadlines[timer] = () => completion.completeError(
      const VoiceContractUnavailable('Session work was cancelled.'),
    );
    operation.then(
      (value) {
        if (completion.isCompleted) return;
        timer.cancel();
        _deadlines.remove(timer);
        completion.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (completion.isCompleted) return;
        timer.cancel();
        _deadlines.remove(timer);
        completion.completeError(error, stack);
      },
    );
    return completion.future;
  }

  void _cancelDeadlines() {
    for (final entry in _deadlines.entries) {
      entry.key.cancel();
      entry.value();
    }
    _deadlines.clear();
  }

  void _apply(VoiceSessionSnapshot result) {
    if (result.identity.interviewId != identity.interviewId ||
        result.identity.sessionId != identity.sessionId) {
      throw const FormatException('Lifecycle identity mismatch.');
    }
    if (_snapshot != null && result.revision < _snapshot!.revision) return;
    // Voice GET has no server revision. Never let a late read reopen verified
    // terminal audio/completion at an equal analysis revision.
    if (_snapshot?.completed == true && !result.completed) return;
    if (_snapshot?.audioEndedAt != null && result.audioEndedAt == null) return;
    if (_snapshot != null && result.videoRequired != _snapshot!.videoRequired) {
      throw const FormatException('Immutable session mode changed.');
    }
    _snapshot = result;
    _finishWanted |= result.finishRequested || result.completed;
    _finishIntentConfirmed |= result.finishRequested;
    _audioStopConfirmed |= result.audioEndedAt != null;
    _videoSealConfirmed |= !result.videoRequired || result.videoSealed;
    if (result.finishRequested || result.audioEndedAt != null) {
      _localStop();
      _state = result.finishRequested
          ? InterviewLifecycleState.awaitingCompletion
          : InterviewLifecycleState.interrupted;
    }
    if (result.completed) {
      _localStop();
      _state = InterviewLifecycleState.completed;
      _notice = result.reportReady
          ? 'Interview completion is confirmed. Report availability is confirmed separately.'
          : 'Interview completion is confirmed. The report is still processing or unavailable.';
      if (result.reportReady) _pollTimer?.cancel();
    }
  }

  Future<void> restore() =>
      _restoreFlight ??= _restore().whenComplete(() => _restoreFlight = null);
  Future<void> _restore() async {
    if (!isCurrent) return;
    // A refresh is a deliberate recovery boundary, never a second live join.
    if (_state == InterviewLifecycleState.live ||
        _state == InterviewLifecycleState.joining ||
        media.voiceOwnsMicrophone) {
      _localStop();
    }
    _paused = false;
    _state = InterviewLifecycleState.loading;
    _emit();
    // Existing candidate-authorized retrieve includes questions. The separate
    // /questions/ action is recruiter-only in this checkout and is not used.
    try {
      final result = await backend
          .interview(identity.interviewId, cancelToken: _requests)
          .bounded(this);
      if (isCurrent) {
        _interview = result;
        _dataError = null;
      }
    } catch (_) {
      if (isCurrent) {
        _dataError =
            'Approved interview data could not be loaded. Retry status.';
      }
    }
    if (!isCurrent) return;
    try {
      final result = await backend
          .read(
            identity.interviewId,
            sessionId: identity.sessionId,
            cancelToken: _requests,
          )
          .bounded(this);
      if (!isCurrent) return;
      _apply(result);
      // A lagging read must not replace the current completion presentation.
      // All recovery decisions use the highest accepted revision.
      final current = _snapshot!;
      if (current.completed) {
        _state = InterviewLifecycleState.completed;
        _notice = current.reportReady
            ? 'Interview completion is confirmed. Report availability is confirmed separately.'
            : 'Interview completion is confirmed. The report is still processing or unavailable.';
      }
      if (_state != InterviewLifecycleState.completed) {
        _state = _finishWanted
            ? InterviewLifecycleState.awaitingCompletion
            : current.audioEndedAt != null
            ? InterviewLifecycleState.interrupted
            : InterviewLifecycleState.idle;
        _notice = _finishWanted
            ? 'A server-side finish is pending. Retry finish to reconcile remaining controls.'
            : current.audioEndedAt != null
            ? 'Backend audio has ended. Local media is stopped; finish explicitly to confirm completion.'
            : current.credential == null
            ? 'Backend voice credentials are unavailable. No provider call has been joined.'
            : 'Session restored. Join voice explicitly; the camera and frame transport are separate.';
      }
      if (!current.videoRequired || _finishWanted) _localStop();
      if (current.completed && !current.reportReady) _schedulePoll();
    } on VoiceContractUnavailable catch (error) {
      if (isCurrent) {
        _state = InterviewLifecycleState.unavailable;
        _notice = error.message;
      }
    } catch (_) {
      if (isCurrent) {
        _state = InterviewLifecycleState.interrupted;
        _notice =
            'Session status could not be verified. Retry status; no completion is assumed.';
      }
    }
    if (isCurrent) _emit();
  }

  Future<void> joinVoice() async {
    if (!isCurrent || _joining || !canUseMedia || media.busy) return;
    if (!voice.supported) {
      _state = InterviewLifecycleState.unavailable;
      _notice =
          'The supported Retell browser client is unavailable on this target or its local bundle is missing.';
      _emit();
      return;
    }
    _paused = false;
    _joining = true;
    final epoch = ++_voiceEpoch;
    _state = InterviewLifecycleState.joining;
    _notice = 'Checking backend session and provider credentials…';
    _emit();
    try {
      var result = await backend
          .read(
            identity.interviewId,
            sessionId: identity.sessionId,
            cancelToken: _requests,
          )
          .bounded(this);
      if (!isCurrent || epoch != _voiceEpoch) return;
      if (_snapshot != null && result.revision < _snapshot!.revision) {
        throw const VoiceContractUnavailable(
          'Backend credentials are older than the current session status. Retry status.',
        );
      }
      _apply(result);
      if (!canUseMedia) {
        _notice =
            'The backend reports an ended or finishing session; voice was not joined.';
        return;
      }
      if (result.videoRequired && !media.cameraReady) {
        throw const VoiceContractUnavailable(
          'Start the real camera preview before joining this video-enabled session.',
        );
      }
      if (result.credential == null) {
        result = await backend
            .join(
              identity,
              videoRequired: result.videoRequired,
              cancelToken: _requests,
            )
            .bounded(this);
        if (!isCurrent || epoch != _voiceEpoch) return;
        _apply(result);
        if (!canUseMedia) return;
      }
      final credential = result.credential;
      if (credential == null ||
          !credential.expiresAt.isAfter(
            DateTime.now().add(const Duration(seconds: 1)),
          )) {
        throw const VoiceContractUnavailable(
          'A fresh backend-issued provider access token is required. Retry status or rejoin.',
        );
      }
      media.handoffToVoice(preserveCamera: true);
      await voice
          .start(credential, (event) => _voiceEvent(epoch, event))
          .bounded(this);
      // A resolved SDK promise is not a call_started event or completion proof.
      if (isCurrent &&
          epoch == _voiceEpoch &&
          _state == InterviewLifecycleState.joining) {
        _localStop();
        _state = InterviewLifecycleState.interrupted;
        _notice =
            'The provider did not confirm a live voice connection. Rejoin explicitly.';
      }
    } on VoiceContractUnavailable catch (error) {
      if (isCurrent && epoch == _voiceEpoch) {
        _localStop();
        _state = InterviewLifecycleState.unavailable;
        _notice = error.message;
      }
    } catch (_) {
      if (isCurrent && epoch == _voiceEpoch) {
        _localStop();
        _state = InterviewLifecycleState.interrupted;
        _notice =
            'Voice could not connect. Local media stopped; completion was not requested.';
      }
    } finally {
      if (epoch == _voiceEpoch) _joining = false;
      if (isCurrent) _emit();
    }
  }

  void _voiceEvent(int epoch, RetellVoiceEvent event) {
    if (!isCurrent || epoch != _voiceEpoch || _finishWanted) return;
    switch (event) {
      case RetellVoiceEvent.started:
        _state = InterviewLifecycleState.live;
        _notice =
            'Voice provider connected. Camera and frame transport remain independent.';
      case RetellVoiceEvent.audioReady:
        _notice =
            'Provider audio is available. Use Enable audio if browser playback is blocked.';
      case RetellVoiceEvent.agentStartedTalking:
        if (_state == InterviewLifecycleState.live) _agentTalking = true;
      case RetellVoiceEvent.agentStoppedTalking:
        _agentTalking = false;
      case RetellVoiceEvent.ended:
      case RetellVoiceEvent.error:
        _localStop();
        _state = InterviewLifecycleState.interrupted;
        _notice =
            'Voice was interrupted or ended locally. Checking authoritative backend status; no finish is assumed.';
        unawaited(reconcile());
    }
    _emit();
  }

  Future<void> enableAudio() async {
    if (!isCurrent || _finishWanted) return;
    try {
      await voice.resumeAudio();
    } catch (_) {
      if (isCurrent) {
        _notice =
            'Browser audio playback is unavailable. Check site audio settings and retry.';
        _emit();
      }
    }
  }

  Future<void> reconcile() =>
      _readFlight ??= _reconcile().whenComplete(() => _readFlight = null);
  Future<void> _reconcile() async {
    if (!isCurrent) return;
    try {
      final result = await backend
          .sync(identity, cancelToken: _requests)
          .bounded(this);
      if (!isCurrent) return;
      _apply(result);
      // SDK call_ended also occurs on network loss. Only verified backend audio
      // completion permits natural video sealing; never send a client transcript.
      if (result.finishRequested &&
          result.audioEndedAt != null &&
          result.videoRequired &&
          !_videoSealConfirmed) {
        _localStop();
        await _sealVideo();
      }
      if (_finishWanted) {
        if (_state != InterviewLifecycleState.completed) {
          _state = InterviewLifecycleState.awaitingCompletion;
          _notice =
              'Backend completion is still pending; report readiness remains separate.';
        }
        _schedulePoll();
      }
    } on VoiceContractUnavailable catch (error) {
      if (isCurrent) _notice = error.message;
    } catch (_) {
      if (isCurrent) {
        _notice =
            'Backend status could not be verified. Local media is stopped; retry status or finish explicitly.';
      }
    }
    if (isCurrent) _emit();
  }

  Future<void> finish() {
    if (!isCurrent || _snapshot?.completed == true) return Future.value();
    if (_finishFlight != null) return _finishFlight!;
    final completion = Completer<void>();
    _finishFlight = completion.future;
    unawaited(
      _finish().then(
        (_) {
          _finishFlight = null;
          completion.complete();
          if (isCurrent) _emit();
        },
        onError: (Object _, StackTrace __) {
          _finishFlight = null;
          completion.complete();
          if (isCurrent) {
            _notice =
                'Finish could not be confirmed. Retry the remaining controls.';
            _state = InterviewLifecycleState.awaitingCompletion;
            _emit();
          }
        },
      ),
    );
    return completion.future;
  }

  Future<void> _finish() async {
    _finishWanted = true;
    _paused = false;
    _polls = 0;
    _pollTimer?.cancel();
    _localStop();
    _state = InterviewLifecycleState.finishing;
    _notice = 'Requesting backend voice stop and video sealing…';
    _emit();
    if (_snapshot == null) {
      try {
        final result = await backend
            .read(
              identity.interviewId,
              sessionId: identity.sessionId,
              cancelToken: _requests,
            )
            .bounded(this);
        if (!isCurrent) return;
        _apply(result);
      } catch (_) {
        // Audio stop may still be requested, but unknown video mode is not guessed.
      }
    }
    // Both controls get a chance even when the other fails. Only acknowledged
    // steps are retained, and retries target the missing idempotent control.
    final results = await Future.wait<bool>([
      _audioStopConfirmed && _finishIntentConfirmed
          ? Future.value(true)
          : _stopAudio(),
      _snapshot == null
          ? Future.value(false)
          : !videoRequired || _videoSealConfirmed
          ? Future.value(true)
          : _sealVideo(),
    ]);
    if (!isCurrent) return;
    try {
      final result = await backend
          .read(
            identity.interviewId,
            sessionId: identity.sessionId,
            cancelToken: _requests,
          )
          .bounded(this);
      if (!isCurrent) return;
      _apply(result);
    } catch (_) {
      /* Unknown status stays unknown; neither receipt is finalization. */
    }
    if (!isCurrent) return;
    if (_state != InterviewLifecycleState.completed) {
      _state = InterviewLifecycleState.awaitingCompletion;
      _notice = results.every((v) => v)
          ? 'Stop and sealing were acknowledged. Waiting for authoritative interview completion.'
          : 'Finish is only partially confirmed. Retry finish for the remaining step; no successful completion is shown.';
      _schedulePoll();
      _emit();
    } else {
      _schedulePoll();
    }
  }

  Future<bool> _stopAudio() async {
    try {
      await backend.stop(identity, cancelToken: _requests).bounded(this);
      if (!isCurrent) return false;
      _audioStopConfirmed = true;
      _finishIntentConfirmed = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sealVideo() async {
    try {
      final result = await analysis
          .finishVideo(identity, cancelToken: _requests)
          .bounded(this);
      if (!isCurrent) return false;
      if (!['finalizing', 'ended'].contains(result.videoState)) {
        return false;
      }
      _videoSealConfirmed = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (!isCurrent ||
        _paused ||
        (_snapshot?.completed == true && _snapshot?.reportReady == true)) {
      return;
    }
    if (_polls >= maxPolls) {
      _notice = _snapshot?.completed == true
          ? 'Interview completion is confirmed; report availability is still unconfirmed. Refresh status later.'
          : 'Completion is still unconfirmed. Retry status or finish; the report is not assumed ready.';
      return;
    }
    _pollTimer = Timer(pollInterval, () {
      _polls++;
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    if (!isCurrent || _paused) return;
    try {
      final result = await backend
          .read(
            identity.interviewId,
            sessionId: identity.sessionId,
            cancelToken: _requests,
          )
          .bounded(this);
      if (!isCurrent || _paused) return;
      _apply(result);
    } catch (_) {
      if (isCurrent) {
        _notice =
            'Completion status is temporarily unavailable. No successful completion is assumed.';
      }
    }
    if (isCurrent) {
      _schedulePoll();
      _emit();
    }
  }

  void _localStop() {
    _voiceEpoch++;
    _joining = false;
    _agentTalking = false;
    try {
      voice.stop();
    } catch (_) {
      /* Continue releasing local devices. */
    }
    publisher.pause(notify: false);
    media.stop(notify: false);
    media.voiceReleasedMicrophone(notify: false);
  }

  void pauseLocal({bool notify = true}) {
    if (_disposed) return;
    _paused = true;
    _pollTimer?.cancel();
    _localStop();
    if (!_finishWanted && _snapshot?.completed != true) {
      _state = InterviewLifecycleState.interrupted;
      _notice =
          'Local media paused. Recheck backend status and rejoin explicitly; no finish was sent.';
    }
    if (notify) _emit();
  }

  void _logout() {
    _invalid = true;
    _cancelDeadlines();
    _requests.cancel('Account changed.');
    _pollTimer?.cancel();
    _localStop();
    _snapshot = null;
    _interview = null;
    _finishWanted = false;
    _audioStopConfirmed = false;
    _finishIntentConfirmed = false;
    _videoSealConfirmed = false;
    _state = InterviewLifecycleState.unavailable;
    _notice = 'Your account session changed. Reopen the interview.';
    _emit();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelDeadlines();
    SessionScope.invalidations.removeListener(_logout);
    _requests.cancel('Flow disposed.');
    _pollTimer?.cancel();
    _localStop();
    voice.dispose();
    super.dispose();
  }
}

extension _LifecycleDeadline<T> on Future<T> {
  Future<T> bounded(InterviewLifecycleController owner) => owner._bounded(this);
}
