import '../../widgets/mobile_edge_shadow_wrapper.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'aurora_tokens.dart';
import 'admin_primitives.dart';
import 'admin_data.dart';
import 'admin_csv_stub.dart'
    if (dart.library.js_interop) 'admin_csv_web.dart'
    if (dart.library.io) 'admin_csv_io.dart'
    as csv;

const adminRoutes = <String, String>{
  'AD-01': '/admin/overview',
  'AD-00': '/admin/first-launch',
  'AD-02': '/admin/users',
  'AD-03': '/admin/scoring',
  'AD-04': '/admin/audit',
  'AD-05': '/admin/analytics',
  'AD-06': '/admin/models',
  'AD-07': '/admin/retention',
};
const adminNames = <String, String>{
  'AD-01': 'Overview',
  'AD-00': 'First launch',
  'AD-02': 'User management',
  'AD-03': 'Global scoring',
  'AD-04': 'Audit log',
  'AD-05': 'System analytics',
  'AD-06': 'AI models',
  'AD-07': 'Data retention',
};
const adminIcons = <String, IconData>{
  'AD-01': Icons.space_dashboard_outlined,
  'AD-00': Icons.auto_awesome_outlined,
  'AD-02': Icons.people_outline,
  'AD-03': Icons.tune_outlined,
  'AD-04': Icons.receipt_long_outlined,
  'AD-05': Icons.show_chart_outlined,
  'AD-06': Icons.memory_outlined,
  'AD-07': Icons.storage_outlined,
};

class AdminPortal extends StatefulWidget {
  const AdminPortal({
    super.key,
    required this.module,
    this.initialAnalyticsTab,
    this.onSignOut,
  });
  final String module;
  final String? initialAnalyticsTab;
  final VoidCallback? onSignOut;
  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  bool expanded = false;
  String analyticsTab = 'Usage';
  @override
  void initState() {
    super.initState();
    analyticsTab = widget.initialAnalyticsTab == 'Integrity'
        ? 'Integrity'
        : 'Usage';
    load();
    poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!loading && !saving && ['AD-01', 'AD-05'].contains(widget.module)) {
        load();
      }
    });
  }

  void go(String id, {String? tab}) {
    if (id == widget.module && tab == null) return;
    Navigator.pushReplacementNamed(context, adminRoutes[id]!, arguments: tab);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final mobile = c.maxWidth < 900;
      final t = context.aurora;
      return Scaffold(
        backgroundColor: t.bg,
        body: mobile ? _mobileShell() : _webShell(),
        bottomNavigationBar: mobile ? _bottomNav() : null,
      );
    },
  );
  Widget _webShell() {
    final t = context.aurora;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: expanded ? 246 : 76,
          decoration: BoxDecoration(
            color: t.knob.withValues(alpha: .76),
            border: Border(right: BorderSide(color: t.edge)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 76,
                child: Row(
                  children: [
                    const SizedBox(width: 17),
                    _brandMark(),
                    if (expanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SkillSense',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: t.tx,
                              ),
                            ),
                            MonoText(
                              'AURORA CONSOLE',
                              style: TextStyle(fontSize: 8, color: t.tx3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: InkWell(
                  onTap: () => setState(() => expanded = !expanded),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: t.field,
                      border: Border.all(color: t.edge),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.dock_outlined, size: 18, color: t.tx2),
                        if (expanded) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Collapse rail',
                            style: TextStyle(color: t.tx2, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    _navGroup('PLATFORM', ['AD-01', 'AD-00', 'AD-02']),
                    _navGroup('GOVERNANCE', ['AD-03', 'AD-04', 'AD-07']),
                    _navGroup('OPERATIONS', ['AD-05', 'AD-06']),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _avatar('A'),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Admin',
                        style: TextStyle(color: t.tx, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: t.knob.withValues(alpha: .45),
                  border: Border(bottom: BorderSide(color: t.edge2)),
                ),
                child: Row(
                  children: [
                    CapText(
                      'SKILLSENSE  /  ADMIN  /  ${adminNames[widget.module]!.toUpperCase()}',
                      style: TextStyle(color: t.tx2),
                    ),
                    const Spacer(),
                    _signOutButton(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: _page(false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navGroup(String title, List<String> ids) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 3, 0, 9),
              child: CapText(title),
            ),
          ...ids.map((id) {
            final active = id == widget.module;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Tooltip(
                message: adminNames[id]!,
                child: InkWell(
                  onTap: () => go(id),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: active
                          ? t.gd.withValues(alpha: .09)
                          : Colors.transparent,
                      border: Border.all(
                        color: active
                            ? t.gd.withValues(alpha: .25)
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          adminIcons[id],
                          size: 19,
                          color: active ? t.gd : t.tx3,
                        ),
                        if (expanded) ...[
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              adminNames[id]!,
                              style: TextStyle(
                                color: active ? t.gd : t.tx3,
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (active) AdminLed(tone: AdminTone.blue),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _brandMark() {
    final t = context.aurora;
    return Container(
      width: 41,
      height: 41,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.edge),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('✦', style: TextStyle(color: t.gd, fontSize: 23)),
    );
  }

  Widget _avatar(String v) {
    final t = context.aurora;
    return Container(
      width: 33,
      height: 33,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.glass,
        border: Border.all(color: t.edge),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        v,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          color: t.gd,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _mobileShell() {
    final t = context.aurora;
    return Column(
      children: [
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: t.knob.withValues(alpha: .65),
            border: Border(bottom: BorderSide(color: t.edge)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _showNavDrawer,
                icon: Icon(Icons.menu, color: t.tx2, size: 21),
              ),
              const Spacer(),
              Text(
                '✦  SkillSense ',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: t.tx,
                  fontSize: 13,
                ),
              ),
              Text(
                'Admin',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  color: t.gd,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _signOutButton(),
            ],
          ),
        ),
        Expanded(
          child: MobileEdgeShadowWrapper(
            surfaceColor: t.bg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(17, 19, 17, 25),
              child: _page(true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _signOutButton() => IconButton(
    tooltip: 'Sign out',
    onPressed: widget.onSignOut,
    icon: Icon(Icons.logout, color: context.aurora.tx2, size: 20),
  );

  Widget _bottomNav() {
    final t = context.aurora;
    final ids = ['AD-01', 'AD-02', 'AD-04', 'more'];
    final labels = ['Overview', 'Users', 'Audit', 'More'];
    final icons = [
      Icons.space_dashboard_outlined,
      Icons.people_outline,
      Icons.receipt_long_outlined,
      Icons.more_horiz,
    ];
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: t.knob,
        border: Border(top: BorderSide(color: t.edge)),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final active = ids[i] == widget.module;
          return Expanded(
            child: InkWell(
              onTap: i == 3 ? _showNavDrawer : () => go(ids[i]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[i], size: 21, color: active ? t.gd : t.tx3),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: active ? t.gd : t.tx3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showNavDrawer() {
    final t = context.aurora;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close navigation',
      barrierColor: Colors.black54,
      pageBuilder: (c, _, __) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: t.knob,
          child: SizedBox(
            width: 285,
            height: double.infinity,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        _brandMark(),
                        const SizedBox(width: 12),
                        Text(
                          'Aurora Console',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: t.tx,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: adminRoutes.keys
                          .map(
                            (id) => ListTile(
                              leading: Icon(
                                adminIcons[id],
                                color: id == widget.module ? t.gd : t.tx3,
                              ),
                              title: Text(
                                adminNames[id]!,
                                style: TextStyle(
                                  color: id == widget.module ? t.gd : t.tx2,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(c);
                                go(id);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  final api = AdminApi();
  Timer? poll, searchTimer;
  Map<String, dynamic>? data;
  List<AdminRecord> rubrics = [];
  bool loading = false, saving = false;
  String? failure;
  DateTime? updated;
  int page = 1;
  String search = '';
  String? accountRole, accountStatus;
  Object? loadToken;
  bool get paginated => ['AD-02', 'AD-04'].contains(widget.module);

  Future<void> load({bool reset = false}) async {
    final token = Object();
    loadToken = token;
    setState(() {
      loading = true;
      failure = null;
      if (reset) {
        data = null;
        updated = null;
      }
    });
    try {
      final path = switch (widget.module) {
        'AD-02' => 'users',
        'AD-03' => 'integrity-thresholds',
        'AD-04' => 'audit-log',
        'AD-05' when analyticsTab == 'Usage' => 'analytics',
        'AD-06' || 'AD-07' => 'operations',
        _ => 'overview',
      };
      final snapshot = await api.request<AdminRecord>(
        path,
        query: paginated
            ? {
                'page': page,
                'page_size': 20,
                'search': search,
                if (accountRole != null) 'role': accountRole,
                if (accountStatus != null) 'is_active': accountStatus,
              }
            : null,
      );
      final versions = widget.module == 'AD-03'
          ? adminRows(await api.request<List<dynamic>>('rubrics'))
          : <AdminRecord>[];
      if (!mounted || loadToken != token) return;
      setState(() {
        data = snapshot;
        rubrics = versions;
        updated =
            DateTime.tryParse('${snapshot['updated_at']}') ?? DateTime.now();
      });
    } catch (error) {
      if (mounted && loadToken == token) {
        setState(() {
          failure = message(error, 'Could not load admin data.');
          if (error is DioException &&
              [401, 403].contains(error.response?.statusCode)) {
            data = null;
            updated = null;
          }
        });
      }
    } finally {
      if (mounted && loadToken == token) setState(() => loading = false);
    }
  }

  String message(Object error, String fallback) {
    if (error is DioException) {
      return switch (error.response?.statusCode) {
        401 => 'Your session expired. Sign in again.',
        403 => 'This account cannot access this operation.',
        _ => fallback,
      };
    }
    return fallback;
  }

  Future<void> save(String path, String method, [AdminRecord? values]) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await api.request<AdminRecord>(path, method: method, data: values);
      if (!mounted) return;
      AdminToast.show(context, 'Change saved');
      await load();
    } catch (error) {
      if (mounted) {
        AdminToast.show(context, message(error, 'Could not save the change.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String time(Object? raw) {
    final date = raw is DateTime ? raw : DateTime.tryParse('$raw');
    return date
            ?.toLocal()
            .toIso8601String()
            .replaceFirst('T', ' ')
            .substring(0, 19) ??
        '—';
  }

  static const headings = {
    'AD-01': (
      'Platform / Overview',
      'Admin dashboard',
      'A single view of integrity risk, usage and infrastructure health.',
    ),
    'AD-00': (
      'Platform / First launch',
      'First-launch dashboard',
      'Set up your workspace and follow its first activity.',
    ),
    'AD-02': (
      'Access control / Accounts',
      'User management',
      'Search, review and manage platform accounts with confirmation safeguards.',
    ),
    'AD-03': (
      'Policy / Rubric defaults',
      'Global scoring config',
      'Manage scoring rubric versions and integrity display thresholds.',
    ),
    'AD-04': (
      'Governance / Event history',
      'Audit log',
      'An append-only view of important platform and administration events.',
    ),
    'AD-05': (
      'Operations / Intelligence',
      'System analytics',
      'Review interview completion, application activity and integrity signals.',
    ),
    'AD-06': (
      'Operations / Model control',
      'AI model config',
      'Review the model versions and features configured on the backend.',
    ),
    'AD-07': (
      'Governance / Privacy',
      'Data retention',
      'Review configured retention windows and records due for review.',
    ),
  };

  Widget _page(bool mobile) {
    final snapshot = data;
    final timestamp = updated;
    final (section, title, description) = headings[widget.module]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CapText(
          section.toUpperCase(),
          style: TextStyle(color: context.aurora.gd),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: mobile ? 24 : 33,
            color: context.aurora.tx,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: TextStyle(color: context.aurora.tx2, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (timestamp != null)
              AdminTag(
                'Updated ${time(timestamp)}',
                tone: failure == null ? AdminTone.green : AdminTone.amber,
              ),
            AdminButton(
              'Refresh',
              icon: Icons.refresh,
              onPressed: loading || saving ? null : () => load(),
            ),
            if (widget.module == 'AD-05')
              for (final tab in ['Usage', 'Performance', 'Integrity'])
                ChoiceChip(
                  label: Text(tab == 'Integrity' ? 'Incidents' : tab),
                  selected: analyticsTab == tab,
                  onSelected: (_) {
                    if (analyticsTab == tab) return;
                    setState(() => analyticsTab = tab);
                    load(reset: true);
                  },
                ),
          ],
        ),
        if (paginated)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: widget.module == 'AD-02'
                    ? 'Search name, email or company'
                    : 'Search action, target or ID',
              ),
              onChanged: (value) {
                searchTimer?.cancel();
                searchTimer = Timer(const Duration(milliseconds: 300), () {
                  search = value.trim();
                  page = 1;
                  load(reset: true);
                });
              },
            ),
          ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (failure case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AdminCallout(
              title: error,
              description: snapshot == null
                  ? 'Select Refresh to retry.'
                  : 'Showing the last successful update.',
            ),
          ),
        if (snapshot != null)
          switch (widget.module) {
            'AD-00' => firstLaunch(snapshot),
            'AD-02' => accounts(snapshot, mobile),
            'AD-03' => scoring(snapshot),
            'AD-04' => audit(snapshot, mobile),
            'AD-05' => analytics(snapshot),
            'AD-06' => models(snapshot),
            'AD-07' => retention(snapshot),
            _ => dashboard(snapshot),
          },
      ],
    );
  }

  Widget panel(String title, List<Widget> children, {bool hot = false}) =>
      AdminPanel(
        title: title,
        hot: hot,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget line(
    String label,
    Object? value, {
    AdminTone tone = AdminTone.neutral,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: MonoText(
            '${value ?? '—'}',
            textAlign: TextAlign.end,
            style: TextStyle(color: toneColor(context.aurora, tone)),
          ),
        ),
      ],
    ),
  );

  Widget grid(List<Widget> cards, double minWidth) => LayoutBuilder(
    builder: (context, box) {
      const gap = 14.0;
      final columns = ((box.maxWidth + gap) / (minWidth + gap)).floor().clamp(
        1,
        cards.length,
      );
      final width = (box.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final card in cards) SizedBox(width: width, child: card),
        ],
      );
    },
  );

  Widget stat(
    String label,
    Object? value, {
    String? note,
    bool danger = false,
  }) => AdminStat(
    label: label,
    value: '${value ?? '—'}',
    danger: danger,
    footer: note == null ? null : Text(note),
  );

  Widget dashboard(AdminRecord value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      overviewStats(value),
      const SizedBox(height: 16),
      pair(
        serviceHealth(value),
        panel(
          'Recent alerts',
          alertRows(value['recent_alerts'], 'No alerts in the last 7 days.'),
        ),
        leftFlex: 5,
        rightFlex: 6,
      ),
      const SizedBox(height: 16),
      pair(
        panel('Integrity review queue', [
          line(
            'Sessions with recorded signals',
            value['flagged_sessions'],
            tone: AdminTone.red,
          ),
          Text(
            'Detection signals require human review.',
            style: TextStyle(color: context.aurora.tx3, fontSize: 11),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminButton(
              'View incidents',
              kind: AdminButtonKind.text,
              onPressed: () => go('AD-05', tab: 'Integrity'),
            ),
          ),
        ]),
        panel('Processing volume', [
          MonoText(
            "${value['screening_succeeded_7d']}",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: AdminTag('AI PIPELINE', tone: AdminTone.blue),
          ),
          line(
            'Screening assessments completed in the last 7 days',
            value['screening_succeeded_7d'],
          ),
          line('Queued or in progress', value['screening_pending']),
        ]),
      ),
    ],
  );

  Widget pair(
    Widget left,
    Widget right, {
    int leftFlex = 1,
    int rightFlex = 1,
  }) => LayoutBuilder(
    builder: (_, size) => size.maxWidth < 720
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: 16),
              Expanded(flex: rightFlex, child: right),
            ],
          ),
  );

  Widget overviewStats(AdminRecord value) => grid([
    stat(
      'Total users',
      value['total_users'],
      note: "${value['new_users_7d']} joined in the last 7 days",
    ),
    stat('Active jobs', value['active_jobs']),
    stat('Interviews completed', value['completed_interviews']),
    stat(
      'Integrity flags',
      value['flagged_sessions'],
      note: 'Sessions with recorded signals',
      danger: (value['flagged_sessions'] as int) > 0,
    ),
  ], 225);

  Widget serviceHealth(AdminRecord value) {
    final broker = value['broker_available'] == true;
    return panel('Service health', [
      grid([
        telemetry('API latency', '—', 'p95 unavailable', AdminTone.neutral),
        telemetry(
          'Video frame queue',
          "${value['pending_frame_jobs']}",
          'Pending jobs',
          AdminTone.blue,
        ),
      ], 140),
      const SizedBox(height: 12),
      line('Django REST API', 'Responding', tone: AdminTone.green),
      line(
        'Celery broker',
        broker ? 'Reachable' : 'Unavailable',
        tone: broker ? AdminTone.green : AdminTone.amber,
      ),
      line('Database', 'Responding', tone: AdminTone.green),
    ], hot: true);
  }

  Widget telemetry(
    String label,
    String value,
    String caption,
    AdminTone tone,
  ) => AdminPanel(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapText(label.toUpperCase()),
        MonoText(
          value,
          style: TextStyle(
            fontSize: 25,
            color: toneColor(context.aurora, tone),
          ),
        ),
        AdminTag(caption, tone: tone),
      ],
    ),
  );

  Widget firstLaunch(AdminRecord value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      overviewStats(value),
      const SizedBox(height: 16),
      pair(
        panel('Build your first workspace', [
          const CapText('QUICK START'),
          line('Set up platform accounts', value['total_users']),
          line('Publish an active job', value['active_jobs']),
          line('Complete an interview', value['completed_interviews']),
          Align(
            alignment: Alignment.centerLeft,
            child: AdminButton(
              'Open user management',
              kind: AdminButtonKind.primary,
              onPressed: () => go('AD-02'),
            ),
          ),
        ], hot: true),
        serviceHealth(value),
      ),
    ],
  );

  List<Widget> alertRows(Object? payload, String empty) {
    final rows = adminRows(payload);
    return [
      if (rows.isEmpty) Text(empty),
      for (final row in rows)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const AdminLed(tone: AdminTone.amber),
          title: Text('${row['title']}'),
          subtitle: Text('${time(row['created_at'])}\n${row['id']}'),
        ),
    ];
  }

  Widget paging(AdminRecord value) => Wrap(
    spacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text("Page $page · ${value['count']} results"),
      AdminButton(
        'Previous',
        onPressed: loading || value['previous'] == null
            ? null
            : () {
                page--;
                load(reset: true);
              },
      ),
      AdminButton(
        'Next',
        onPressed: loading || value['next'] == null
            ? null
            : () {
                page++;
                load(reset: true);
              },
      ),
    ],
  );

  Widget table(List<String> labels, List<DataRow> rows) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: box.maxWidth),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(context.aurora.field),
          columnSpacing: 20,
          columns: [
            for (final label in labels) DataColumn(label: CapText(label)),
          ],
          rows: rows,
        ),
      ),
    ),
  );

  String nameOf(AdminRecord row) {
    final name = "${row['first_name']} ${row['last_name']}".trim();
    return name.isEmpty ? '${row['email']}' : name;
  }

  Widget accounts(AdminRecord value, bool mobile) {
    final rows = adminRows(value['results']);
    return AdminPanel(
      title: 'Platform accounts',
      trailing: AdminTag("${value['count']} ACCOUNTS"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              accountFilter(
                'Role',
                accountRole ?? '',
                const {
                  '': 'All roles',
                  'ADMIN': 'Admin',
                  'RECRUITER': 'Recruiter',
                  'CANDIDATE': 'Candidate',
                },
                (value) => accountRole = value.isEmpty ? null : value,
              ),
              accountFilter(
                'Status',
                accountStatus ?? '',
                const {'': 'Any status', 'true': 'Active', 'false': 'Inactive'},
                (value) => accountStatus = value.isEmpty ? null : value,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty) const Text('No matching accounts.'),
          if (mobile)
            ...rows.map(account)
          else if (rows.isNotEmpty)
            table(
              [
                'USER / EMAIL',
                'ROLE',
                'CREATED',
                'STATUS',
                'USER ID',
                'ACTIONS',
              ],
              [
                for (final row in rows)
                  DataRow(
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nameOf(row)),
                            MonoText(
                              '${row['email']}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      DataCell(AdminTag('${row['role']}')),
                      DataCell(
                        MonoText(time(row['created_at']).split(' ').first),
                      ),
                      DataCell(
                        AdminTag(
                          row['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                          tone: row['is_active'] == true
                              ? AdminTone.green
                              : AdminTone.amber,
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: '${row['id']}',
                          child: MonoText('${row['id']}'.split('-').first),
                        ),
                      ),
                      DataCell(accountAction(row) ?? const Text('—')),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: 10),
          paging(value),
        ],
      ),
    );
  }

  Widget accountFilter(
    String label,
    String selected,
    Map<String, String> items,
    ValueChanged<String> select,
  ) => SizedBox(
    width: 155,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: selected,
          items: [
            for (final entry in items.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value == null || value == selected) return;
            select(value);
            page = 1;
            load(reset: true);
          },
        ),
      ),
    ),
  );

  Widget account(AdminRecord row) {
    final name = "${row['first_name']} ${row['last_name']}".trim();
    final active = row['is_active'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name.isEmpty ? '${row['email']}' : name),
      subtitle: Text(
        [
          if (name.isNotEmpty) '${row['email']}',
          row['role'],
          if (row['company'] != '') row['company'],
          active ? 'Active' : 'Inactive',
        ].join(' · '),
      ),
      trailing: accountAction(row),
    );
  }

  Widget? accountAction(AdminRecord row) {
    final active = row['is_active'] == true;
    final action = active ? 'Deactivate' : 'Activate';
    return row['role'] == 'ADMIN'
        ? null
        : AdminButton(
            action,
            onPressed: saving
                ? null
                : () async {
                    final confirmed = await AdminModal.confirm(
                      context,
                      title: '$action account',
                      message: "$action ${row['email']}?",
                      confirmLabel: action,
                      destructive: active,
                    );
                    if (mounted && confirmed) {
                      await save('users/${row['id']}', 'PATCH', {
                        'is_active': !active,
                      });
                    }
                  },
          );
  }

  static const weights = {
    'weight_match': 'Resume match',
    'weight_interview': 'Interview',
    'weight_behavioral': 'Behavioral',
  };
  static const thresholds = {
    'look_away_limit': 'Look-away count limit',
    'integrity_flag_limit': 'Integrity signal count limit',
  };

  Widget scoring(AdminRecord value) => pair(
    panel('Default scoring weights', [
      Align(
        alignment: Alignment.centerLeft,
        child: AdminButton(
          'Create rubric',
          icon: Icons.add,
          onPressed: saving ? null : createRubric,
        ),
      ),
      if (rubrics.isEmpty) const Text('No scoring rubrics have been created.'),
      for (final row in rubrics)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("${row['name']} · Version ${row['version']}"),
          subtitle: Text(
            weights.entries
                .map((field) {
                  final percent = (row[field.key] as num) * 100;
                  return '${field.value} ${percent.toStringAsFixed(1)}%';
                })
                .join(' · '),
          ),
          trailing: row['active'] == true
              ? const AdminTag('Active', tone: AdminTone.green)
              : row['policy_version'] != 'COMBINED_V1'
              ? const AdminTag('Legacy')
              : AdminButton(
                  'Activate',
                  onPressed: saving
                      ? null
                      : () async {
                          final confirmed = await AdminModal.confirm(
                            context,
                            title: 'Activate scoring rubric',
                            message:
                                "Use ${row['name']} version ${row['version']} as the active rubric?",
                            confirmLabel: 'Activate',
                          );
                          if (mounted && confirmed) {
                            await save('rubrics/${row['id']}/activate', 'POST');
                          }
                        },
                ),
        ),
    ]),
    panel('Integrity display thresholds', [
      for (final field in thresholds.entries)
        line(field.value, value[field.key]),
      Align(
        alignment: Alignment.centerLeft,
        child: AdminButton(
          'Edit thresholds',
          onPressed: saving ? null : () => editThresholds(value),
        ),
      ),
    ]),
  );

  Future<void> createRubric() async {
    final fields = await edit(
      'Create scoring rubric',
      {
        'name': 'Rubric name',
        'weight_match': 'Resume match (%)',
        'weight_interview': 'Interview (%)',
      },
      const {'weight_match': '40', 'weight_interview': '60'},
      (values) {
        final name = (values['name'] ?? '').trim();
        if (name.isEmpty || name.length > 100) {
          return 'Enter a rubric name up to 100 characters.';
        }
        final match = percentagePoints(values['weight_match']);
        final interview = percentagePoints(values['weight_interview']);
        if (match == null || interview == null || match + interview != 10000) {
          return 'Enter two positive weights totaling 100%, with up to two decimal places.';
        }
        return null;
      },
    );
    if (mounted && fields != null) {
      await save('rubrics', 'POST', {
        'name': fields['name']!.trim(),
        'weight_match': percentagePoints(fields['weight_match'])! / 10000,
        'weight_interview':
            percentagePoints(fields['weight_interview'])! / 10000,
        'weight_behavioral': 0,
      });
    }
  }

  int? percentagePoints(String? raw) {
    final text = raw?.trim() ?? '';
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(text)) return null;
    final points = (double.parse(text) * 100).round();
    return points > 0 && points < 10000 ? points : null;
  }

  Future<void> editThresholds(AdminRecord value) async {
    final fields = await edit(
      'Edit integrity display thresholds',
      thresholds,
      {for (final key in thresholds.keys) key: '${value[key]}'},
      (values) {
        for (final key in thresholds.keys) {
          final n = int.tryParse(values[key] ?? '');
          if (n == null || n < 0 || n > 2147483647) {
            return 'Enter non-negative whole numbers up to 2147483647.';
          }
        }
        return null;
      },
    );
    if (mounted && fields != null) {
      await save('integrity-thresholds', 'PATCH', {
        for (final key in thresholds.keys) key: int.parse(fields[key]!),
      });
    }
  }

  Future<Map<String, String>?> edit(
    String title,
    Map<String, String> labels,
    Map<String, String> initial,
    String? Function(Map<String, String>) validate,
  ) {
    final values = Map<String, String>.of(initial);
    String? error;
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, dialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in labels.entries)
                  TextFormField(
                    initialValue: initial[field.key],
                    decoration: InputDecoration(labelText: field.value),
                    keyboardType: field.key == 'name'
                        ? TextInputType.text
                        : const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => values[field.key] = value,
                  ),
                if (error != null)
                  Text(error!, style: TextStyle(color: context.aurora.pr)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final issue = validate(values);
                if (issue == null) {
                  Navigator.pop(context, values);
                } else {
                  dialogState(() => error = issue);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget audit(AdminRecord value, bool mobile) {
    final rows = adminRows(value['results']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminCallout(
          title: 'Immutable activity history',
          description: 'Audit entries are read-only.',
          tone: AdminTone.blue,
        ),
        const SizedBox(height: 16),
        AdminPanel(
          title: 'Event history',
          trailing: rows.isEmpty
              ? null
              : AdminButton(
                  mobile ? 'CSV' : 'Export CSV',
                  icon: Icons.download_outlined,
                  onPressed: () => exportAudit(rows),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rows.isEmpty) const Text('No matching audit entries.'),
              if (mobile)
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${row['action']}'),
                    subtitle: Text(
                      "${row['target_type']} ${row['target_id']}\n${time(row['created_at'])}",
                    ),
                  )
              else if (rows.isNotEmpty)
                table(
                  ['EVENT TYPE', 'ACTOR', 'TIMESTAMP', 'DETAILS'],
                  [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          DataCell(AdminTag('${row['action']}')),
                          DataCell(
                            MonoText(
                              '${row['actor'] ?? 'System / unavailable'}',
                            ),
                          ),
                          DataCell(MonoText(time(row['created_at']))),
                          DataCell(
                            Text("${row['target_type']} ${row['target_id']}"),
                          ),
                        ],
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              paging(value),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> exportAudit(List<AdminRecord> rows) async {
    String escape(Object? field) {
      final text = field?.toString() ?? '';
      final safe = RegExp(r'^\s*[=+\-@]|\t|\r').hasMatch(text)
          ? "'$text"
          : text;
      return '"${safe.replaceAll('"', '""')}"';
    }

    final content = [
      [
        'Action',
        'Target type',
        'Target ID',
        'Actor ID',
        'Timestamp',
        'Metadata',
      ],
      for (final row in rows)
        [
          row['action'],
          row['target_type'],
          row['target_id'],
          row['actor'],
          row['created_at'],
          jsonEncode(row['metadata']),
        ],
    ].map((row) => row.map(escape).join(',')).join('\r\n');
    try {
      if (await csv.downloadCsv('skillsense-audit-log.csv', content)) return;
    } catch (_) {
      // Report a failed export consistently on each platform.
    }
    if (mounted) AdminToast.show(context, 'CSV export could not be saved.');
  }

  Widget analytics(AdminRecord value) {
    if (analyticsTab == 'Performance') {
      return pair(
        serviceHealth(value),
        panel('Screening throughput', [
          line('Completed in the last 7 days', value['screening_succeeded_7d']),
          line('Queued or in progress', value['screening_pending']),
        ]),
      );
    }
    if (analyticsTab == 'Integrity') {
      return panel('Integrity signals', [
        line(
          'Sessions with recorded integrity signals',
          value['flagged_sessions'],
        ),
        ...alertRows(
          value['recent_integrity_signals'],
          'No integrity signals recorded in the last 7 days.',
        ),
      ]);
    }
    final statuses = value['applications_by_status'] as AdminRecord;
    final score = value['average_score'] as num?;
    final rate = (value['interview_completion_rate'] as num) * 100;
    final total = statuses.values.fold<int>(
      0,
      (sum, count) => sum + (count as int),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(
          panel('Interview completion rate', [
            MonoText(
              '${rate.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            LinearProgressIndicator(value: rate / 100),
            const SizedBox(height: 10),
            const Text('Share of started interviews marked completed'),
          ], hot: true),
          stat('Average ranked score', score?.toStringAsFixed(1)),
        ),
        const SizedBox(height: 16),
        panel('Applications by status', [
          for (final entry in statuses.entries) ...[
            line(entry.key.toLowerCase().replaceAll('_', ' '), entry.value),
            if (total > 0)
              LinearProgressIndicator(value: (entry.value as int) / total),
          ],
        ]),
      ],
    );
  }

  Widget models(AdminRecord value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminCallout(
        title: 'Privileged system configuration',
        description: 'Model versions are set by the deployed backend.',
        tone: AdminTone.blue,
      ),
      const SizedBox(height: 16),
      AdminPanel(
        title: 'Active model versions',
        child: grid([
          for (final entry in (value['models'] as AdminRecord).entries)
            telemetry(
              entry.key,
              '${entry.value}',
              'Configured',
              AdminTone.blue,
            ),
          telemetry(
            'Behavioral observation',
            value['behavioral_observation_enabled'] == true
                ? 'Enabled'
                : 'Disabled',
            'Deployment setting',
            AdminTone.neutral,
          ),
        ], 265),
      ),
    ],
  );

  Widget retention(AdminRecord value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminCallout(
        title: 'Lifecycle and privacy controls',
        description:
            'Review records older than their configured retention window.',
        tone: AdminTone.blue,
      ),
      const SizedBox(height: 16),
      AdminPanel(
        title: 'Retention periods',
        trailing: const AdminTag('CURRENT POLICY'),
        child: Column(
          children: [
            for (final row in adminRows(value['retention'])) ...[
              line('${row['name']}', "${row['days']} days"),
              line('Records due for review', row['review_due']),
              const Divider(),
            ],
          ],
        ),
      ),
    ],
  );

  @override
  void dispose() {
    poll?.cancel();
    searchTimer?.cancel();
    api.dispose();
    super.dispose();
  }
}
