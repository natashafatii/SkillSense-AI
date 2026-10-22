import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/question_set.dart';
import '../models/api_contract.dart';
import '../services/foreground_poller.dart';
import '../services/session_scope.dart';
import '../models/application.dart';
import '../services/application_service.dart';
import '../services/api_exception.dart';
import '../services/question_preparation_service.dart';

/// Review the actual application draft before scheduling; no sample questions.
class QuestionPreparationPanel extends StatefulWidget {
  const QuestionPreparationPanel({
    super.key,
    required this.applicationId,
    required this.onApprovalChanged,
    this.client,
    this.application,
  });
  final String applicationId;
  final Dio? client;
  final Application? application;
  final void Function(String? setId, int? revision) onApprovalChanged;
  @override
  State<QuestionPreparationPanel> createState() =>
      _QuestionPreparationPanelState();
}

class _QuestionPreparationPanelState extends State<QuestionPreparationPanel> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  bool _stale = false;
  String? _error;
  Map<String, dynamic>? _unsavedAdd;
  String _unsavedOperation = 'add';
  Application? _application;
  DateTime? _retryAt;
  bool _reviewRequired = false;
  int _resourceEpoch = 0;
  late final ForegroundPoller<Map<String, dynamic>> _poller;
  final int _session = SessionScope.generation;

  Future<Map<String, dynamic>> _read([CancelToken? token]) async {
    final dio = widget.client ?? await ApiClient.getInstance();
    final response = await dio.get(
      '/applications/${widget.applicationId}/question-set/',
      cancelToken: token,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  void dispose() {
    _poller.dispose();
    SessionScope.invalidations.removeListener(_clearSession);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _poller = ForegroundPoller(
      read: _read,
      isVisible: () => mounted && ModalRoute.of(context)?.isCurrent != false,
      isPending: (data) =>
          isPendingWorkflowState(data['generation_status']?.toString() ?? ''),
      onData: (data) {
        if (mounted && _session == SessionScope.generation) _accept(data);
      },
      onStopped: (error) {
        if (mounted &&
            isPendingWorkflowState(
              _data?['generation_status']?.toString() ?? '',
            )) {
          setState(() => _error = 'Still processing. Refresh to check again.');
        }
      },
    );
    _application = widget.application;
    SessionScope.invalidations.addListener(_clearSession);
    _refresh();
  }

  Future<void> _refresh() async {
    final resourceEpoch = _resourceEpoch;
    _poller.stop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _read();
      if (!mounted ||
          _session != SessionScope.generation ||
          resourceEpoch != _resourceEpoch) {
        return;
      }
      _accept(data);
      if (data['generation_status'] == 'NOT_REQUESTED') {
        final application = await ApplicationService.getApplication(
          widget.applicationId,
          client: widget.client,
        );
        if (mounted &&
            _session == SessionScope.generation &&
            resourceEpoch == _resourceEpoch) {
          setState(() => _application = application);
        }
      }
      if (isPendingWorkflowState(data['generation_status']?.toString() ?? '')) {
        _poller.start();
      }
    } catch (_) {
      if (mounted &&
          _session == SessionScope.generation &&
          resourceEpoch == _resourceEpoch) {
        widget.onApprovalChanged(null, null);
        setState(() {
          _stale = true;
          _error = 'Could not load question preparation. Refresh to try again.';
        });
      }
    } finally {
      if (mounted && resourceEpoch == _resourceEpoch) {
        setState(() => _busy = false);
      }
    }
  }

  void _accept(Map<String, dynamic> value) {
    final parsed = QuestionSet.fromJson(value);
    setState(() {
      _data = value;
      _stale = false;
      _retryAt = parsed.nextAttemptAt ?? _retryAt;
    });
    final approved =
        parsed.schedulable && !_reviewRequired && _unsavedAdd == null;
    widget.onApprovalChanged(
      approved ? value['id'] as String? : null,
      approved ? parsed.revision?.value : null,
    );
  }

  Future<void> _command(
    String operation, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final resourceEpoch = _resourceEpoch;
    final current = _data;
    if (_busy || (_retryAt != null && DateTime.now().isBefore(_retryAt!))) {
      return;
    }
    if (current == null ||
        current['id'] == null ||
        _reviewRequired ||
        _session != SessionScope.generation) {
      return;
    }
    _poller.stop();
    widget.onApprovalChanged(null, null);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await QuestionPreparationService(
        client: widget.client,
      ).command(QuestionSet.fromJson(current), operation, fields);
      if (mounted &&
          _session == SessionScope.generation &&
          resourceEpoch == _resourceEpoch) {
        _unsavedAdd = null;
        _accept(result.toJson());
        if (isPendingWorkflowState(result.generationStatus)) _poller.start();
      }
    } catch (error) {
      if (mounted &&
          resourceEpoch == _resourceEpoch &&
          _session == SessionScope.generation) {
        widget.onApprovalChanged(null, null);
        setState(() {
          _stale = true;
          _reviewRequired = true;
          if (error is ApiException && error.statusCode == 429) {
            _retryAt = DateTime.now().add(
              error.retryAfter ?? const Duration(seconds: 15),
            );
          }
          _error = error is ApiException && error.statusCode == 409
              ? 'This question set changed. Refresh the draft before making more changes.'
              : 'The change could not be saved. Refresh the draft before retrying.';
        });
        await _refresh();
        if (mounted && resourceEpoch == _resourceEpoch) {
          setState(
            () => _error = error is ApiException
                ? error.message
                : 'The change was not confirmed. Review current state before retrying.',
          );
        }
      }
    } finally {
      if (mounted && resourceEpoch == _resourceEpoch) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addQuestion() async {
    final resourceEpoch = _resourceEpoch;
    final fields = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddQuestionDialog(),
    );
    if (!mounted ||
        resourceEpoch != _resourceEpoch ||
        fields == null ||
        _busy ||
        _stale) {
      return;
    }
    _unsavedAdd = Map<String, dynamic>.from(fields);
    _unsavedOperation = 'add';
    await _command('add', fields);
  }

  Future<void> _editQuestion(Map<String, dynamic> question) async {
    if (!const {
      'TECHNICAL',
      'BEHAVIORAL',
      'SITUATIONAL',
    }.contains(question['category'])) {
      setState(
        () => _error =
            'This question category is not supported by this editor. Refresh or contact your administrator.',
      );
      return;
    }
    final resourceEpoch = _resourceEpoch;
    final fields = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddQuestionDialog(initial: question),
    );
    if (!mounted ||
        resourceEpoch != _resourceEpoch ||
        fields == null ||
        _busy ||
        _stale ||
        _reviewRequired) {
      return;
    }
    _unsavedAdd = {'id': question['id'], ...fields};
    _unsavedOperation = 'edit';
    await _command('edit', _unsavedAdd!);
  }

  Future<void> _move(String id, int offset) async {
    final ids = (_data!['questions'] as List)
        .map((q) => (q as Map)['id'] as String)
        .toList();
    final index = ids.indexOf(id), target = ids.indexOf(id) + offset;
    if (index < 0 || target < 0 || target >= ids.length) return;
    ids.removeAt(index);
    ids.insert(target, id);
    await _command('reorder', {'ids': ids});
  }

  Future<void> _regenerate() async {
    final resourceEpoch = _resourceEpoch;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate this unapproved draft?'),
        content: const Text(
          'Unedited generated and template questions will be archived. Manual questions and recruiter-edited wording are preserved. Review and approve the resulting revision again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate draft'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        resourceEpoch == _resourceEpoch &&
        !_busy &&
        !_reviewRequired) {
      await _command('regenerate');
    }
  }

  Future<void> _prepare() async {
    final app = _application;
    if (app == null || !app.canPrepareQuestions || _busy || _reviewRequired) {
      return;
    }
    setState(() => _busy = true);
    try {
      await QuestionPreparationService(client: widget.client).prepare(app);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _reviewRequired = true;
      await _refresh();
      if (mounted) {
        setState(
          () => _error =
              'Preparation was not confirmed. Review refreshed application state before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearSession() {
    _resourceEpoch++;
    _poller.stop();
    if (mounted) {
      setState(() {
        _data = null;
        _application = null;
        _unsavedAdd = null;
        _stale = true;
      });
    }
    widget.onApprovalChanged(null, null);
  }

  @override
  void didUpdateWidget(covariant QuestionPreparationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicationId != widget.applicationId) {
      _resourceEpoch++;
      _poller.stop();
      _data = null;
      _application = widget.application;
      _unsavedAdd = null;
      _reviewRequired = false;
      widget.onApprovalChanged(null, null);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _data?['generation_status']?.toString() ?? 'LOADING';
    final approved = _data?['approved_at'] != null;
    final frozen =
        _data?['frozen_at'] != null ||
        _data?['legacy'] == true ||
        state == 'LEGACY';
    final questions = (_data?['questions'] as List?) ?? const [];
    final label = switch (state) {
      'FALLBACK' => 'Template fallback — tailored generation was unavailable.',
      'READY' => 'Questions ready for recruiter review.',
      'QUEUED' => 'Question generation is queued.',
      'GENERATING' => 'Tailored questions are being generated.',
      'FAILED' =>
        'Question generation failed. Review the error and retry timing.',
      'LEGACY' =>
        'Historical imported questions — read-only and unavailable for new scheduling.',
      'NOT_REQUESTED' => 'No draft has been requested for this application.',
      'LOADING' => 'Loading question preparation…',
      _ => 'Question preparation state unavailable. Refresh to check again.',
    };
    final editable =
        !frozen &&
        _data?['legacy'] != true &&
        ['READY', 'FALLBACK'].contains(state);
    final canChange =
        editable &&
        !_busy &&
        !_stale &&
        !_reviewRequired &&
        (_retryAt == null || !DateTime.now().isBefore(_retryAt!));
    const ink = Color(0xFF17233B);
    const muted = Color(0xFF64748B);
    const teal = Color(0xFF087F72);
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          brightness: Brightness.light,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: ink),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE4EAF3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F6F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.quiz_outlined,
                          color: teal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Interview questions',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Shape the conversation before sending an invitation.',
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final add = OutlinedButton.icon(
                    onPressed: canChange && questions.length < 100
                        ? _addQuestion
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add question'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: teal,
                      side: const BorderSide(color: Color(0xFFB7DCD5)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  return constraints.maxWidth < 560
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [heading, const SizedBox(height: 16), add],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            const SizedBox(width: 20),
                            add,
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _badge(
                    frozen
                        ? 'Locked for interview'
                        : approved
                        ? 'Approved'
                        : 'Draft for review',
                    teal,
                  ),
                  _badge('${questions.length} questions', muted),
                  if (_data?['revision'] != null)
                    Text(
                      'Revision ${_data!['revision']}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 13, color: muted)),
              if (approved)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Recruiter approved',
                    style: TextStyle(color: teal, fontSize: 12),
                  ),
                ),
              if (frozen)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Frozen for the scheduled interview',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              if (_data?['fallback_reason'] != null &&
                  _data!['fallback_reason'] != '')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Fallback reason: ${_data!['fallback_reason']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A6700),
                    ),
                  ),
                ),
              if (_unsavedAdd != null)
                Text('Unsaved question: ${_unsavedAdd!['text'] ?? ''}'),
              if (_reviewRequired)
                TextButton(
                  onPressed: _busy || _stale
                      ? null
                      : () {
                          setState(() => _reviewRequired = false);
                          _accept(_data!);
                        },
                  child: const Text('I reviewed the refreshed draft'),
                ),
              if (_unsavedAdd != null && canChange)
                TextButton(
                  onPressed: () => _command(_unsavedOperation, _unsavedAdd!),
                  child: const Text('Submit preserved question'),
                ),
              if (_unsavedAdd != null && !_busy)
                TextButton(
                  onPressed: () async {
                    final edited = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _AddQuestionDialog(initial: _unsavedAdd),
                    );
                    if (edited != null && mounted) {
                      setState(
                        () => _unsavedAdd = {
                          if (_unsavedAdd!['id'] != null)
                            'id': _unsavedAdd!['id'],
                          ...edited,
                        },
                      );
                    }
                  },
                  child: const Text('Edit preserved wording'),
                ),
              if (_unsavedAdd != null && !_busy)
                TextButton(
                  onPressed: () {
                    setState(() => _unsavedAdd = null);
                    if (_data != null) _accept(_data!);
                  },
                  child: const Text('Discard preserved changes'),
                ),
              if (_unsavedAdd != null &&
                  _unsavedOperation == 'edit' &&
                  canChange &&
                  !questions.any((q) => (q as Map)['id'] == _unsavedAdd!['id']))
                TextButton(
                  onPressed: () => _command('add', {
                    'text': _unsavedAdd!['text'],
                    'category': _unsavedAdd!['category'],
                  }),
                  child: const Text('Add preserved wording as a new question'),
                ),
              if (_data?['error_code'] != null && _data!['error_code'] != '')
                Text('Generation error: ${_data!['error_code']}'),
              if (_data?['next_attempt_at'] != null)
                Text(
                  'Next generation attempt: ${ApiValue.instant(_data!['next_attempt_at'])?.toLocal()}',
                ),
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42338),
                      fontSize: 13,
                    ),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 20),
              for (final raw in questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _questionCard(
                    Map<String, dynamic>.from(raw as Map),
                    canChange,
                    frozen,
                  ),
                ),
              if (questions.isEmpty && !_busy)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    editable
                        ? 'No questions in this draft. Add a question to get started.'
                        : 'Your questions will appear here when preparation is complete.',
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFE4EAF3)),
              const SizedBox(height: 12),
              Text(
                frozen
                    ? 'This question set is locked to preserve the interview record.'
                    : approved
                    ? 'Adding or removing a question will require approval again.'
                    : 'Review every question, then approve this set to continue scheduling.',
                style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (state == 'NOT_REQUESTED' &&
                      _application?.canPrepareQuestions == true)
                    FilledButton(
                      onPressed: _busy || _reviewRequired ? null : _prepare,
                      child: const Text('Prepare questions'),
                    ),
                  TextButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Refresh draft'),
                  ),
                  if (!approved &&
                      !frozen &&
                      ['READY', 'FALLBACK', 'FAILED'].contains(state))
                    TextButton.icon(
                      onPressed:
                          !_busy &&
                              !_stale &&
                              !_reviewRequired &&
                              _data?['legacy'] != true &&
                              (_retryAt == null ||
                                  !DateTime.now().isBefore(_retryAt!))
                          ? _regenerate
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                      label: const Text('Regenerate unapproved draft'),
                    ),
                  if (!approved && !frozen && state == 'FAILED')
                    OutlinedButton(
                      onPressed:
                          _busy ||
                              _stale ||
                              _reviewRequired ||
                              (_retryAt != null &&
                                  DateTime.now().isBefore(_retryAt!))
                          ? null
                          : () => _command('retry'),
                      child: const Text('Retry generation'),
                    ),
                  if (!approved &&
                      !frozen &&
                      ['READY', 'FALLBACK'].contains(state))
                    FilledButton.icon(
                      onPressed:
                          canChange &&
                              questions.isNotEmpty &&
                              _unsavedAdd == null
                          ? () => _command('approve')
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: teal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve this set'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _questionCard(
    Map<String, dynamic> question,
    bool canChange,
    bool frozen,
  ) {
    final category = question['category']?.toString() ?? 'QUESTION';
    final categoryColor = switch (category) {
      'TECHNICAL' => const Color(0xFF4268C8),
      'BEHAVIORAL' => const Color(0xFF8256AD),
      _ => const Color(0xFF087F72),
    };
    final number = (question['position'] as num? ?? 0).toInt() + 1;
    return Container(
      key: ValueKey('question-${question['id']}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EAF3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: categoryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _badge(
                      category[0] + category.substring(1).toLowerCase(),
                      categoryColor,
                    ),
                    Text(
                      'Source: ${question['source']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${question['text']}',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF17233B),
                  ),
                ),
              ],
            ),
          ),
          if (!frozen) ...[
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit question $number',
                  onPressed: canChange ? () => _editQuestion(question) : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Move question $number up',
                  onPressed: canChange && number > 1
                      ? () => _move(question['id'] as String, -1)
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: 'Move question $number down',
                  onPressed:
                      canChange && number < (_data!['questions'] as List).length
                      ? () => _move(question['id'] as String, 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Remove question $number',
              onPressed: canChange
                  ? () => _command('remove', {'id': question['id']})
                  : null,
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: const Color(0xFFB45060),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFF5F5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddQuestionDialog extends StatefulWidget {
  const _AddQuestionDialog({this.initial});
  final Map<String, dynamic>? initial;
  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  String _category = 'TECHNICAL';
  @override
  void initState() {
    super.initState();
    _text.text = widget.initial?['text']?.toString() ?? '';
    _category = widget.initial?['category']?.toString() ?? 'TECHNICAL';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF087F72),
        brightness: Brightness.light,
      ),
    ),
    child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        widget.initial == null ? 'Add your own question' : 'Edit question',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ask about a skill or experience you want to explore.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'TECHNICAL',
                      child: Text('Technical'),
                    ),
                    DropdownMenuItem(
                      value: 'BEHAVIORAL',
                      child: Text('Behavioral'),
                    ),
                    DropdownMenuItem(
                      value: 'SITUATIONAL',
                      child: Text('Situational'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _category = value;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 10000,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'What would you like to ask the candidate?',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a question.'
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, {
                'text': _text.text.trim(),
                'category': _category,
              });
            }
          },
          child: Text(
            widget.initial == null ? 'Add question' : 'Save question',
          ),
        ),
      ],
    ),
  );
}
