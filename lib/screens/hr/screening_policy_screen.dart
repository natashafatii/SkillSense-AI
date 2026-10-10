import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/job_service.dart';

class ScreeningPolicyScreen extends StatefulWidget {
  final Job job;
  const ScreeningPolicyScreen({super.key, required this.job});
  @override
  State<ScreeningPolicyScreen> createState() => _ScreeningPolicyScreenState();
}

class _ScreeningPolicyScreenState extends State<ScreeningPolicyScreen> {
  late final _threshold = TextEditingController(
    text: widget.job.screeningThreshold.toString(),
  );
  late final _years = TextEditingController(
    text:
        widget.job.screeningCriteria['minimum_experience_years']?.toString() ??
        '',
  );
  late final _education = TextEditingController(
    text: (widget.job.screeningCriteria['education_levels'] as List? ?? [])
        .join(', '),
  );
  late final _certifications = TextEditingController(
    text: (widget.job.screeningCriteria['certifications'] as List? ?? []).join(
      ', ',
    ),
  );
  late bool _enabled = widget.job.autoShortlistEnabled;
  late bool _manual =
      widget.job.screeningCriteria['manual_review_required'] == true;
  late String _policy = widget.job.nonPassPolicy;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _threshold.dispose();
    _years.dispose();
    _education.dispose();
    _certifications.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final threshold = double.tryParse(_threshold.text);
    final years = _years.text.trim().isEmpty
        ? null
        : double.tryParse(_years.text);
    if (threshold == null ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 100 ||
        (_years.text.trim().isNotEmpty &&
            (years == null || !years.isFinite || years < 0 || years > 80))) {
      setState(
        () => _error =
            'Use a threshold from 0 to 100 and experience from 0 to 80 years.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await JobService.updateJob(widget.job.id, {
        'screening_threshold': threshold,
        'auto_shortlist_enabled': _enabled,
        'non_pass_policy': _policy,
        'screening_criteria': {
          if (years != null) 'minimum_experience_years': years,
          'education_levels': _education.text
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          'certifications': _certifications.text
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          'manual_review_required': _manual,
        },
      });
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screening policy')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.job.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Changes apply to new assessments. Existing applications keep their recorded policy; under-review applications can be rescreened explicitly.',
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable automatic screening'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            TextField(
              controller: _threshold,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum match score (inclusive, 0–100)',
              ),
            ),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _policy,
              decoration: const InputDecoration(
                labelText: 'Confirmed failure policy',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'REVIEW',
                  child: Text('Hold for review'),
                ),
                DropdownMenuItem(
                  value: 'REJECT',
                  child: Text('Reject confirmed failures'),
                ),
              ],
              onChanged: (v) => setState(() => _policy = v ?? 'REVIEW'),
            ),
            const Text(
              'Uncertain evidence always goes to review. Processing errors never reject applicants.',
            ),
            TextField(
              controller: _years,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum relevant years (optional)',
              ),
            ),
            TextField(
              controller: _education,
              decoration: const InputDecoration(
                labelText: 'Accepted education levels, comma separated',
              ),
            ),
            TextField(
              controller: _certifications,
              decoration: const InputDecoration(
                labelText: 'Required certifications, comma separated',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Other mandatory conditions need manual review',
              ),
              value: _manual,
              onChanged: (v) => setState(() => _manual = v ?? false),
            ),
            Text('Mandatory skills: ${widget.job.skillsRequired.join(', ')}'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save screening policy'),
            ),
          ],
        ),
      ),
    ),
  );
}
