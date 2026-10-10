import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/application.dart';
import '../services/application_service.dart';
import '../services/resume_service.dart';
import '../services/session_scope.dart';

/// Application-owned progress and screening actions, shared by both roles.
class ApplicationScreeningScreen extends StatefulWidget {
  final String applicationId;
  final Future<Application> Function(String id)? loadApplication;
  final Future<Application> Function(
    Application app,
    String action,
    String reason,
  )?
  performAction;
  const ApplicationScreeningScreen({
    super.key,
    required this.applicationId,
    this.loadApplication,
    this.performAction,
  });
  @override
  State<ApplicationScreeningScreen> createState() =>
      _ApplicationScreeningScreenState();
}

class _ApplicationScreeningScreenState
    extends State<ApplicationScreeningScreen> {
  Application? _app;
  String? _error;
  bool _busy = false;
  Timer? _timer;
  final _reason = TextEditingController();
  final _session = SessionScope.generation;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final app =
          await (widget.loadApplication?.call(widget.applicationId) ??
              ApplicationService.getApplication(widget.applicationId));
      if (!mounted || _session != SessionScope.generation) return;
      setState(() {
        _app = app;
        _error = null;
      });
      final stage = app.assessment?['status'];
      if (stage != null && stage != 'SUCCEEDED' && stage != 'FAILED') {
        _polls++;
        _timer = Timer(Duration(seconds: _polls < 10 ? 2 : 10), _load);
      }
    } catch (error) {
      if (mounted && _session == SessionScope.generation) {
        setState(() => _error = '$error');
      }
    }
  }

  Future<void> _act(String action) async {
    final app = _app;
    if (app == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _timer?.cancel();
    try {
      String? resumeId;
      if (action == 'retry-screening' &&
          app.assessment?['recovery_action'] == 'REPLACE_RESUME') {
        final consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace resume'),
            content: const Text(
              'Choose a readable PDF or DOCX. Its text will be sent to Google Gemini for parsing and screening. Do you consent?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Agree and choose file'),
              ),
            ],
          ),
        );
        if (consent != true) return;
        final selection = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'docx'],
          withData: true,
        );
        if (selection == null) return;
        final file = selection.files.single;
        if (file.bytes == null) {
          throw StateError('Could not read the selected file.');
        }
        ApplicationService.validateResume(file.name, file.bytes!);
        final uploaded = await ResumeService.uploadResume(
          fileBytes: file.bytes!,
          fileName: file.name,
        );
        resumeId = uploaded['id'].toString();
      }
      final updated =
          await (widget.performAction?.call(app, action, _reason.text.trim()) ??
              ApplicationService.screeningAction(
                app,
                action,
                reason: _reason.text.trim(),
                resumeId: resumeId,
                consent: resumeId != null,
              ));
      if (!mounted || _session != SessionScope.generation) return;
      setState(() {
        _app = updated;
        _reason.clear();
      });
      await _load();
    } catch (error) {
      // Refresh stale versions before the next action without losing the actionable error.
      await _load();
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final assessment = app?.assessment;
    final criteria = assessment?['criteria_results'] as List? ?? const [];
    final reasons = (assessment?['reasons'] as List? ?? const [])
        .join(', ')
        .replaceAll('_', ' ');
    const labels = {
      'shortlist': 'Shortlist',
      'reject': 'Reject',
      'retry-screening': 'Retry screening',
      'rescreen': 'Rescreen with current policy',
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application screening'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (app == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (app != null) ...[
                Text(
                  app.jobTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(app.candidateName ?? app.candidateEmail),
                const SizedBox(height: 16),
                Text(
                  'Application: ${(app.rawStatus ?? app.status.value).replaceAll('_', ' ')}',
                ),
                Text(
                  'Processing: ${assessment?['status'] ?? 'Awaiting assessment'}',
                ),
                if (assessment != null)
                  Text(
                    'Assessment ${assessment['revision']} · policy ${assessment['policy_version']}',
                  ),
                if (app.resumeScore != null)
                  Text(
                    'Match: ${app.resumeScore!.toStringAsFixed(2)} / 100 · minimum ${assessment?['threshold']}',
                  ),
                if (reasons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(reasons),
                  ),
                for (final row in criteria)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row['requirement']} — ${row['status']}'),
                    subtitle: Text('${row['evidence']}'),
                  ),
                if ((assessment?['error_message'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('${assessment!['error_message']}'),
                  ),
                if (app.allowedActions.contains('shortlist') ||
                    app.allowedActions.contains('reject'))
                  TextField(
                    controller: _reason,
                    maxLines: 3,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Reason for rejection or screening override',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final action in app.allowedActions)
                      FilledButton(
                        onPressed: _busy ? null : () => _act(action),
                        child: Text(labels[action] ?? action),
                      ),
                  ],
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                if (app.eligibleForInterview)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      'Shortlisted and available for interview scheduling.',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
