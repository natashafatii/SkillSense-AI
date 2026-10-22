import 'package:skillsense_ai/widgets/recruiter_button_style.dart';
import 'package:skillsense_ai/widgets/pointer_gesture_detector.dart';
import '../../widgets/mobile_edge_shadow_wrapper.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/job.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../widgets/recruiter_top_bar.dart';

@immutable
class CreateRoleTokens extends ThemeExtension<CreateRoleTokens> {
  const CreateRoleTokens({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.field,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.success,
    required this.error,
  });

  final Color background, surface, surface2, field, border, borderStrong;
  final Color text,
      text2,
      text3,
      accent,
      accentStrong,
      accentSoft,
      success,
      error;

  static const light = CreateRoleTokens(
    background: Color(0xFFF5F7FC),
    surface: Colors.white,
    surface2: Color(0xFFF8FAFE),
    field: Colors.white,
    border: Color(0xFFDDE3F0),
    borderStrong: Color(0xFFC5CEE3),
    text: Color(0xFF16213A),
    text2: Color(0xFF4A5875),
    text3: Color(0xFF74829E),
    accent: Color(0xFF3E6FF0),
    accentStrong: Color(0xFF2F57CC),
    accentSoft: Color(0x1A3E6FF0),
    success: Color(0xFF0E9F72),
    error: Color(0xFFD64545),
  );
  static const mobileLight = CreateRoleTokens(
    background: Color(0xFFF4F6FB),
    surface: Colors.white,
    surface2: Color(0xFFF7F9FD),
    field: Colors.white,
    border: Color(0xFFE0E5F0),
    borderStrong: Color(0xFFC5CEE3),
    text: Color(0xFF16213A),
    text2: Color(0xFF4A5875),
    text3: Color(0xFF74829E),
    accent: Color(0xFF3A68E8),
    accentStrong: Color(0xFF3A68E8),
    accentSoft: Color(0x1A3A68E8),
    success: Color(0xFF0E9F72),
    error: Color(0xFFD64545),
  );
  static const dark = CreateRoleTokens(
    background: Color(0xFF070B14),
    surface: Color(0xFF0D1424),
    surface2: Color(0xFF111A2E),
    field: Color(0xFF0A1120),
    border: Color(0x267FA0D0),
    borderStrong: Color(0x4D94AADC),
    text: Color(0xFFE8EDF8),
    text2: Color(0xFFA3AFC8),
    text3: Color(0xFF6E7C99),
    accent: Color(0xFF6C9BFF),
    accentStrong: Color(0xFF8FB0FF),
    accentSoft: Color(0x246C9BFF),
    success: Color(0xFF34E3B0),
    error: Color(0xFFFF7B7B),
  );

  @override
  CreateRoleTokens copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? field,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accentStrong,
    Color? accentSoft,
    Color? success,
    Color? error,
  }) => CreateRoleTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    field: field ?? this.field,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    text: text ?? this.text,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    accentSoft: accentSoft ?? this.accentSoft,
    success: success ?? this.success,
    error: error ?? this.error,
  );

  @override
  CreateRoleTokens lerp(ThemeExtension<CreateRoleTokens>? other, double t) {
    if (other is! CreateRoleTokens) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return CreateRoleTokens(
      background: blend(background, other.background),
      surface: blend(surface, other.surface),
      surface2: blend(surface2, other.surface2),
      field: blend(field, other.field),
      border: blend(border, other.border),
      borderStrong: blend(borderStrong, other.borderStrong),
      text: blend(text, other.text),
      text2: blend(text2, other.text2),
      text3: blend(text3, other.text3),
      accent: blend(accent, other.accent),
      accentStrong: blend(accentStrong, other.accentStrong),
      accentSoft: blend(accentSoft, other.accentSoft),
      success: blend(success, other.success),
      error: blend(error, other.error),
    );
  }
}

class _SalaryFormatter extends TextInputFormatter {
  const _SalaryFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final before = newValue.text.substring(
      0,
      newValue.selection.baseOffset.clamp(0, newValue.text.length),
    );
    final digitsBefore = before.replaceAll(RegExp(r'\D'), '').length;
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final reversed = digits.split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < reversed.length; i += 3) {
      groups.add(reversed.skip(i).take(3).toList().reversed.join());
    }
    final formatted = groups.reversed.join(',');
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBefore) {
      if (RegExp(r'\d').hasMatch(formatted[offset])) seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class _SelectedSkill {
  _SelectedSkill(this.name, [this.weight = 2]);
  final String name;
  int weight;
}

enum CreateRoleEditResult { notFound }

class CreateRoleScreen extends StatefulWidget {
  const CreateRoleScreen({super.key, this.initialJob});

  final Job? initialJob;

  @override
  State<CreateRoleScreen> createState() => _CreateRoleScreenState();
}

class _CreateRoleScreenState extends State<CreateRoleScreen> {
  static const _catalog = [
    'Python',
    'Django',
    'Django REST Framework',
    'PostgreSQL',
    'Celery',
    'Redis',
    'Docker',
    'AWS',
    'REST APIs',
    'GraphQL',
    'React',
    'TypeScript',
    'JavaScript',
    'Node.js',
    'FastAPI',
    'Kubernetes',
    'CI/CD',
    'Git',
    'Linux',
    'Machine Learning',
    'SQL',
    'Flutter',
    'Figma',
    'Communication',
  ];
  static const _suggested = [
    'Python',
    'Django',
    'PostgreSQL',
    'Docker',
    'REST APIs',
  ];
  static const _cities = [
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Peshawar',
    'Anywhere in Pakistan',
  ];
  static const _ranges = [
    ('50k – 80k', 50000, 80000),
    ('80k – 120k', 80000, 120000),
    ('120k – 200k', 120000, 200000),
    ('200k+', 200000, 350000),
  ];
  static const _mixColors = [
    Color(0xFF3E6FF0),
    Color(0xFF14B584),
    Color(0xFFE9A83C),
  ];
  static const _mixNames = ['Technical', 'Behavioral', 'Situational'];
  static const _mixDetails = [
    'Hands-on skills and problem solving',
    'Past experience and teamwork',
    'Judgment in realistic scenarios',
  ];

  final _title = TextEditingController();
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _description = TextEditingController();
  final _requirements = TextEditingController();
  final _skillSearch = TextEditingController();
  final _pageScroll = ScrollController();
  final _skillFocus = FocusNode();
  final _skillLink = LayerLink();
  final _skillOverlay = OverlayPortalController();
  final _skillFieldKey = GlobalKey();
  final _dateFieldKey = GlobalKey();
  final _sectionKeys = List.generate(6, (_) => GlobalKey());
  final _fieldFocus = List.generate(6, (_) => FocusNode());
  final _mixFocus = List.generate(6, (_) => FocusNode());
  final _salaryMaxFocus = FocusNode();
  OverlayEntry? _calendarOverlay;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final _errors = <String, String>{};
  final _skills = <_SelectedSkill>[];
  final _mix = [4, 2, 2];
  String? _location;
  String _workType = 'Remote';
  String _experience = 'Mid';
  DateTime? _deadline;
  int _highlighted = -1;
  double _threshold = 66;
  bool _autoShortlist = true;
  bool _saving = false;
  String? _savedJobId;
  double _scrollOffset = 0;

  // The recruiter workspace has a light navigation shell. Keep the form and
  // its overlays in the same palette regardless of the OS appearance setting.
  CreateRoleTokens get _c =>
      _isMobile ? CreateRoleTokens.mobileLight : CreateRoleTokens.light;
  bool get _isMobile => MediaQuery.sizeOf(context).width < 900;

  @override
  void initState() {
    super.initState();
    if (widget.initialJob case final job?) {
      _prefillJob(job);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreDraft();
      });
    }
    for (final controller in [
      _title,
      _salaryMin,
      _salaryMax,
      _description,
      _requirements,
    ]) {
      controller.addListener(_refresh);
    }
    _skillSearch.addListener(() {
      _highlighted = -1;
      if (_skillFocus.hasFocus) _skillOverlay.show();
      _refresh();
    });
    _skillFocus.addListener(() {
      if (_skillFocus.hasFocus) {
        _skillOverlay.show();
      } else {
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted && !_skillFocus.hasFocus) _skillOverlay.hide();
        });
      }
      _refresh();
    });
    _pageScroll.addListener(() {
      if (mounted && _pageScroll.offset != _scrollOffset) {
        setState(() => _scrollOffset = _pageScroll.offset);
      }
    });
  }

  void _prefillJob(Job job) {
    _savedJobId = job.id;
    _title.text = job.title;
    _description.text = job.description;
    _requirements.text = job.requirements;
    _location = job.location;
    _workType = switch (job.jobType) {
      JobType.hybrid => 'Hybrid',
      JobType.onsite => 'On-site',
      JobType.remote => 'Remote',
    };
    _experience = switch (job.experienceLevel) {
      ExperienceLevel.entry => 'Junior',
      ExperienceLevel.mid => 'Mid',
      ExperienceLevel.senior => 'Senior',
    };
    _deadline = job.deadline;
    final salaryParts = RegExp(r'\d[\d,]*').allMatches(job.salary).toList();
    if (salaryParts.length == 2) {
      _salaryMin.text = salaryParts[0].group(0)!;
      _salaryMax.text = salaryParts[1].group(0)!;
    }
    _threshold = job.screeningThreshold.clamp(40, 90);
    _autoShortlist = job.autoShortlistEnabled;
    final weights = job.screeningCriteria['skill_weights'];
    final names = job.skillsRequired.isNotEmpty
        ? job.skillsRequired
        : job.jobSkills.map((skill) => skill.skillName).toList();
    _skills.addAll(
      names.map(
        (name) => _SelectedSkill(
          name,
          weights is Map && weights[name] is num
              ? (weights[name] as num).toInt().clamp(1, 3)
              : 2,
        ),
      ),
    );
    final mix = job.screeningCriteria['question_mix'];
    if (mix is Map) {
      for (var i = 0; i < _mix.length; i++) {
        final value = mix[_mixNames[i].toLowerCase()];
        if (value is num) _mix[i] = value.toInt().clamp(0, 12);
      }
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _closeCalendarOverlay();
    for (final controller in [
      _title,
      _salaryMin,
      _salaryMax,
      _description,
      _requirements,
      _skillSearch,
    ]) {
      controller.dispose();
    }
    for (final focus in [
      ..._fieldFocus,
      ..._mixFocus,
      _skillFocus,
      _salaryMaxFocus,
    ]) {
      focus.dispose();
    }
    _pageScroll.dispose();
    super.dispose();
  }

  TextStyle _body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color ?? _c.text,
  );
  TextStyle _heading(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color ?? _c.text,
  );
  BoxDecoration _cardDecoration({double radius = 16}) => BoxDecoration(
    color: _c.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _c.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .06),
        blurRadius: 22,
        offset: const Offset(0, 8),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Theme(
        data: Theme.of(context).copyWith(
          brightness: Brightness.light,
          extensions: [c],
          colorScheme: ColorScheme.fromSeed(
            seedColor: c.accent,
            brightness: Brightness.light,
          ),
        ),
        child: _isMobile
            ? _mobileScaffold()
            : Scaffold(
                backgroundColor: c.background,
                body: SafeArea(
                  child: Column(
                    children: [
                      _topBar(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final horizontalPadding = constraints.maxWidth < 640
                                ? 16.0
                                : 28.0;
                            final width = math.min(
                              1200.0,
                              math.max(
                                0.0,
                                constraints.maxWidth - horizontalPadding * 2,
                              ),
                            );
                            final wide = constraints.maxWidth >= 980;
                            if (!wide) {
                              return SingleChildScrollView(
                                controller: _pageScroll,
                                padding: EdgeInsets.fromLTRB(
                                  horizontalPadding,
                                  constraints.maxWidth < 640 ? 24 : 32,
                                  horizontalPadding,
                                  48,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: width,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _pageIntro(constraints.maxWidth < 640),
                                        _formCard(constraints.maxWidth < 640),
                                        const SizedBox(height: 24),
                                        _aside(),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }
                            final formWidth = width - 384;
                            return Center(
                              child: SizedBox(
                                width: width,
                                child: Stack(
                                  children: [
                                    SingleChildScrollView(
                                      controller: _pageScroll,
                                      padding: const EdgeInsets.fromLTRB(
                                        0,
                                        32,
                                        0,
                                        64,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _pageIntro(false),
                                          SizedBox(
                                            width: formWidth,
                                            child: _formCard(false),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: math.max(20, 174 - _scrollOffset),
                                      bottom: 0,
                                      width: 360,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        child: _aside(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _mobileScaffold() {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            RecruiterTopBar(
              pageTitle: widget.initialJob == null
                  ? 'Create a Role'
                  : 'Edit role',
              mobileTitle: widget.initialJob == null
                  ? 'New job posting'
                  : 'Edit role',
              breadcrumbSegments: [
                widget.initialJob == null ? 'Create a Role' : 'Edit role',
              ],
            ),
            Expanded(
              child: MobileEdgeShadowWrapper(
                child: SingleChildScrollView(
                  controller: _pageScroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _mobileCard('Role basics', 'What candidates see first.', [
                        _field(
                          key: _sectionKeys[0],
                          id: 'title',
                          label: 'Role title',
                          controller: _title,
                          hint: 'Senior Django Developer',
                          focusNode: _fieldFocus[0],
                        ),
                        _locationField(),
                        _segmentField(
                          'Work type',
                          const ['Remote', 'Hybrid', 'On-site'],
                          _workType,
                          (v) => setState(() => _workType = v),
                        ),
                        _segmentField(
                          'Experience level',
                          const ['Junior', 'Mid', 'Senior', 'Lead'],
                          _experience,
                          (v) => setState(() => _experience = v),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _mobileCard(
                        'Pay and timeline',
                        'Monthly salary in Pakistani rupees.',
                        [
                          KeyedSubtree(
                            key: _sectionKeys[2],
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _salaryField(
                                    'Minimum',
                                    _salaryMin,
                                    _fieldFocus[2],
                                    '200,000',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _salaryField(
                                    'Maximum',
                                    _salaryMax,
                                    _salaryMaxFocus,
                                    '300,000',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_errors['salary'] != null)
                            _errorText(_errors['salary']!),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _ranges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => _rangePill(_ranges[i]),
                            ),
                          ),
                          _dateField(),
                        ],
                        gaps: const [16, 6, 18],
                      ),
                      const SizedBox(height: 14),
                      _mobileCard(
                        'Description and requirements',
                        'Clear requirements make screening fairer.',
                        [
                          _field(
                            key: _sectionKeys[4],
                            id: 'description',
                            label: 'About the role',
                            controller: _description,
                            hint:
                                'What will this person own, and who will they work with?',
                            focusNode: _fieldFocus[4],
                            minLines: 4,
                            maxLines: 6,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _field(
                                id: 'requirements',
                                label: 'Must-have requirements',
                                labelTrailing: 'One per line',
                                controller: _requirements,
                                hint:
                                    '4+ years building production Django apps\nStrong SQL and query tuning',
                                minLines: 4,
                                maxLines: 6,
                                maxLength: 500,
                                hideCounter: true,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Missing a requirement flags the applicant.',
                                      maxLines: 2,
                                      style: _body(12.5, color: _c.text3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_requirements.text.length} / 500',
                                    style: _body(12.5, color: _c.text3),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _mobileCard(
                        'Skills',
                        'Tap a ×1 to ×3 badge to set how much a skill matters.',
                        [_skillsField()],
                      ),
                      const SizedBox(height: 14),
                      _mobileCard(
                        'AI interview',
                        'How the interview agent splits its questions.',
                        [_interviewMix()],
                      ),
                      const SizedBox(height: 14),
                      _mobileCard(
                        'Screening threshold',
                        'Minimum match score to count as qualified.',
                        [_mobileThreshold()],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(top: false, child: _mobileActions()),
    );
  }

  Widget _mobileCard(
    String title,
    String subtitle,
    List<Widget> fields, {
    List<double>? gaps,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    decoration: BoxDecoration(
      color: _c.surface,
      border: Border.all(color: _c.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: _body(
            17,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: -.17),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: _body(13.5, color: _c.text3)),
        const SizedBox(height: 16),
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0)
            SizedBox(
              height: gaps != null && i - 1 < gaps.length ? gaps[i - 1] : 16,
            ),
          fields[i],
        ],
      ],
    ),
  );

  Widget _mobileActions() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: BoxDecoration(
      color: _c.surface,
      border: Border(top: BorderSide(color: _c.border)),
      boxShadow: [
        BoxShadow(
          color: _c.text.withValues(alpha: .12),
          blurRadius: 24,
          offset: const Offset(0, -8),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            key: const Key('create-role-mobile-preview'),
            onPressed: _openMobilePreview,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _c.text,
              side: BorderSide(color: _c.borderStrong),
              backgroundColor: _c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: _body(16, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('create-role-publish'),
              onPressed: _saving
                  ? null
                  : () => _saveRole(publish: widget.initialJob == null),
              style: RecruiterButtonStyle.primary(FilledButton.styleFrom(
                backgroundColor: _c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              )),
              child: Text(
                _saving
                    ? 'Saving…'
                    : widget.initialJob == null
                    ? 'Publish role'
                    : 'Save changes',
                style: _body(16, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _mobileThreshold() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '${_threshold.round()}',
            key: const Key('create-role-threshold-value'),
            style: _heading(
              36,
            ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]),
          ),
          const SizedBox(width: 10),
          Text(
            _thresholdBand,
            style: _body(13.5, weight: FontWeight.w600, color: _c.success),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  stops: [0, .35, .65, 1],
                  colors: [
                    Color(0xFFEF5B5B),
                    Color(0xFFE9A83C),
                    Color(0xFF3A68E8),
                    Color(0xFF14B584),
                  ],
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 10,
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbShape: _WhiteSliderThumb(_c.accent, radius: 15),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                key: const Key('create-role-threshold'),
                min: 40,
                max: 90,
                divisions: 50,
                value: _threshold,
                onChanged: (v) =>
                    setState(() => _threshold = v.roundToDouble()),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Text('40 Open', style: _body(12.5, color: _c.text3)),
          const Spacer(),
          Text('90 Strict', style: _body(12.5, color: _c.text3)),
        ],
      ),
      const SizedBox(height: 18),
      Divider(height: 1, color: _c.border),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-shortlist',
                  style: _body(15, weight: FontWeight.w600),
                ),
                Text(
                  _autoShortlist
                      ? 'Applicants scoring ${_threshold.round()}+ who meet every requirement are shortlisted.'
                      : 'Off. You review every applicant yourself.',
                  style: _body(13, color: _c.text3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Switch(
            key: const Key('create-role-auto-shortlist'),
            value: _autoShortlist,
            activeThumbColor: Colors.white,
            activeTrackColor: _c.accent,
            onChanged: (v) => setState(() => _autoShortlist = v),
          ),
        ],
      ),
    ],
  );

  Future<void> _openMobilePreview() async {
    _skillFocus.unfocus();
    _skillOverlay.hide();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 300),
              reverseDuration: Duration(milliseconds: 250),
            ),
      barrierColor: const Color(0x80070B14),
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .86,
          ),
          decoration: BoxDecoration(
            color: _c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _c.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Live preview', style: _heading(18)),
                const SizedBox(height: 14),
                _mobilePreviewJob(),
                const SizedBox(height: 16),
                _mobileEstimate(),
                const SizedBox(height: 16),
                Divider(height: 1, color: _c.border),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    key: const Key('create-role-sheet-publish'),
                    onPressed: _saving
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            _saveRole(publish: widget.initialJob == null);
                          },
                    style: RecruiterButtonStyle.primary(FilledButton.styleFrom(
                      backgroundColor: _c.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )),
                    child: Text(
                      widget.initialJob == null
                          ? 'Publish role'
                          : 'Save changes',
                      style: _body(
                        16,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

  Widget _mobilePreviewJob() {
    final hasSalary = _money(_salaryMin) > 0 && _money(_salaryMax) > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface2,
        border: Border.all(color: _c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title.text.trim().isEmpty ? 'Role title' : _title.text.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _heading(
              18,
              weight: FontWeight.w600,
              color: _title.text.trim().isEmpty ? _c.text3 : _c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _previewMeta(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(13.5, color: _c.text2),
          ),
          const SizedBox(height: 10),
          Text(
            hasSalary
                ? 'PKR ${_salaryMin.text} – ${_salaryMax.text} / month'
                : 'Salary range',
            style: _body(15, weight: FontWeight.w600),
          ),
          if (_skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in _skills.take(6)) _previewSkill(skill.name),
                if (_skills.length > 6) _previewSkill('+${_skills.length - 6}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileEstimate() {
    final estimate = _estimate();
    return estimate == null
        ? Text(
            'Add a title and skills to see an applicant estimate.',
            style: _body(14, color: _c.text2),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${estimate.$1}–${estimate.$2} applicants',
                key: const Key('create-role-estimate'),
                style: _heading(20, weight: FontWeight.w600),
              ),
              Text(
                'expected in week one, based on similar roles',
                style: _body(14, color: _c.text2),
              ),
            ],
          );
  }

  Widget _topBar() => RecruiterTopBar(
    pageTitle: widget.initialJob == null ? 'Create a Role' : 'Edit role',
    mobileTitle: widget.initialJob == null ? 'New job posting' : 'Edit role',
    breadcrumbSegments: [
      widget.initialJob == null ? 'Create a Role' : 'Edit role',
    ],
    hasUnread:
        AppNavState.hasUnreadNotifications || AppNavState.unreadInterviews > 0,
    onBellTap: () =>
        Navigator.of(context).pushNamed('/recruiter/notifications'),
  );
  Widget _pageIntro(bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.initialJob == null ? 'New job posting' : 'Edit role',
        style: _heading(
          compact ? 26 : 30,
        ).copyWith(letterSpacing: compact ? -.52 : -.6),
      ),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Text(
          'Describe the role and pick the skills that matter. SkillSense uses them to match, screen and interview candidates.',
          style: _body(15, color: _c.text2),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _formCard(bool compact) => Container(
    decoration: _cardDecoration(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          'Role basics',
          'What candidates will see first.',
          compact,
          children: [
            _twoColumns(
              _field(
                key: _sectionKeys[0],
                id: 'title',
                label: 'Role title',
                controller: _title,
                hint: 'Senior Django Developer',
                focusNode: _fieldFocus[0],
              ),
              _locationField(),
              compact,
            ),
            const SizedBox(height: 18),
            _twoColumns(
              _segmentField(
                'Work type',
                ['Remote', 'Hybrid', 'On-site'],
                _workType,
                (value) => setState(() => _workType = value),
              ),
              _segmentField(
                'Experience level',
                ['Junior', 'Mid', 'Senior', 'Lead'],
                _experience,
                (value) => setState(() => _experience = value),
              ),
              compact,
            ),
          ],
        ),
        _section(
          'Pay and timeline',
          'Monthly salary in Pakistani rupees. Posted roles with a range get more applicants.',
          compact,
          children: [
            KeyedSubtree(
              key: _sectionKeys[2],
              child: _twoColumns(
                _salaryField('Minimum', _salaryMin, _fieldFocus[2], '200,000'),
                _salaryField('Maximum', _salaryMax, _salaryMaxFocus, '300,000'),
                compact,
              ),
            ),
            if (_errors['salary'] != null) _errorText(_errors['salary']!),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _ranges.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _rangePill(_ranges[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: compact ? double.infinity : 300,
              child: _dateField(),
            ),
          ],
        ),
        _section(
          'Description and requirements',
          'Be specific. Clear requirements let the screening score applicants fairly.',
          compact,
          children: [
            _field(
              key: _sectionKeys[4],
              id: 'description',
              label: 'About the role',
              controller: _description,
              hint: 'What will this person own, and who will they work with?',
              focusNode: _fieldFocus[4],
              minLines: 4,
              maxLines: 6,
            ),
            const SizedBox(height: 18),
            _field(
              id: 'requirements',
              label: 'Must-have requirements',
              labelTrailing: 'One per line',
              controller: _requirements,
              hint:
                  '4+ years building production Django apps\nStrong SQL and query tuning\nComfortable owning code reviews',
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              hideCounter: true,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Candidates missing a requirement are flagged for review.',
                    maxLines: 2,
                    style: _body(12.5, color: _c.text3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_requirements.text.length} / 500',
                  style: _body(12.5, color: _c.text3),
                ),
              ],
            ),
          ],
        ),
        _section(
          'Skills',
          'Weight skills from ×1 (nice to have) to ×3 (essential).',
          compact,
          children: [_skillsField()],
        ),
        _section(
          'AI interview',
          'Choose how the interview agent splits its questions.',
          compact,
          last: true,
          children: [_interviewMix()],
        ),
      ],
    ),
  );

  Widget _section(
    String title,
    String subtitle,
    bool compact, {
    required List<Widget> children,
    bool last = false,
  }) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 18 : 32,
      vertical: compact ? 22 : 28,
    ),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: _c.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: _body(
            17,
            weight: FontWeight.w600,
          ).copyWith(letterSpacing: title == 'Skills' ? -.17 : null),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: _body(13.5, color: _c.text3)),
        const SizedBox(height: 20),
        ...children,
      ],
    ),
  );

  Widget _twoColumns(Widget left, Widget right, bool compact) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: 16), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _label(String title, {String? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: _body(13.5, weight: FontWeight.w500)),
        ),
        if (trailing != null)
          Text(trailing, style: _body(12.5, color: _c.text3)),
      ],
    ),
  );
  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: _body(12.5, color: _c.error)),
  );
  BoxDecoration _inputBox(bool focused, bool errored, {double radius = 10}) =>
      BoxDecoration(
        color: _c.field,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: errored
              ? _c.error
              : focused
              ? _c.accent
              : _c.borderStrong,
          width: errored || focused ? 1.5 : 1,
        ),
        boxShadow: focused
            ? [BoxShadow(color: _c.accentSoft, blurRadius: 0, spreadRadius: 4)]
            : null,
      );

  Widget _field({
    Key? key,
    required String id,
    required String label,
    String? labelTrailing,
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    bool hideCounter = false,
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(label, trailing: labelTrailing),
      Focus(
        onFocusChange: (_) => _refresh(),
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              constraints: BoxConstraints(
                minHeight: minLines > 1 ? 108 : (_isMobile ? 48 : 46),
              ),
              decoration: _inputBox(
                focused,
                _errors.containsKey(id),
                radius: _isMobile ? 12 : 10,
              ),
              child: TextField(
                key: Key('create-role-$id'),
                controller: controller,
                focusNode: focusNode,
                minLines: minLines,
                maxLines: maxLines,
                maxLength: maxLength,
                style: _body(14.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: _body(14.5, color: _c.text3),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: minLines > 1 ? 12 : (_isMobile ? 14 : 13),
                  ),
                  counterText: hideCounter ? '' : null,
                ),
                onChanged: (_) => _errors.remove(id),
              ),
            );
          },
        ),
      ),
      if (_errors[id] != null) _errorText(_errors[id]!),
    ],
  );

  Widget _locationField() => Column(
    key: _sectionKeys[1],
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label('Location'),
      Focus(
        onFocusChange: (_) => _refresh(),
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              height: _isMobile ? 48 : 46,
              decoration: _inputBox(
                focused,
                _errors.containsKey('location'),
                radius: _isMobile ? 12 : 10,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('create-role-location'),
                  value: _location,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  dropdownColor: _c.surface,
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: _c.text3,
                  ),
                  hint: Text(
                    'Select a city',
                    style: _body(14.5, color: _c.text3),
                  ),
                  style: _body(14.5),
                  items: [
                    if (_location != null && !_cities.contains(_location))
                      DropdownMenuItem(
                        value: _location,
                        child: Text(
                          _location!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    for (final city in _cities)
                      DropdownMenuItem(
                        value: city,
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (city) => setState(() {
                    _location = city;
                    _errors.remove('location');
                  }),
                ),
              ),
            );
          },
        ),
      ),
      if (_errors['location'] != null) _errorText(_errors['location']!),
    ],
  );

  Widget _segmentField(
    String label,
    List<String> values,
    String selected,
    ValueChanged<String> onSelect,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(label),
      Container(
        height: _isMobile ? 48 : 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _c.surface2,
          border: Border.all(color: _c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final value in values)
              Expanded(
                child: InkWell(
                  key: Key(
                    'create-role-${label.toLowerCase().replaceAll(' ', '-')}-${value.toLowerCase()}',
                  ),
                  onTap: () => onSelect(value),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: value == selected
                        ? BoxDecoration(
                            color: _c.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _c.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .12),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          )
                        : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: _body(
                          13.5,
                          weight: FontWeight.w500,
                          color: value == selected ? _c.text : _c.text2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _salaryField(
    String label,
    TextEditingController controller,
    FocusNode focus,
    String hint,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label(label),
      Focus(
        onFocusChange: (_) => _refresh(),
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              height: _isMobile ? 48 : 46,
              clipBehavior: Clip.antiAlias,
              decoration: _inputBox(
                focused,
                _errors.containsKey('salary'),
                radius: _isMobile ? 12 : 10,
              ),
              child: Row(
                children: [
                  Container(
                    height: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _c.surface2,
                      border: Border(right: BorderSide(color: _c.border)),
                    ),
                    child: Text(
                      'PKR',
                      style: _body(
                        12.5,
                        weight: FontWeight.w600,
                        color: _c.text2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      key: Key(
                        label == 'Minimum' ? 'salary-min' : 'salary-max',
                      ),
                      controller: controller,
                      focusNode: focus,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [_SalaryFormatter()],
                      style: _body(14.5).copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: hint,
                        hintStyle: _body(14.5, color: _c.text3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                      ),
                      onChanged: (_) => _errors.remove('salary'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );

  int _money(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll(',', '')) ?? 0;
  String _commas(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  Widget _rangePill((String, int, int) range) {
    final selected =
        _money(_salaryMin) == range.$2 && _money(_salaryMax) == range.$3;
    return InkWell(
      key: Key('range-${range.$2}'),
      onTap: () {
        _salaryMin.text = _commas(range.$2);
        _salaryMax.text = _commas(range.$3);
        setState(() => _errors.remove('salary'));
      },
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: _isMobile ? 36 : 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _c.accentSoft : _c.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? _c.accent : _c.border),
        ),
        child: Text(
          range.$1,
          style: _body(
            _isMobile ? 13.5 : 13,
            weight: FontWeight.w500,
            color: selected ? _c.accent : _c.text2,
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _closeCalendarOverlay() {
    _calendarOverlay?.remove();
    _calendarOverlay = null;
  }

  void _showCalendarPopover() {
    if (_calendarOverlay != null) {
      _closeCalendarOverlay();
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Position the overlay just below the date field button
    final renderBox =
        _dateFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _calendarMonth = DateTime(
      (_deadline ?? today).year,
      (_deadline ?? today).month,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CalendarPopover(
        anchorOffset: offset,
        anchorSize: size,
        initialMonth: _calendarMonth,
        selected: _deadline,
        today: today,
        tokens: _c,
        bodyStyle: _body,
        headingStyle: _heading,
        onSelect: (date) {
          setState(() {
            _deadline = date;
            _errors.remove('date');
          });
          _closeCalendarOverlay();
        },
        onClear: () {
          setState(() => _deadline = null);
          _closeCalendarOverlay();
        },
        onDismiss: _closeCalendarOverlay,
      ),
    );
    _calendarOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  Widget _dateField() => Column(
    key: _sectionKeys[3],
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label('Applications close'),
      KeyedSubtree(
        key: const Key('create-role-date'),
        child: InkWell(
          key: _dateFieldKey,
          onTap: _showCalendarPopover,
          borderRadius: BorderRadius.circular(_isMobile ? 12 : 10),
          child: Container(
            height: _isMobile ? 48 : 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: _inputBox(
              _calendarOverlay != null,
              _errors.containsKey('date'),
              radius: _isMobile ? 12 : 10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _deadline == null
                        ? 'Select a closing date'
                        : _dateLabel(_deadline!),
                    style: _body(
                      14.5,
                      color: _deadline == null ? _c.text3 : _c.text,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 17, color: _c.text3),
              ],
            ),
          ),
        ),
      ),
      if (_errors['date'] != null) _errorText(_errors['date']!),
    ],
  );

  List<String> _skillOptions() {
    final query = _skillSearch.text.trim().toLowerCase();
    final matches = _catalog
        .where(
          (name) =>
              !_skills.any(
                (selected) => selected.name.toLowerCase() == name.toLowerCase(),
              ) &&
              (query.isEmpty || name.toLowerCase().contains(query)),
        )
        .take(_isMobile ? 6 : 7)
        .toList();
    if (query.isNotEmpty &&
        !_catalog.any((name) => name.toLowerCase() == query) &&
        !_skills.any((selected) => selected.name.toLowerCase() == query)) {
      matches.add(_skillSearch.text.trim());
    }
    return matches;
  }

  void _addSkill(String name) {
    final clean = name.trim();
    if (clean.isEmpty ||
        _skills.length >= 20 ||
        _skills.any(
          (selected) => selected.name.toLowerCase() == clean.toLowerCase(),
        )) {
      return;
    }
    setState(() {
      _skills.add(_SelectedSkill(clean));
      _skillSearch.clear();
      _highlighted = -1;
      _errors.remove('skills');
    });
    _skillOverlay.hide();
  }

  KeyEventResult _onSkillKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final options = _skillOptions();
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (options.isNotEmpty) {
        setState(
          () => _highlighted = math.min(_highlighted + 1, options.length - 1),
        );
      }
      _skillOverlay.show();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (options.isNotEmpty) {
        setState(() => _highlighted = math.max(_highlighted - 1, 0));
      }
      _skillOverlay.show();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (options.isNotEmpty) {
        _addSkill(options[_highlighted < 0 ? 0 : _highlighted]);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _skillOverlay.hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _skillsField() => Column(
    key: _sectionKeys[5],
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _label('Add skills', trailing: '${_skills.length} of 20'),
      OverlayPortal(
        controller: _skillOverlay,
        overlayChildBuilder: (context) {
          final options = _skillOptions();
          final width =
              (_skillFieldKey.currentContext?.findRenderObject() as RenderBox?)
                  ?.size
                  .width ??
              300;
          return CompositedTransformFollower(
            link: _skillLink,
            showWhenUnlinked: false,
            offset: Offset(0, _isMobile ? 54 : 52),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: Material(
                  color: _c.surface,
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(_isMobile ? 14 : 12),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: _isMobile ? 220 : 240,
                    ),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(color: _c.borderStrong),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < options.length; i++)
                          InkWell(
                            key: Key('skill-option-$i'),
                            onTap: () => _addSkill(options[i]),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isMobile ? 12 : 10,
                                vertical: _isMobile ? 12 : 9,
                              ),
                              decoration: BoxDecoration(
                                color: i == _highlighted ? _c.accentSoft : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                i == options.length - 1 &&
                                        !_catalog.any(
                                          (name) =>
                                              name.toLowerCase() ==
                                              options[i].toLowerCase(),
                                        )
                                    ? 'Add “${options[i]}”'
                                    : options[i],
                                style: _body(
                                  14,
                                  color: i == _highlighted
                                      ? _c.accent
                                      : _c.text,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: CompositedTransformTarget(
          link: _skillLink,
          child: Focus(
            onKeyEvent: _onSkillKey,
            onFocusChange: (_) => _refresh(),
            child: Builder(
              builder: (context) {
                final focused = Focus.of(context).hasFocus;
                return Container(
                  key: _skillFieldKey,
                  height: _isMobile ? 48 : 46,
                  decoration: _inputBox(
                    focused,
                    _errors.containsKey('skills'),
                    radius: _isMobile ? 12 : 10,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search, size: 16, color: _c.text3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('create-role-skill-search'),
                          controller: _skillSearch,
                          focusNode: _skillFocus,
                          textInputAction: _isMobile
                              ? TextInputAction.done
                              : TextInputAction.search,
                          enabled: _skills.length < 20,
                          style: _body(14.5),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search skills, e.g. Django',
                            hintStyle: _body(14.5, color: _c.text3),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: _skills.isEmpty
            ? Text('No skills added yet.', style: _body(13.5, color: _c.text3))
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final skill in _skills) _skillChip(skill)],
              ),
      ),
      if (_errors['skills'] != null) _errorText(_errors['skills']!),
      const SizedBox(height: 16),
      if (!_isMobile)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_suggested.any(
              (name) => !_skills.any(
                (skill) => skill.name.toLowerCase() == name.toLowerCase(),
              ),
            ))
              Text('Suggested:', style: _body(13, color: _c.text3)),
            for (final name in _suggested)
              if (!_skills.any(
                (skill) => skill.name.toLowerCase() == name.toLowerCase(),
              ))
                _SuggestedSkillChip(
                  key: Key('suggested-skill-$name'),
                  name: name,
                  borderColor: _c.borderStrong,
                  textColor: _c.text2,
                  accentColor: _c.accent,
                  onTap: () => _addSkill(name),
                ),
          ],
        ),
      if (_isMobile &&
          _suggested.any(
            (name) => !_skills.any(
              (skill) => skill.name.toLowerCase() == name.toLowerCase(),
            ),
          ))
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Center(
                child: Text('Suggested', style: _body(13, color: _c.text3)),
              ),
              const SizedBox(width: 8),
              for (final name in _suggested)
                if (!_skills.any(
                  (skill) => skill.name.toLowerCase() == name.toLowerCase(),
                )) ...[
                  _SuggestedSkillChip(
                    key: Key('suggested-skill-$name'),
                    name: name,
                    height: 32,
                    borderColor: _c.borderStrong,
                    textColor: _c.text2,
                    accentColor: _c.accent,
                    onTap: () => _addSkill(name),
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
    ],
  );

  Widget _skillChip(_SelectedSkill skill) => Container(
    height: _isMobile ? 36 : 34,
    constraints: BoxConstraints(
      maxWidth: _isMobile
          ? math.max(120, MediaQuery.sizeOf(context).width - 68)
          : double.infinity,
    ),
    decoration: BoxDecoration(
      color: _c.accentSoft,
      border: Border.all(color: _c.accent),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Padding(
            padding: const EdgeInsets.only(left: 13, right: 8),
            child: Text(
              skill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(13.5, weight: FontWeight.w500, color: _c.accent),
            ),
          ),
        ),
        Container(width: 1, height: 20, color: _c.accent.withValues(alpha: .3)),
        InkWell(
          key: Key('skill-weight-${skill.name}'),
          onTap: () => setState(() => skill.weight = skill.weight % 3 + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Text(
              '×${skill.weight}',
              style: _body(12.5, weight: FontWeight.w600, color: _c.accent),
            ),
          ),
        ),
        InkWell(
          key: Key('skill-remove-${skill.name}'),
          onTap: () => setState(() => _skills.remove(skill)),
          child: Padding(
            padding: const EdgeInsets.only(left: 2, right: 10),
            child: Text(
              '✕',
              style: _body(12.5, weight: FontWeight.w600, color: _c.accent),
            ),
          ),
        ),
      ],
    ),
  );

  int get _totalQuestions => _mix.reduce((a, b) => a + b);
  void _changeMix(int index, int delta, FocusNode focus) {
    if (index < 0 || index >= _mix.length) return;
    if (_mix[index] + delta < 0 || _totalQuestions + delta > 12) return;
    setState(() => _mix[index] += delta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focus.canRequestFocus) focus.requestFocus();
    });
  }

  Widget _interviewMix() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 10,
          child: Row(
            children: [
              for (var i = 0; i < _mix.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                if (_mix[i] > 0)
                  Expanded(
                    flex: _mix[i],
                    child: ColoredBox(color: _mixColors[i]),
                  ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < _mix.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: i == 0 ? null : Border(top: BorderSide(color: _c.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _mixColors[i],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mixNames[i],
                      style: _body(14, weight: FontWeight.w600),
                    ),
                    Text(
                      _isMobile
                          ? const [
                              'Hands-on skills',
                              'Past experience',
                              'Realistic scenarios',
                            ][i]
                          : _mixDetails[i],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body(12.5, color: _c.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: _isMobile ? 42 : 36,
                decoration: BoxDecoration(
                  color: _c.field,
                  border: Border.all(color: _c.borderStrong),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _isMobile ? 42 : 34,
                      child: TextButton(
                        key: Key('mix-minus-${_mixNames[i]}'),
                        focusNode: _mixFocus[i * 2],
                        onPressed: _mix[i] == 0
                            ? null
                            : () => _changeMix(i, -1, _mixFocus[i * 2]),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text('−', style: _body(17, color: _c.text2)),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        _mix[i].toString(),
                        textAlign: TextAlign.center,
                        style: _body(14.5, weight: FontWeight.w600).copyWith(
                          fontFeatures: [const FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _isMobile ? 42 : 34,
                      child: TextButton(
                        key: Key('mix-plus-${_mixNames[i]}'),
                        focusNode: _mixFocus[i * 2 + 1],
                        onPressed: _totalQuestions >= 12
                            ? null
                            : () => _changeMix(i, 1, _mixFocus[i * 2 + 1]),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text('+', style: _body(17, color: _c.text2)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text('Total questions', style: _body(12.5, color: _c.text3)),
          ),
          Text(
            _totalQuestions.toString(),
            style: _body(14.5, weight: FontWeight.w700),
          ),
        ],
      ),
    ],
  );

  Widget _aside() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _previewPanel(),
      const SizedBox(height: 16),
      _thresholdPanel(),
      const SizedBox(height: 16),
      _readinessPanel(),
      const SizedBox(height: 16),
      _actions(),
      const SizedBox(height: 2),
      Text(
        'Goes live immediately. Candidates can apply right away.',
        textAlign: TextAlign.center,
        style: _body(12.5, color: _c.text3),
      ),
    ],
  );

  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(22),
    bool beam = false,
  }) => Container(
    decoration: _cardDecoration(),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        if (beam)
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF10C79A),
                  Color(0xFF3E6FF0),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    ),
  );

  Widget _panelHeader(String title, {String? tag}) => Row(
    children: [
      Expanded(
        child: Text(title, style: _body(15, weight: FontWeight.w600)),
      ),
      if (tag != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: _c.accentSoft,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            tag,
            style: _body(12, weight: FontWeight.w600, color: _c.accent),
          ),
        ),
    ],
  );

  String _previewMeta() =>
      [_location ?? 'Location', _workType, _experience].join(' · ');
  (int, int)? _estimate() {
    if (_title.text.trim().isEmpty || _skills.isEmpty) return null;
    final salarySet = _money(_salaryMin) > 0 && _money(_salaryMax) > 0;
    final base =
        18 + _skills.length * 4 + (salarySet ? 8 : 0) - (_threshold - 60) / 2;
    final low = math.max(8, (base / 2).round() * 2);
    return (low, low + (low * .5 / 2).round() * 2);
  }

  Widget _previewPanel() {
    final estimate = _estimate();
    final salarySet = _money(_salaryMin) > 0 && _money(_salaryMax) > 0;
    return _panel(
      beam: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader('Live preview', tag: 'As candidates see it'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _c.surface2,
              border: Border.all(color: _c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title.text.trim().isEmpty
                      ? 'Role title'
                      : _title.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _heading(
                    17,
                    weight: FontWeight.w600,
                    color: _title.text.trim().isEmpty ? _c.text3 : _c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewMeta(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _body(13, color: _c.text2),
                ),
                const SizedBox(height: 10),
                Text(
                  salarySet
                      ? 'PKR ${_salaryMin.text} – ${_salaryMax.text} / month'
                      : 'Salary range',
                  style: _body(15, weight: FontWeight.w600),
                ),
                if (_skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in _skills.take(6))
                        _previewSkill(skill.name),
                      if (_skills.length > 6)
                        _previewSkill('+${_skills.length - 6}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.people_outline, size: 34, color: _c.accent),
              const SizedBox(width: 12),
              Expanded(
                child: estimate == null
                    ? Text(
                        'Add a title and skills to see an applicant estimate.',
                        style: _body(13.5, color: _c.text2),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${estimate.$1}–${estimate.$2} applicants',
                            key: const Key('create-role-estimate'),
                            style: _heading(20, weight: FontWeight.w600),
                          ),
                          Text(
                            'expected in week one, based on similar roles',
                            style: _body(13.5, color: _c.text2),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewSkill(String text) => Container(
    constraints: BoxConstraints(
      maxWidth: _isMobile
          ? math.max(100, MediaQuery.sizeOf(context).width - 100)
          : double.infinity,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _c.surface,
      border: Border.all(color: _c.border),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body(12.5, color: _c.text2),
    ),
  );

  String get _thresholdBand => _threshold < 55
      ? 'Open'
      : _threshold < 75
      ? 'Balanced'
      : 'Strict';
  Widget _thresholdPanel() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panelHeader('Screening threshold'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _threshold.round().toString(),
              key: const Key('create-role-threshold-value'),
              style: _heading(
                34,
              ).copyWith(fontFeatures: [const FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 10),
            Text(
              _thresholdBand,
              style: _body(13, weight: FontWeight.w600, color: _c.success),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(
                    stops: [0, .35, .65, 1],
                    colors: [
                      Color(0xFFEF5B5B),
                      Color(0xFFE9A83C),
                      Color(0xFF3E6FF0),
                      Color(0xFF14B584),
                    ],
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: _WhiteSliderThumb(_c.accent),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  key: const Key('create-role-threshold'),
                  min: 40,
                  max: 90,
                  divisions: 50,
                  value: _threshold,
                  onChanged: (value) =>
                      setState(() => _threshold = value.roundToDouble()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('40 · Open', style: _body(12, color: _c.text3)),
            const Spacer(),
            Text('90 · Strict', style: _body(12, color: _c.text3)),
          ],
        ),
        const SizedBox(height: 18),
        Container(height: 1, color: _c.border),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-shortlist',
                    style: _body(14, weight: FontWeight.w600),
                  ),
                  Text(
                    _autoShortlist
                        ? 'Applicants scoring ${_threshold.round()}+ who meet every requirement are shortlisted.'
                        : 'Off. You review every applicant manually.',
                    style: _body(12.5, color: _c.text3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Switch(
              key: const Key('create-role-auto-shortlist'),
              value: _autoShortlist,
              activeThumbColor: Colors.white,
              activeTrackColor: _c.accent,
              onChanged: (value) => setState(() => _autoShortlist = value),
            ),
          ],
        ),
      ],
    ),
  );

  List<(String, bool)> get _checklist {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min = _money(_salaryMin), max = _money(_salaryMax);
    return [
      ('Title', _title.text.trim().isNotEmpty),
      ('Location', _location != null),
      ('Salary', min > 0 && max >= min),
      ('Close date', _deadline != null && !_deadline!.isBefore(today)),
      ('Description', _description.text.trim().isNotEmpty),
      ('Skills', _skills.isNotEmpty),
    ];
  }

  Widget _readinessPanel() {
    final items = _checklist;
    final completed = items.where((item) => item.$2).length;
    return _panel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelHeader(
            'Ready to publish',
            tag: '$completed of ${items.length}',
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _c.surface2,
              border: Border.all(color: _c.border),
              borderRadius: BorderRadius.circular(99),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: completed / items.length),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) => LinearProgressIndicator(
                key: const Key('create-role-readiness-progress'),
                value: value,
                backgroundColor: Colors.transparent,
                color: _c.success,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _readinessItem(items[i])),
                const SizedBox(width: 12),
                Expanded(child: _readinessItem(items[i + 1])),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _readinessItem((String, bool) item) => Semantics(
    label: item.$1,
    checked: item.$2,
    child: Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: item.$2 ? _c.success : Colors.transparent,
            border: Border.all(
              color: item.$2 ? _c.success : _c.borderStrong,
              width: 1.5,
            ),
          ),
          child: item.$2
              ? const Icon(Icons.check, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            item.$1,
            style: _body(13, color: item.$2 ? _c.text2 : _c.text3),
          ),
        ),
      ],
    ),
  );

  Widget _actions() => Row(
    children: [
      if (widget.initialJob == null) ...[
        Expanded(
          flex: 10,
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              key: const Key('create-role-save-draft'),
              onPressed: _saving ? null : () => _saveRole(publish: false),
              style: OutlinedButton.styleFrom(
                backgroundColor: _c.surface,
                side: BorderSide(color: _c.borderStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Save draft',
                maxLines: 1,
                style: _body(14.5, weight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
      ],
      Expanded(
        flex: 14,
        child: SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: RecruiterButtonStyle.blue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _c.accent.withValues(alpha: .3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextButton(
              key: const Key('create-role-publish'),
              onPressed: _saving
                  ? null
                  : () => _saveRole(publish: widget.initialJob == null),
              child: Text(
                _saving
                    ? 'Saving…'
                    : widget.initialJob == null
                    ? 'Publish role'
                    : 'Save changes',
                maxLines: 1,
                style: _body(
                  14.5,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  String get _draftKey {
    final user = AuthService.currentUserData;
    final id =
        AuthService.currentUserId ??
        user?['clerk_id']?.toString() ??
        user?['id']?.toString() ??
        user?['email']?.toString() ??
        'anonymous';
    return 'create_role_draft_${Uri.encodeComponent(id)}';
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final restoredLocation = data['location']?.toString();
      final restoredWorkType = data['workType']?.toString();
      final restoredExperience = data['experience']?.toString();
      final restoredDeadline = DateTime.tryParse(
        data['deadline']?.toString() ?? '',
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final restoredThreshold = (data['threshold'] as num?)?.toDouble();
      final restoredSkills = (data['skills'] as List? ?? [])
          .whereType<Map>()
          .map((item) {
            final name = item['name']?.toString().trim() ?? '';
            final weight = (item['weight'] as num?)?.toInt() ?? 2;
            return _SelectedSkill(name, weight.clamp(1, 3));
          })
          .where((skill) => skill.name.isNotEmpty)
          .take(20)
          .toList();
      final restoredMix = data['mix'] as List?;
      final mixValues = restoredMix?.length == _mix.length
          ? restoredMix!.map((value) => (value as num?)?.toInt()).toList()
          : null;
      final validMix =
          mixValues != null &&
          mixValues.every((value) => value != null && value >= 0) &&
          mixValues.fold<int>(0, (sum, value) => sum + value!) <= 12;
      _title.text = data['title']?.toString() ?? '';
      _salaryMin.text = data['minimum']?.toString() ?? '';
      _salaryMax.text = data['maximum']?.toString() ?? '';
      _description.text = data['description']?.toString() ?? '';
      _requirements.text = data['requirements']?.toString() ?? '';
      _location = _cities.contains(restoredLocation) ? restoredLocation : null;
      _workType =
          const ['Remote', 'Hybrid', 'On-site'].contains(restoredWorkType)
          ? restoredWorkType!
          : 'Remote';
      _experience =
          const ['Junior', 'Mid', 'Senior', 'Lead'].contains(restoredExperience)
          ? restoredExperience!
          : 'Mid';
      _deadline = restoredDeadline != null && !restoredDeadline.isBefore(today)
          ? restoredDeadline
          : null;
      _threshold = restoredThreshold != null && restoredThreshold.isFinite
          ? restoredThreshold.clamp(40, 90)
          : 66;
      _autoShortlist = data['autoShortlist'] == true;
      _skills
        ..clear()
        ..addAll(restoredSkills);
      if (validMix) {
        for (var i = 0; i < _mix.length; i++) {
          _mix[i] = mixValues[i]!;
        }
      }
      setState(() {});
    } catch (_) {
      // A damaged local draft leaves the empty form available.
    }
  }

  Future<void> _saveLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setString(
      _draftKey,
      jsonEncode({
        'title': _title.text,
        'location': _location,
        'workType': _workType,
        'experience': _experience,
        'minimum': _salaryMin.text,
        'maximum': _salaryMax.text,
        'deadline': _deadline?.toIso8601String(),
        'description': _description.text,
        'requirements': _requirements.text,
        'skills': [
          for (final skill in _skills)
            {'name': skill.name, 'weight': skill.weight},
        ],
        'threshold': _threshold,
        'autoShortlist': _autoShortlist,
        'mix': _mix,
      }),
    );
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: _body(13.5, weight: FontWeight.w500, color: _c.background),
        ),
        duration: const Duration(milliseconds: 2400),
        behavior: SnackBarBehavior.floating,
        width: math.min(420, MediaQuery.sizeOf(context).width - 32),
        backgroundColor: _c.text,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _validatePublish() {
    _errors.clear();
    if (_title.text.trim().isEmpty) _errors['title'] = 'Add a role title.';
    if (_location == null) _errors['location'] = 'Choose a location.';
    final min = _money(_salaryMin), max = _money(_salaryMax);
    if (min <= 0 || max <= 0) {
      _errors['salary'] = 'Enter a salary range.';
    } else if (max < min) {
      _errors['salary'] = 'Maximum must be higher than minimum.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_deadline == null || _deadline!.isBefore(today)) {
      _errors['date'] = 'Pick a closing date.';
    }
    if (_description.text.trim().isEmpty) {
      _errors['description'] = 'Describe the role.';
    }
    if (_skills.isEmpty) _errors['skills'] = 'Add at least one skill.';
    setState(() {});
  }

  Future<void> _showFirstError() async {
    const order = [
      'title',
      'location',
      'salary',
      'date',
      'description',
      'skills',
    ];
    final index = order.indexWhere(_errors.containsKey);
    if (index < 0) return;
    final fieldContext = _sectionKeys[index].currentContext;
    if (fieldContext != null) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 350),
        alignment: .5,
      );
    }
    if (!mounted) return;
    if (index == 0 || index == 2 || index == 4 || index == 5) {
      (index == 5 ? _skillFocus : _fieldFocus[index]).requestFocus();
    } else if (index == 1) {
      _fieldFocus[1].requestFocus();
    }
    _toast(
      widget.initialJob == null
          ? 'Complete the highlighted fields to publish'
          : 'Complete the highlighted fields to save',
    );
  }

  JobType get _apiJobType => switch (_workType) {
    'Hybrid' => JobType.hybrid,
    'On-site' => JobType.onsite,
    _ => JobType.remote,
  };
  ExperienceLevel get _apiExperience => switch (_experience) {
    'Junior' => ExperienceLevel.entry,
    'Senior' || 'Lead' => ExperienceLevel.senior,
    _ => ExperienceLevel.mid,
  };

  Future<void> _saveRole({required bool publish}) async {
    if (_saving) return;
    if (publish || widget.initialJob != null) {
      _validatePublish();
      if (_errors.isNotEmpty) {
        await _showFirstError();
        return;
      }
    }
    setState(() => _saving = true);
    try {
      if (!publish &&
          widget.initialJob == null &&
          _checklist.any((item) => !item.$2)) {
        await _saveLocalDraft();
        if (mounted) _toast('Draft saved');
        return;
      }
      final payload = Job.writePayload(
        title: _title.text.trim(),
        description: _description.text.trim(),
        requirements: _requirements.text.trim(),
        skillsRequired: _skills.map((skill) => skill.name).toList(),
        location: _location!,
        salary: 'PKR ${_salaryMin.text}–${_salaryMax.text}',
        jobType: _apiJobType,
        experienceLevel: _apiExperience,
        deadline: _deadline!,
        // Match the displayed score and avoid slider floating-point precision
        // exceeding the API's DecimalField limits.
        // Match the whole-number threshold displayed to the recruiter, including
        // older drafts that may contain continuous-slider decimal values.
        screeningThreshold: _threshold.roundToDouble().roundToDouble(),
        autoShortlistEnabled: _autoShortlist,
        screeningCriteria: {
          ...?widget.initialJob?.screeningCriteria,
          'minimum_experience_years': switch (_experience) {
            'Junior' => 1.0,
            'Senior' || 'Lead' => 5.0,
            _ => 3.0,
          },
          'education_levels':
              widget.initialJob?.screeningCriteria['education_levels'] ??
              <String>[],
          'certifications':
              widget.initialJob?.screeningCriteria['certifications'] ??
              <String>[],
          'manual_review_required':
              widget.initialJob?.screeningCriteria['manual_review_required'] ??
              false,
          'question_mix': {
            for (var i = 0; i < _mix.length; i++)
              _mixNames[i].toLowerCase(): _mix[i],
          },
          'skill_weights': {
            for (final skill in _skills) skill.name: skill.weight,
          },
        },
      );
      final saved = _savedJobId == null
          ? await JobService.createJob(payload)
          : await JobService.updateJob(_savedJobId!, payload);
      _savedJobId = saved.id;
      if (widget.initialJob != null) {
        if (mounted) Navigator.of(context).pop(saved);
        return;
      }
      if (publish) {
        final published = await JobService.publishJob(saved.id, payload);
        if (!published.isActive) {
          throw StateError('The job API did not confirm publication.');
        }
      }
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      if (mounted) _toast(publish ? 'Role published' : 'Draft saved');
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        await AuthService.signOut(context);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
        return;
      }
      if (widget.initialJob != null &&
          error is ApiException &&
          error.statusCode == 404) {
        Navigator.of(context).pop(CreateRoleEditResult.notFound);
        return;
      }
      if (widget.initialJob != null &&
          error is ApiException &&
          error.statusCode == 403) {
        _toast("You're not authorized to perform this action.");
        return;
      }
      if (widget.initialJob != null &&
          error is ApiException &&
          (error.statusCode ?? 0) >= 500) {
        _toast('Server error. Please retry.');
        return;
      }
      if (error is ApiException && error.fieldErrors != null) {
        setState(() {
          for (final entry in error.fieldErrors!.entries) {
            final key = switch (entry.key) {
              'deadline' => 'date',
              'skills_required' => 'skills',
              _ => entry.key,
            };
            _errors[key] = entry.value.toString();
          }
        });
      }
      _toast(
        error is ApiException
            ? error.message
            : 'Could not save this role. Please retry.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SuggestedSkillChip extends StatefulWidget {
  const _SuggestedSkillChip({
    super.key,
    required this.name,
    this.height = 28,
    required this.borderColor,
    required this.textColor,
    required this.accentColor,
    required this.onTap,
  });

  final String name;
  final double height;
  final Color borderColor;
  final Color textColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_SuggestedSkillChip> createState() => _SuggestedSkillChipState();
}

class _SuggestedSkillChipState extends State<_SuggestedSkillChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => IntrinsicWidth(
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(99),
        child: CustomPaint(
          foregroundPainter: _DashedPillBorder(
            _hovered ? widget.accentColor : widget.borderColor,
            solid: _hovered,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.accentColor.withValues(alpha: .08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: SizedBox(
              height: widget.height,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 11),
                  Text(
                    '+ ${widget.name}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: _hovered ? widget.accentColor : widget.textColor,
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedPillBorder extends CustomPainter {
  const _DashedPillBorder(this.color, {this.solid = false});
  final Color color;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1),
          const Radius.circular(99),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (solid) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 6) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 3, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPillBorder oldDelegate) =>
      oldDelegate.color != color || oldDelegate.solid != solid;
}

class _WhiteSliderThumb extends SliderComponentShape {
  const _WhiteSliderThumb(this.accent, {this.radius = 11});
  final Color accent;
  final double radius;
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size(radius * 2, radius * 2);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    final border = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 1, border);
  }
}

// ─── Calendar Popover ─────────────────────────────────────────────────────────

class _CalendarPopover extends StatefulWidget {
  const _CalendarPopover({
    required this.anchorOffset,
    required this.anchorSize,
    required this.initialMonth,
    required this.selected,
    required this.today,
    required this.tokens,
    required this.bodyStyle,
    required this.headingStyle,
    required this.onSelect,
    required this.onClear,
    required this.onDismiss,
  });

  final Offset anchorOffset;
  final Size anchorSize;
  final DateTime initialMonth;
  final DateTime? selected;
  final DateTime today;
  final CreateRoleTokens tokens;
  final TextStyle Function(double, {Color? color, FontWeight weight}) bodyStyle;
  final TextStyle Function(double, {Color? color, FontWeight weight})
  headingStyle;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onClear;
  final VoidCallback onDismiss;

  @override
  State<_CalendarPopover> createState() => _CalendarPopoverState();
}

class _CalendarPopoverState extends State<_CalendarPopover>
    with SingleTickerProviderStateMixin {
  late DateTime _month;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  static const _popoverW = 320.0;
  static const _popoverH = 360.0;
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, -0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Compute popover left/top so it stays inside the screen
  Offset _position(Size screen) {
    double left = widget.anchorOffset.dx;
    double top = widget.anchorOffset.dy + widget.anchorSize.height + 6;

    // Flip left if it overflows right edge
    if (left + _popoverW > screen.width - 8) {
      left = screen.width - _popoverW - 8;
    }
    if (left < 8) left = 8;

    // Flip above if it overflows bottom
    if (top + _popoverH > screen.height - 8) {
      top = widget.anchorOffset.dy - _popoverH - 6;
    }
    return Offset(left, top);
  }

  List<DateTime?> _buildGrid() {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final startWeekday = firstOfMonth.weekday % 7; // Sun=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_month.year, _month.month, d));
    }
    // Pad to a multiple of 7
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  void _prevMonth() => setState(() {
    _month = DateTime(_month.year, _month.month - 1);
  });
  void _nextMonth() => setState(() {
    _month = DateTime(_month.year, _month.month + 1);
  });

  @override
  Widget build(BuildContext context) {
    final c = widget.tokens;
    final screen = MediaQuery.sizeOf(context);
    final pos = _position(screen);
    final grid = _buildGrid();

    return Stack(
      children: [
        // Dismiss barrier
        Positioned.fill(
          child: PointerGestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        // The popover card
        Positioned(
          left: pos.dx,
          top: pos.dy,
          width: _popoverW,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .14),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_monthNames[_month.month - 1]} ${_month.year}',
                                style: widget
                                    .headingStyle(15, weight: FontWeight.w700)
                                    .copyWith(letterSpacing: -.2),
                              ),
                            ),
                            // Up / prev month
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.keyboard_arrow_up,
                                  size: 20,
                                  color: c.text2,
                                ),
                                onPressed: _prevMonth,
                              ),
                            ),
                            // Down / next month
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: c.text2,
                                ),
                                onPressed: _nextMonth,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Weekday labels ──────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            for (final day in _days)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: widget.bodyStyle(
                                      12,
                                      weight: FontWeight.w600,
                                      color: c.text3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ── Day grid ────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            for (
                              var row = 0;
                              row < grid.length ~/ 7;
                              row++
                            ) ...[
                              Row(
                                children: [
                                  for (var col = 0; col < 7; col++)
                                    _DayCell(
                                      date: grid[row * 7 + col],
                                      selected: widget.selected,
                                      today: widget.today,
                                      tokens: c,
                                      bodyStyle: widget.bodyStyle,
                                      onTap: widget.onSelect,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // ── Footer ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: widget.onClear,
                              style: TextButton.styleFrom(
                                foregroundColor: c.accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Clear',
                                style: widget.bodyStyle(
                                  13.5,
                                  weight: FontWeight.w500,
                                  color: c.accent,
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => widget.onSelect(widget.today),
                              style: TextButton.styleFrom(
                                foregroundColor: c.accent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Today',
                                style: widget.bodyStyle(
                                  13.5,
                                  weight: FontWeight.w500,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.today,
    required this.tokens,
    required this.bodyStyle,
    required this.onTap,
  });

  final DateTime? date;
  final DateTime? selected;
  final DateTime today;
  final CreateRoleTokens tokens;
  final TextStyle Function(double, {Color? color, FontWeight weight}) bodyStyle;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const Expanded(child: SizedBox(height: 38));
    }
    final d = date!;
    final isSelected = selected != null && _sameDay(d, selected!);
    final isToday = _sameDay(d, today);
    final isPast = d.isBefore(today);

    final bg = isSelected
        ? tokens.accent
        : isToday
        ? tokens.accentSoft
        : Colors.transparent;
    final textColor = isSelected
        ? Colors.white
        : isPast
        ? tokens.text3
        : isToday
        ? tokens.accent
        : tokens.text;

    return Expanded(
      child: PointerGestureDetector(
        onTap: isPast ? null : () => onTap(d),
        child: Container(
          height: 38,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '${d.day}',
            style: bodyStyle(
              13,
              weight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
