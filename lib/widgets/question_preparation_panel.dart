import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';

/// Review the actual application draft before scheduling; no sample questions.
class QuestionPreparationPanel extends StatefulWidget {
  const QuestionPreparationPanel({
    super.key,
    required this.applicationId,
    required this.onApprovalChanged,
    this.client,
  });
  final String applicationId;
  final Dio? client;
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
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = widget.client ?? await ApiClient.getInstance();
      final result = await dio.get(
        '/applications/${widget.applicationId}/question-set/',
      );
      if (!mounted) return;
      _accept(Map<String, dynamic>.from(result.data as Map));
    } catch (_) {
      if (mounted) {
        widget.onApprovalChanged(null, null);
        setState(() {
          _stale = true;
          _error = 'Could not load question preparation. Refresh to try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _accept(Map<String, dynamic> value) {
    setState(() {
      _data = value;
      _stale = false;
    });
    final approved = value['approved_at'] != null && value['frozen_at'] == null;
    widget.onApprovalChanged(
      approved ? value['id'] as String? : null,
      approved ? value['revision'] as int? : null,
    );
  }

  Future<void> _command(
    String operation, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final current = _data;
    if (current == null || current['id'] == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = widget.client ?? await ApiClient.getInstance();
      final result = await dio.patch(
        '/question-sets/${current['id']}/',
        data: {
          'operation': operation,
          'expected_revision': current['revision'],
          ...fields,
        },
      );
      if (mounted) {
        _accept(Map<String, dynamic>.from(result.data as Map));
      }
    } catch (error) {
      if (mounted) {
        widget.onApprovalChanged(null, null);
        setState(() {
          _stale = true;
          _error = error is DioException && error.response?.statusCode == 409
              ? 'This question set changed. Refresh the draft before making more changes.'
              : 'The change could not be saved. Refresh the draft before retrying.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addQuestion() async {
    final fields = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddQuestionDialog(),
    );
    if (!mounted || fields == null || _busy || _stale) return;
    await _command('add', fields);
  }

  @override
  Widget build(BuildContext context) {
    final state = _data?['generation_status']?.toString() ?? 'LOADING';
    final approved = _data?['approved_at'] != null;
    final frozen = _data?['frozen_at'] != null;
    final questions = (_data?['questions'] as List?) ?? const [];
    final label = switch (state) {
      'FALLBACK' => 'Template fallback — tailored generation was unavailable.',
      'READY' => 'Questions ready for recruiter review.',
      'QUEUED' => 'Question generation is queued.',
      'GENERATING' => 'Tailored questions are being generated.',
      'FAILED' => 'Question generation failed. Retry is available.',
      'NOT_REQUESTED' => 'No draft has been requested for this application.',
      _ => 'Loading question preparation…',
    };
    final editable = !frozen && ['READY', 'FALLBACK', 'LEGACY'].contains(state);
    final canChange = editable && !_busy && !_stale;
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
                  TextButton.icon(
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Refresh draft'),
                  ),
                  if (!approved &&
                      !frozen &&
                      ['READY', 'FALLBACK'].contains(state))
                    TextButton.icon(
                      onPressed: canChange
                          ? () => _command('regenerate')
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                      label: const Text('Regenerate unapproved draft'),
                    ),
                  if (!approved && !frozen && state == 'FAILED')
                    OutlinedButton(
                      onPressed: _busy || _stale
                          ? null
                          : () => _command('retry'),
                      child: const Text('Retry generation'),
                    ),
                  if (!approved &&
                      !frozen &&
                      ['READY', 'FALLBACK'].contains(state))
                    FilledButton.icon(
                      onPressed: canChange && questions.isNotEmpty
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
  const _AddQuestionDialog();
  @override
  State<_AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<_AddQuestionDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  String _category = 'TECHNICAL';
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
      title: const Text('Add your own question'),
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
          child: const Text('Add question'),
        ),
      ],
    ),
  );
}
