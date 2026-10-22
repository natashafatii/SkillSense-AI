import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Recruiter-authorized continuation. Never restarts an ended provider call.
class InterviewContinuationPanel extends StatefulWidget {
  const InterviewContinuationPanel({
    super.key,
    required this.interviewId,
    required this.applicationId,
    this.client,
    this.pickSlot,
  });
  final String interviewId, applicationId;
  final Dio? client;
  final Future<DateTime?> Function(BuildContext)? pickSlot;
  @override
  State<InterviewContinuationPanel> createState() =>
      _InterviewContinuationPanelState();
}

class _InterviewContinuationPanelState
    extends State<InterviewContinuationPanel> {
  final _reason = TextEditingController();
  bool _busy = false, _eligible = false, _complete = false;
  String? _error, _scheduled;
  int? _version;
  DateTime? _slot;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _eligible = false;
    });
    try {
      final dio = widget.client ?? await ApiClient.getInstance();
      final voice =
          (await dio.get(
                '/interviews/${widget.interviewId}/voice-session/',
              )).data
              as Map;
      if (!mounted) return;
      final outcome = (voice['conversation'] as Map?)?['outcome'];
      if (voice['status'] != 'DONE' || outcome == 'COMPLETED') {
        setState(() => _complete = true);
        return;
      }
      final app =
          (await dio.get('/applications/${widget.applicationId}/')).data as Map;
      if (!mounted) return;
      final version = app['version'];
      if (version is! int) {
        throw const FormatException('Missing application version.');
      }
      setState(() {
        _version = version;
        _eligible = !['DECISION', 'REJECTED'].contains(app['status']);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not check continuation eligibility. Refresh to try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseSlot() async {
    DateTime? slot;
    if (widget.pickSlot != null) {
      slot = await widget.pickSlot!(context);
    } else {
      final now = DateTime.now();
      final day = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: now.add(const Duration(days: 1)),
      );
      if (!mounted || day == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 10, minute: 0),
      );
      if (time != null) {
        slot = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      }
    }
    if (mounted && slot != null) setState(() => _slot = slot);
  }

  Future<void> _schedule() async {
    if (_slot == null ||
        !_slot!.isAfter(DateTime.now()) ||
        _reason.text.trim().isEmpty) {
      setState(
        () => _error =
            'Choose a future time and explain why a continuation is needed.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dio = widget.client ?? await ApiClient.getInstance();
      final response = await dio.post(
        '/interviews/${widget.interviewId}/reopen/',
        data: {
          'expected_version': _version,
          'reason': _reason.text.trim(),
          'scheduled_at': _slot!.toUtc().toIso8601String(),
          'resume_remaining': true,
        },
      );
      final id = (response.data as Map)['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Missing continuation identity.');
      }
      if (mounted) setState(() => _scheduled = id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _eligible = false;
          _error = error is DioException && error.response?.statusCode == 409
              ? 'The application changed. Refresh and review its latest interview before retrying.'
              : 'Continuation could not be scheduled. Verify that the selected transcript supports the earlier answers and that questions remain, then refresh.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return const SizedBox.shrink();
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F72)),
      ),
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Continue an interrupted interview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17233B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Retain verified earlier answers and ask only the remaining questions in a new call. The original interview stays in history.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.5),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB42338)),
                  ),
                ),
              if (_scheduled != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Continuation scheduled. New interview: $_scheduled',
                    style: const TextStyle(color: Color(0xFF087F72)),
                  ),
                )
              else ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _reason,
                  enabled: _eligible && !_busy,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Reason for continuation',
                    hintText:
                        'For example: audio interruption before the final answer',
                    border: OutlineInputBorder(),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _eligible && !_busy ? _chooseSlot : null,
                      icon: const Icon(Icons.schedule),
                      label: Text(
                        _slot == null
                            ? 'Choose continuation time'
                            : _slot!.toLocal().toString(),
                      ),
                    ),
                    FilledButton(
                      onPressed: _eligible && !_busy ? _schedule : null,
                      child: const Text('Schedule continuation'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: const Text('Refresh eligibility'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
