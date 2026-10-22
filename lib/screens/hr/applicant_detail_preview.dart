import '../application_screening_screen.dart';
import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/application.dart';
import '../../models/resume_detail.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../services/application_service.dart';
import '../../services/resume_service.dart';

/// Applicant-owned information only. Screening analysis belongs to RD-03.
class ApplicantDetailPreview extends StatefulWidget {
  final Application initialApplication;
  final String candidateName;
  final String company;
  final bool mobile;
  final Future<Application> Function(String id)? loadApplication;
  final Future<ResumeDetail> Function(String id)? loadResume;
  final Future<bool> Function(Application app) onShortlist;
  final Future<bool> Function(Application app) onReject;

  const ApplicantDetailPreview({
    super.key,
    required this.initialApplication,
    required this.candidateName,
    required this.company,
    required this.mobile,
    this.loadApplication,
    this.loadResume,
    required this.onShortlist,
    required this.onReject,
  });

  @override
  State<ApplicantDetailPreview> createState() => _ApplicantDetailPreviewState();
}

class _ApplicantDetailPreviewState extends State<ApplicantDetailPreview> {
  static const _ink = Color(0xFF17233B);
  static const _muted = Color(0xFF8290AB);
  static const _border = Color(0xFFE2E8F0);
  Application? _application;
  ResumeDetail? _resume;
  String? _error;
  bool _loading = true;
  bool _resumeUnavailable = false;
  final bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final app =
          await (widget.loadApplication?.call(widget.initialApplication.id) ??
              ApplicationService.getApplication(widget.initialApplication.id));
      if (!mounted) return;
      setState(() {
        _application = app;
        _loading = false;
      });
      final resumeId = app.resumeId;
      if (resumeId == null || resumeId.isEmpty) {
        setState(() => _resumeUnavailable = true);
        return;
      }
      try {
        final resume =
            await (widget.loadResume?.call(resumeId) ??
                ResumeService.getResumeDetail(resumeId));
        if (mounted) setState(() => _resume = resume);
      } on ApiException catch (error) {
        if (mounted) setState(() => _resumeUnavailable = true);
        if (error.statusCode != 404 && mounted) {
          setState(() => _error = error.message);
        }
      } catch (_) {
        if (mounted) setState(() => _resumeUnavailable = true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load applicant.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openScreening() async {
    final app = _application;
    if (app == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApplicationScreeningScreen(applicationId: app.id),
      ),
    );
    if (mounted) _load();
  }

  String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.isNegative || difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _size(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openFile(String url) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return;
    final uri = parsed.hasScheme
        ? parsed
        : Uri.parse(ApiClient.baseUrl).resolveUri(parsed);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open resume.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _application;
    final name = app?.candidateName?.trim().isNotEmpty == true
        ? app!.candidateName!.trim()
        : widget.candidateName;
    final actionAllowed =
        app != null &&
        (app.rawStatus == 'APPLIED' || app.rawStatus == 'UNDER_REVIEW');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(widget.mobile ? 24 : 20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.mobile)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8D0DF),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Applicant — $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFE85D5B),
                            ),
                          ),
                        ),
                      if (app != null) ...[
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFE8EEFF),
                              child: Text(
                                _initials(name),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF3F5BC9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                  Text(
                                    app.candidateEmail,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                  Text(
                                    'Applied ${_timeAgo(app.createdAt)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          [
                            app.jobTitle,
                            if (widget.company.trim().isNotEmpty)
                              widget.company.trim(),
                          ].join(' · '),
                          style: GoogleFonts.inter(fontSize: 12, color: _muted),
                        ),
                        const SizedBox(height: 24),
                        _section('RESUME'),
                        const SizedBox(height: 10),
                        _resumeSection(),
                        const SizedBox(height: 24),
                        _section('COVER NOTE'),
                        const SizedBox(height: 10),
                        Text(
                          app.coverNote?.trim().isNotEmpty == true
                              ? app.coverNote!.trim()
                              : 'No cover note provided.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: app.coverNote?.trim().isNotEmpty == true
                                ? _ink
                                : _muted,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, widget.mobile ? 24 : 18),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _loading ? null : _openScreening,
                  child: const Text('Review screening evidence'),
                ),
                if (actionAllowed) ...[
                  OutlinedButton(
                    onPressed: _busy || !app.allowedActions.contains('reject')
                        ? null
                        : _openScreening,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85D5B),
                      side: const BorderSide(color: Color(0x66E85D5B)),
                    ),
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed:
                        _busy || !app.allowedActions.contains('shortlist')
                        ? null
                        : _openScreening,
                    style: RecruiterButtonStyle.primary(
                      FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5AF1),
                      ),
                    ),
                    child: const Text('Shortlist'),
                  ),
                ],
                OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Text(
    label,
    style: GoogleFonts.spaceGrotesk(
      fontSize: 11,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  );

  Widget _resumeSection() {
    if (_resumeUnavailable) {
      return Text(
        'Resume not available',
        style: GoogleFonts.inter(fontSize: 13, color: _muted),
      );
    }
    final resume = _resume;
    if (resume == null) return const LinearProgressIndicator(minHeight: 2);
    final meta = [
      if (resume.uploadedAt != null)
        '${resume.uploadedAt!.day}/${resume.uploadedAt!.month}/${resume.uploadedAt!.year}',
      if (resume.fileSize != null) _size(resume.fileSize),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.description_outlined,
              color: Color(0xFF4F83FF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resume.filename?.isNotEmpty == true
                        ? resume.filename!
                        : 'Resume',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta.join(' · '),
                      style: GoogleFonts.inter(fontSize: 11, color: _muted),
                    ),
                ],
              ),
            ),
            if (resume.fileUrl?.isNotEmpty == true)
              TextButton(
                onPressed: () => _openFile(resume.fileUrl!),
                child: const Text('Open / Download'),
              ),
          ],
        ),
        if (resume.isPending)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Parsing…',
                  style: GoogleFonts.inter(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        if (resume.isParsed) ...[
          _chips('Skills', resume.skills),
          _rows('Experience', resume.experience, [
            'title',
            'company',
            'duration',
          ]),
          _rows('Education', resume.education, [
            'degree',
            'institution',
            'year',
          ]),
          _chips('Certifications', resume.certifications),
        ],
      ],
    );
  }

  Widget _chips(String label, List<String>? values) {
    if (values == null || values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in values)
                Chip(label: Text(value), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rows(
    String label,
    List<Map<String, dynamic>>? values,
    List<String> keys,
  ) {
    if (values == null || values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in values)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                keys
                    .map((key) => row[key]?.toString().trim() ?? '')
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                style: GoogleFonts.inter(fontSize: 12, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}
