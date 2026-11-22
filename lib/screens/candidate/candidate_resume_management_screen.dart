import 'package:skillsense_ai/theme/app_typography.dart';
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/adaptive_colors.dart';
import '../../widgets/candidate_button_style.dart';
import '../../widgets/candidate_mobile_search.dart';
import '../../widgets/candidate_scaffold.dart';
import '../../widgets/global_search.dart';
import '../../widgets/notification_unread_scope.dart';
import '../../widgets/recruiter_top_bar.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/resume_detail.dart';
import '../../services/resume_manager.dart';
import '../../services/resume_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/candidate_side_nav.dart';

import 'resume_file_drop_stub.dart'
    if (dart.library.js_interop) 'resume_file_drop_web.dart';

part 'candidate_resume_upload_visuals.dart';

class CandidateResumeManagementScreen extends StatefulWidget {
  const CandidateResumeManagementScreen({super.key});

  @override
  State<CandidateResumeManagementScreen> createState() =>
      _CandidateResumeManagementScreenState();
}

class _CandidateResumeManagementScreenState
    extends State<CandidateResumeManagementScreen> {
  // Right-panel list loading state
  bool _isLoadingList = true;
  String? _listError;

  // Uploading and Parsing State
  bool _hasStagedFile = false;
  List<int>? _stagedFileBytes;
  bool _autoCommitOnParse = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isParsing = false;
  bool _parseCompleted = false;
  bool _isFailed = false;
  bool _processingDelayed = false;
  bool _canRetryParsing = false;
  bool _parseNeedsSupport = false;
  final Set<String> _retryingResumes = {};
  String _failureErrorMessage = '';
  String? _statusCheckMessage;
  String _stagedFilename = '';
  String _stagedFilesize = '';
  String? _stagedResumeId;
  int _parsingElapsedSeconds = 0;

  bool get _canUpload =>
      _hasStagedFile &&
      !_isUploading &&
      !_isParsing &&
      !_parseCompleted &&
      !_isFailed &&
      _statusCheckMessage == null;

  // Parsed Response Data (from API — no hardcoded values)
  ResumeDetail? _stagedExtracted;

  // Dynamic persistent resumes list loaded from ResumeManager
  List<Map<String, dynamic>> get _resumes => ResumeManager.getResumes();

  static const _maxFileSize = 5 * 1024 * 1024;
  CancelToken? _uploadCancellation;
  bool _isPicking = false;
  bool _isSaving = false;
  bool _savedAsDefault = false;

  @override
  void initState() {
    super.initState();
    _loadResumeList();
  }

  /// Fetches the canonical resume list from the API on page load.
  Future<void> _loadResumeList() async {
    setState(() {
      _isLoadingList = true;
      _listError = null;
    });
    try {
      await ResumeManager.loadFromApi();
    } catch (e) {
      if (mounted) setState(() => _listError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  @override
  void dispose() {
    _uploadCancellation?.cancel();
    super.dispose();
  }

  void _removeResume(Map<String, dynamic> resume) async {
    final String apiId = (resume['id'] ?? '').toString();
    if (apiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Resume ID is empty.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.themeSurface(Colors.white),
        title: Text('Delete this resume?', style: AppType.body.style(context)),
        content: Text(
          'Are you sure you want to delete "${resume['filename']}"?',
          style: AppType.body.style(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: CandidateButtonStyle.secondary(
              context,
              TextButton.styleFrom(),
            ),
            child: Text(
              'Cancel',
              style: AppType.button.style(
                context,
                color: CandidateButtonStyle.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: CandidateButtonStyle.destructive(
              context,
              TextButton.styleFrom(),
            ),
            child: Text(
              'Yes, delete',
              style: AppType.button.style(
                context,
                color: CandidateButtonStyle.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Delete on the backend
      await ResumeService.deleteResume(apiId);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 404) {
        // Ignore 404, it's already gone
      } else if (e is ApiException && e.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot delete this resume because it has been submitted for an application.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      } else {
        String errorMessage = e.toString();
        if (e is ApiException) {
          errorMessage = e.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting resume: $errorMessage'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // 2. Eagerly remove from local UI
    try {
      ResumeManager.deleteResume(apiId);
      if (_stagedResumeId == apiId) {
        _clearStagedFile();
      } else {
        setState(() {});
      }
    } catch (e) {
      // ignore local cache errors
    }

    // 3. Sync with backend
    try {
      await ResumeManager.loadFromApi();
      if (ResumeManager.getResumes().any((r) => r['id'] == apiId)) {
        throw StateError('The server still lists this resume.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Warning: $e')));
      }
    }

    if (mounted) setState(() {});

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Resume "${resume['filename']}" deleted.',
          style: AppType.caption.style(context, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _triggerBrowseFiles() async {
    if (!_canChooseFile) return;
    _isPicking = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        withData: kIsWeb,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (!_validateFile(file.name, file.size)) return;
      final bytes =
          file.bytes ??
          (file.path == null
              ? Uint8List(0)
              : await File(file.path!).readAsBytes());
      if (mounted) _stageFile(file.name, bytes);
    } catch (e) {
      if (mounted) _showFileError('Failed to pick file: $e');
    } finally {
      _isPicking = false;
    }
  }

  bool get _canChooseFile =>
      !_isPicking && !_isUploading && !_isParsing && !_isSaving;

  Future<void> _stageDroppedFile(
    String name,
    int size,
    Future<Uint8List> Function() read,
  ) async {
    if (!_canChooseFile || !_validateFile(name, size)) return;
    _isPicking = true;
    try {
      final bytes = await read();
      if (mounted) _stageFile(name, bytes);
    } catch (e) {
      if (mounted) _showFileError('Could not read the selected resume: $e');
    } finally {
      _isPicking = false;
    }
  }

  bool _validateFile(String name, int size) {
    final lower = name.toLowerCase();
    final isSupported = lower.endsWith('.pdf') || lower.endsWith('.docx');
    if (!isSupported || size > _maxFileSize) {
      _showFileError('Choose a PDF or DOCX file up to 5 MB.');
      return false;
    }
    if (size == 0) {
      _showFileError(
        'Could not read file content. Please select a valid file.',
      );
      return false;
    }
    return true;
  }

  void _showFileError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _stageFile(String name, Uint8List bytes) {
    if (!_validateFile(name, bytes.length)) return;
    final size = bytes.length;
    final filesize = size >= 1024 * 1024
        ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(size / 1024).ceil()} KB';
    setState(() {
      _stagedFilename = name;
      _stagedFilesize = filesize;
      _stagedFileBytes = bytes;
      _stagedResumeId = null;
      _statusCheckMessage = null;
      _hasStagedFile = true;
      _uploadProgress = 0;
      _parseCompleted = false;
      _isFailed = false;
      _failureErrorMessage = '';
      _stagedExtracted = null;
      _savedAsDefault = false;
      _canRetryParsing = false;
      _parseNeedsSupport = false;
      _processingDelayed = false;
      _parsingElapsedSeconds = 0;
      _autoCommitOnParse = false;
    });
  }

  void _startUploadFlowFromButton() {
    if (_canUpload && !_isPicking && _stagedFileBytes != null) {
      _autoCommitOnParse = true;
      _startRealUploadFlow(_stagedFilename, _stagedFilesize, _stagedFileBytes!);
    }
  }

  void _startRealUploadFlow(
    String filename,
    String filesize,
    List<int> fileBytes,
  ) async {
    _uploadCancellation?.cancel();
    final cancellation = _uploadCancellation = CancelToken();

    if (fileBytes.isEmpty) {
      setState(() {
        _isUploading = false;
        _isParsing = false;
        _isFailed = true;
        _failureErrorMessage =
            'Could not read file content. Please select a valid file.';
      });
      return;
    }

    setState(() {
      _stagedFilename = filename;
      _stagedFilesize = filesize;
      _isUploading = true;
      _uploadProgress = 0.05;
      _isParsing = false;
      _parseCompleted = false;
      _isFailed = false;
      _failureErrorMessage = '';
      _parsingElapsedSeconds = 0;
      _stagedExtracted = null;
    });

    try {
      // Upload file via POST to Django backend
      final uploadResult = await ResumeService.uploadResume(
        fileBytes: fileBytes,
        fileName: filename,
        cancelToken: cancellation,
        onSendProgress: (sent, total) {
          if (total > 0 && mounted && !cancellation.isCancelled) {
            setState(() {
              _uploadProgress = (sent / total).clamp(0.0, 1.0);
            });
          }
        },
      );

      if (!mounted || cancellation.isCancelled) return;
      final resumeId = uploadResult['id']?.toString();
      if (resumeId == null || resumeId.isEmpty) {
        throw const ApiException(message: 'The upload could not be confirmed.');
      }
      setState(() {
        _stagedResumeId = resumeId;
        _uploadProgress = 1.0;
        _isUploading = false;
        _isParsing = true;
      });

      // Poll backend until parsing is completed or failed
      _pollParsingStatus(resumeId);
    } catch (e) {
      if (!mounted || cancellation.isCancelled) return;
      setState(() {
        _isUploading = false;
        _isParsing = false;
        _isFailed = true;
        _failureErrorMessage = e is ApiException
            ? e.message
            : 'The resume could not be uploaded.';
      });
    }
  }

  void _pollParsingStatus(String resumeId) async {
    _uploadCancellation?.cancel();
    final cancellation = _uploadCancellation = CancelToken();
    setState(() {
      _isParsing = true;
      _isFailed = false;
      _canRetryParsing = false;
      _parseNeedsSupport = false;
      _processingDelayed = false;
      _statusCheckMessage = null;
      _parsingElapsedSeconds = 0;
    });
    try {
      final detail = await ResumeService.pollResumeUntilReady(
        resumeId,
        fetchDetail: (id) => ResumeService.getResumeDetail(
          id,
          refresh: true,
          cancelToken: cancellation,
        ),
        onStatus: (detail) {
          final delayed = detail.processingCode == 'RETRY_PENDING';
          if (mounted &&
              _stagedResumeId == resumeId &&
              delayed != _processingDelayed) {
            setState(() => _processingDelayed = delayed);
          }
        },
        onTick: (elapsed) {
          if (cancellation.isCancelled) {
            throw StateError('Resume polling stopped.');
          }
          if (mounted && _stagedResumeId == resumeId) {
            setState(() {
              _parsingElapsedSeconds = elapsed;
            });
          }
        },
      );

      if (!mounted || cancellation.isCancelled || _stagedResumeId != resumeId) {
        return;
      }
      setState(() {
        _isParsing = false;
        _parseCompleted = true;
        _stagedExtracted = detail;
      });

      if (_autoCommitOnParse) {
        _autoCommitOnParse = false;
        await _commitStagedResume();
      }
    } catch (e) {
      if (!mounted || cancellation.isCancelled || _stagedResumeId != resumeId) {
        return;
      }
      setState(() {
        _isParsing = false;
        if (e is ApiException && e.statusCode == 422) {
          _isFailed = true;
          _canRetryParsing =
              e.validationBody is Map &&
              (e.validationBody as Map)['can_retry_parsing'] == true;
          _parseNeedsSupport =
              e.validationBody is Map &&
              (e.validationBody as Map)['processing_code'] ==
                  'SUPPORT_REQUIRED';
          _failureErrorMessage = e.message;
        } else {
          _statusCheckMessage = e is ApiException
              ? e.message
              : 'The resume status could not be checked.';
        }
      });
    }
  }

  Future<void> _retryParsing(String resumeId) async {
    if (!_retryingResumes.add(resumeId)) return;
    setState(() {});
    try {
      await ResumeService.retryParsing(resumeId);
      if (!mounted) return;
      if (_stagedResumeId == resumeId) {
        _pollParsingStatus(resumeId);
        return;
      }
      setState(() {
        ResumeManager.updateResumeStatus(
          resumeId,
          status: 'pending',
          processingError: '',
          processingCode: '',
          canRetryParsing: false,
        );
      });
      await ResumeService.pollResumeUntilReady(
        resumeId,
        onStatus: (ResumeDetail detail) {
          if (!mounted) return;
          setState(() {
            ResumeManager.updateResumeStatus(
              resumeId,
              status: detail.status.value.toLowerCase(),
              processingError: detail.processingError ?? '',
              processingCode: detail.processingCode ?? '',
              canRetryParsing: detail.canRetryParsing,
            );
          });
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : 'Resume parsing could not be retried.',
            ),
          ),
        );
        if (_stagedResumeId != resumeId) await _loadResumeList();
      }
    } finally {
      _retryingResumes.remove(resumeId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _commitStagedResume() async {
    if (_isSaving ||
        !_parseCompleted ||
        _stagedResumeId == null ||
        _stagedResumeId!.isEmpty) {
      return;
    }
    final id = _stagedResumeId!;
    setState(() => _isSaving = true);
    try {
      ResumeManager.addResume(
        _stagedFilename,
        _stagedFilesize,
        apiId: id,
        status: 'parsed',
      );
      await ResumeManager.loadFromApi();
      ResumeManager.setActive(id);
      if (ResumeManager.getActiveResume()['id'] != id) {
        throw StateError('Failed to set the default resume locally.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resume parsed, but setting it as default failed: $e',
            ),
          ),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (!mounted) return;
    setState(() => _savedAsDefault = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Resume $_stagedFilename confirmed as default.')),
    );
  }

  void _clearStagedFile() {
    final wasBusy = _isUploading || _isParsing;
    _uploadCancellation?.cancel();
    _uploadCancellation = null;
    setState(() {
      _hasStagedFile = false;
      _stagedFileBytes = null;
      _stagedResumeId = null;
      _statusCheckMessage = null;
      _isFailed = false;
      _isUploading = false;
      _isParsing = false;
      _parseCompleted = false;
      _savedAsDefault = false;
      _autoCommitOnParse = false;
      _stagedExtracted = null;
    });
    if (wasBusy) unawaited(_loadResumeList());
  }

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width < CandidateScaffold.mobileBreakpoint;
    const route = '/candidate/resumes';
    return CandidateScaffold(
      currentRoute: route,
      mobileDrawer: Drawer(
        child: CandidateSideNav(
          currentRoute: route,
          initialExpanded: true,
          onNavigate: (destination) {
            final navigator = Navigator.of(context);
            navigator.pop();
            if (destination != route) navigator.pushNamed(destination);
          },
        ),
      ),
      body: WebGlobalSearchLauncher(
        candidate: true,
        builder: (controller, focus, openSearch) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                openSearch,
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                openSearch,
          },
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                if (mobile)
                  Builder(
                    builder: (context) => RecruiterTopBar(
                      pageTitle: 'Resumes',
                      candidate: true,
                      onMobileTitleTap: Scaffold.of(context).openDrawer,
                    ),
                  )
                else
                  _ResumeHeader(
                    mobile: false,
                    search: _ResumeSearchField(
                      controller: controller,
                      focus: focus,
                      openSearch: openSearch,
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 32,
                      28,
                      mobile ? 16 : 32,
                      mobile ? 112 + MediaQuery.paddingOf(context).bottom : 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add your resume',
                          style: _resumeText(context, AppType.h1),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Text(
                            'Upload it once. We read it, pull out your skills, roles and experience, and use them to match you with the right jobs.',
                            style: _resumeText(
                              context,
                              AppType.body,
                              color: _resumeMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final upload = _buildUploadCard();
                            final library = _buildResumeLibrary();
                            // The reference flex bases include padding and borders.
                            const uploadBasis = 610.0;
                            const libraryBasis = 422.0;
                            final available = constraints.maxWidth - 24;
                            if (available < uploadBasis + libraryBasis) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  upload,
                                  const SizedBox(height: 24),
                                  library,
                                ],
                              );
                            }
                            final extra =
                                available - uploadBasis - libraryBasis;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: uploadBasis + extra * 1.45 / 2.45,
                                  child: upload,
                                ),
                                const SizedBox(width: 24),
                                Expanded(child: library),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadCard() {
    return _ResumeCard(
      padding: const EdgeInsets.all(24),
      child: _hasStagedFile
          ? _buildStagedResume()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ResumeDropArea(
                  onBrowse: _triggerBrowseFiles,
                  onDrop: _stageDroppedFile,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ResumeIcon(_lockIcon, size: 15, color: _resumeMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Private to you. Recruiters only see it when you apply.',
                        style: _resumeText(
                          context,
                          AppType.caption,
                          color: _resumeMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStagedResume() {
    final busy = _isUploading || _isParsing;
    final id = _stagedResumeId;
    final statusMessage =
        _statusCheckMessage ?? (_isFailed ? _failureErrorMessage : null);
    final VoidCallback? action = _canUpload && !_isPicking
        ? _startUploadFlowFromButton
        : _parseCompleted && !_isSaving
        ? (_savedAsDefault && ResumeManager.getActiveResume()['id'] == id
              ? _clearStagedFile
              : _commitStagedResume)
        : null;
    final detail = _stagedExtracted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: _resumeBox(context, radius: 14, color: _resumeField),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                _ResumeFileBadge(filename: _stagedFilename, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stagedFilename,
                        style: _resumeText(context, AppType.h4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_resumeFileType(_stagedFilename)} · $_stagedFilesize',
                        style: _resumeText(
                          context,
                          AppType.caption,
                          color: _resumeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _ResumeOutlineButton(
                  label: busy ? 'Cancel' : 'Replace',
                  onPressed: _isSaving
                      ? null
                      : busy
                      ? _clearStagedFile
                      : _triggerBrowseFiles,
                ),
              ],
            ),
          ),
        ),
        if (_isUploading) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            color: _resumeGreen,
            backgroundColor: context.themeChartTrack(_resumeBorder),
            semanticsLabel: 'Upload progress',
          ),
        ],
        const SizedBox(height: 20),
        _ResumeSteps(
          completed: _parseCompleted ? 3 : (_isParsing || id != null ? 1 : 0),
          current: _isUploading
              ? 0
              : _isParsing
              ? 1
              : null,
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 20),
          _ResumeStatusNotice(
            label: statusMessage,
            error: _isFailed,
            onDismiss: _clearStagedFile,
            action: _statusCheckMessage != null && id != null
                ? _ResumeOutlineButton(
                    label: 'Check status',
                    onPressed: () => _pollParsingStatus(id),
                  )
                : _canRetryParsing && id != null
                ? _ResumeOutlineButton(
                    label: 'Retry parsing',
                    onPressed: _retryingResumes.contains(id)
                        ? null
                        : () => _retryParsing(id),
                  )
                : _parseNeedsSupport
                ? null
                : _ResumeOutlineButton(
                    label: 'Choose file',
                    onPressed: _triggerBrowseFiles,
                  ),
          ),
        ],
        if (_parseCompleted && detail != null) ...[
          const SizedBox(height: 20),
          _ResumeFindings(detail: detail),
        ],
        const SizedBox(height: 20),
        _ResumePrimaryButton(
          label: _canUpload || _parseCompleted
              ? 'Use this resume'
              : 'Preparing your resume…',
          onPressed: action,
        ),
        if (statusMessage == null) ...[
          const SizedBox(height: 10),
          Text(
            _savedAsDefault
                ? 'Saved to your library. You can switch resumes anytime.'
                : _canUpload
                ? 'Click to upload and use this resume'
                : _processingDelayed
                ? 'Processing delayed. We’ll retry automatically.'
                : _parsingElapsedSeconds > 10
                ? 'Still processing — this can take a moment.'
                : 'Usually takes 3 to 6 seconds',
            textAlign: TextAlign.center,
            style: _resumeText(context, AppType.caption, color: _resumeMuted),
          ),
        ],
      ],
    );
  }

  Widget _buildResumeLibrary() {
    final resumes = _resumes;
    final activeId = resumes.isEmpty
        ? null
        : ResumeManager.getActiveResume()['id'];
    return _ResumeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.themeOutline(_resumeBorder)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 19),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your resumes',
                      style: _resumeText(context, AppType.h4),
                    ),
                  ),
                  if (!_isLoadingList && _listError == null)
                    _ResumeChip('${resumes.length} saved'),
                ],
              ),
            ),
          ),
          if (_isLoadingList)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: _resumeGreen),
              ),
            )
          else if (_listError case final error?)
            Padding(
              padding: const EdgeInsets.all(20),
              child: _ResumeStatusNotice(
                label: 'Could not load resumes: $error',
                error: true,
                action: _ResumeOutlineButton(
                  label: 'Retry',
                  onPressed: _loadResumeList,
                ),
              ),
            )
          else if (resumes.isEmpty)
            const _EmptyResumeLibrary()
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                spacing: 2,
                children: [
                  for (final resume in resumes)
                    _buildResumeRow(resume, activeId),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumeRow(Map<String, dynamic> resume, Object? activeId) {
    final id = resume['id'].toString();
    final parsed = resume['status'] == 'parsed';
    final active = parsed && activeId == id;
    final filename = (resume['filename'] ?? 'resume.pdf').toString();
    final uploadedAt = DateTime.tryParse(
      resume['uploadedAt']?.toString() ?? '',
    )?.toLocal();
    final date = uploadedAt == null
        ? ResumeManager.getFormattedDateTag(resume).split(' · ').first
        : DateUtils.isSameDay(uploadedAt, DateTime.now())
        ? 'Today'
        : MaterialLocalizations.of(context).formatShortMonthDay(uploadedAt);
    final role = ResumeManager.deriveRoleTag(filename);
    final notice = switch (resume['status']) {
      'pending' when resume['processingCode'] == 'RETRY_PENDING' =>
        'Processing delayed. We’ll retry automatically.',
      'pending' => 'Processing resume…',
      'failed' => resume['processingError']?.toString(),
      _ => null,
    };
    return _ResumeLibraryRow(
      filename: filename,
      metadata: '$role · $date',
      active: active,
      isNew: _parseCompleted && id == _stagedResumeId,
      notice: notice,
      onSelect: parsed && !active && !_isSaving
          ? () => setState(() => ResumeManager.setActive(id))
          : null,
      onDelete: _isSaving || (id == _stagedResumeId && _isParsing)
          ? null
          : () => _removeResume(resume),
      canRetry: resume['canRetryParsing'] == true && id != _stagedResumeId,
      onRetry: _retryingResumes.contains(id) ? null : () => _retryParsing(id),
    );
  }
}
