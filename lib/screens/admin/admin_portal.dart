import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  'AD-06': 'AI model config',
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
  });
  final String module;
  final String? initialAnalyticsTab;
  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  bool expanded = false;
  String analyticsTab = 'Usage';
  bool refreshed = false;
  final store = AdminStore.instance;
  @override
  void initState() {
    super.initState();
    analyticsTab = widget.initialAnalyticsTab ?? 'Usage';
    if (widget.module == 'AD-04' && store.audit.length > 8) {
      to = store.audit.first.date.substring(0, 10);
    }
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
                                fontFamily: 'Space Grotesk',
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
                    _avatar('SA'),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Text(
                        'System Admin',
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
                    MonoText(
                      'PRODUCTION',
                      style: TextStyle(color: t.tx3, fontSize: 9),
                    ),
                    const SizedBox(width: 16),
                    const AdminLed(pulse: true),
                    const SizedBox(width: 7),
                    MonoText(
                      'ALL SYSTEMS',
                      style: TextStyle(color: t.tx3, fontSize: 9),
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      onPressed: () => go('AD-04'),
                      icon: Icon(
                        Icons.notifications_none,
                        color: t.tx2,
                        size: 19,
                      ),
                    ),
                    _avatar('SA'),
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
          fontFamily: 'Space Grotesk',
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
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  color: t.tx,
                  fontSize: 13,
                ),
              ),
              Text(
                'Admin',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  color: t.gd,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _avatar('SA'),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(17, 19, 17, 25),
            child: _page(true),
          ),
        ),
      ],
    );
  }

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
                      fontFamily: 'Space Grotesk',
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
                            fontFamily: 'Space Grotesk',
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

  Widget _page(bool mobile) => switch (widget.module) {
    'AD-01' => _dashboard(mobile),
    'AD-00' => _firstLaunch(mobile),
    'AD-02' => _users(mobile),
    'AD-03' => _scoring(mobile),
    'AD-04' => _audit(mobile),
    'AD-05' => _analytics(mobile),
    'AD-06' => _models(mobile),
    'AD-07' => _retention(mobile),
    _ => const SizedBox.shrink(),
  };
  Widget _heading(
    bool mobile,
    String kicker,
    String title,
    String description, {
    Widget? action,
  }) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.only(bottom: 23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapText(
            '$kicker${mobile ? ' · SAMPLE DATA' : ''}',
            style: TextStyle(color: t.gd, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: mobile ? 24 : 33,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: t.tx,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 9),
          Text(
            description,
            style: TextStyle(
              color: t.tx2,
              fontSize: mobile ? 11 : 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Center(
      child: CapText(
        'AURORA CONSOLE · ADMIN PREVIEW',
        style: TextStyle(color: context.aurora.tx4, fontSize: 9),
      ),
    ),
  );
  Widget _two(
    Widget left,
    Widget right,
    bool mobile, {
    double leftFlex = 1,
    double rightFlex = 1,
  }) => mobile
      ? Column(children: [left, const SizedBox(height: 13), right])
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: (leftFlex * 10).round(), child: left),
            const SizedBox(width: 16),
            Expanded(flex: (rightFlex * 10).round(), child: right),
          ],
        );
  Widget _labelValue(
    String label,
    String value, {
    AdminTone tone = AdminTone.neutral,
  }) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          AdminLed(tone: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: t.tx2, fontSize: 11)),
          ),
          MonoText(
            value,
            style: TextStyle(
              color: t.tx,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(bool mobile) {
    final t = context.aurora;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'PLATFORM / OVERVIEW',
          'Admin dashboard',
          'A single view of integrity risk, usage and infrastructure health.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.field,
                border: Border.all(color: t.edge),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AdminLed(pulse: true),
                  const SizedBox(width: 8),
                  MonoText(
                    refreshed ? 'Updated just now' : 'Updated 18s ago',
                    style: TextStyle(color: t.tx2, fontSize: 10),
                  ),
                  const SizedBox(width: 5),
                  MonoText(
                    '/ 60s',
                    style: TextStyle(color: t.tx3, fontSize: 9),
                  ),
                ],
              ),
            ),
            AdminButton(
              'Refresh',
              icon: Icons.refresh,
              onPressed: () {
                setState(() => refreshed = true);
                AdminToast.show(context, 'Dashboard refreshed');
              },
            ),
          ],
        ),
        const SizedBox(height: 17),
        if (mobile) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: t.pr.withValues(alpha: .05),
              border: Border.all(color: t.pr.withValues(alpha: .5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: t.pr, size: 17),
                    const SizedBox(width: 7),
                    Expanded(
                      child: CapText(
                        'INTEGRITY FLAGS',
                        style: TextStyle(color: t.pr),
                      ),
                    ),
                    const AdminTag('REVIEW REQUIRED', tone: AdminTone.red),
                  ],
                ),
                const SizedBox(height: 14),
                MonoText(
                  '27',
                  style: TextStyle(
                    color: t.pr,
                    fontSize: 45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '9 high-severity cases awaiting human review',
                  style: TextStyle(color: t.tx2, fontSize: 11),
                ),
                AdminButton(
                  'Review incidents',
                  kind: AdminButtonKind.text,
                  onPressed: () => go('AD-05', tab: 'Incidents'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          CapText('PLATFORM SNAPSHOT'),
          const SizedBox(height: 9),
          _statGrid(mobile, true),
          const SizedBox(height: 20),
          CapText('SYSTEM HEALTH'),
          AdminPanel(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                _labelValue('API latency', '142 ms p95', tone: AdminTone.green),
                _labelValue('Celery queue', '38 tasks', tone: AdminTone.amber),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CapText('RECENT ALERTS'),
          const SizedBox(height: 8),
          ..._alertRows().take(4),
          AdminButton(
            'View audit records',
            kind: AdminButtonKind.text,
            onPressed: () => go('AD-04'),
          ),
          _footer(),
        ] else ...[
          _statGrid(mobile, false),
          _two(
            AdminPanel(
              title: 'Service health',
              hot: true,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _metricTile(
                          'API LATENCY',
                          '142',
                          'ms p95',
                          AdminTone.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricTile(
                          'CELERY QUEUE',
                          '38',
                          'tasks',
                          AdminTone.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _labelValue(
                    'Django REST API',
                    'Healthy',
                    tone: AdminTone.green,
                  ),
                  _labelValue(
                    'Celery analysis worker',
                    'Elevated',
                    tone: AdminTone.amber,
                  ),
                  _labelValue(
                    'PostgreSQL primary',
                    'Healthy',
                    tone: AdminTone.green,
                  ),
                ],
              ),
            ),
            AdminPanel(
              title: 'Recent alerts',
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              child: Column(children: _alertRows()),
            ),
            false,
            leftFlex: 1,
            rightFlex: 1.2,
          ),
          const SizedBox(height: 16),
          _two(
            AdminPanel(
              title: 'Integrity review queue',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AdminTag('HIGH SEVERITY', tone: AdminTone.red),
                      const Spacer(),
                      MonoText(
                        '9 / 27',
                        style: TextStyle(
                          color: t.pr,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: 9 / 27,
                    color: t.pr,
                    backgroundColor: t.trk,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Detection signals require human review; they are not proof of misconduct.',
                    style: TextStyle(color: t.tx3, fontSize: 10),
                  ),
                  AdminButton(
                    'View incidents',
                    kind: AdminButtonKind.text,
                    onPressed: () => go('AD-05', tab: 'Incidents'),
                  ),
                ],
              ),
            ),
            AdminPanel(
              title: 'Processing volume',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MonoText(
                    '1,284',
                    style: TextStyle(
                      color: t.tx,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const AdminTag('AI PIPELINE', tone: AdminTone.blue),
                  const SizedBox(height: 12),
                  Text(
                    'Gemini 2.5 Flash-Lite parsing · SBERT matching',
                    style: TextStyle(color: t.tx3, fontSize: 10),
                  ),
                ],
              ),
            ),
            false,
          ),
        ],
      ],
    );
  }

  Widget _metricTile(
    String label,
    String value,
    String suffix,
    AdminTone tone,
  ) {
    final t = context.aurora;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.edge2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapText(label),
          const SizedBox(height: 8),
          Row(
            children: [
              MonoText(
                value,
                style: TextStyle(
                  color: toneColor(t, tone),
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              Text(suffix, style: TextStyle(color: t.tx3, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 7),
          AdminTag(
            tone == AdminTone.green ? 'HEALTHY' : 'ELEVATED',
            tone: tone,
          ),
        ],
      ),
    );
  }

  Widget _statGrid(bool mobile, bool withoutIntegrity, {bool zero = false}) {
    final t = context.aurora;
    final items = <Widget>[
      AdminStat(
        label: 'Total users',
        value: zero ? '0' : '12,846',
        footer: Text(
          zero ? 'No accounts created yet' : '↗ 8.4% this month',
          style: TextStyle(color: t.hi, fontSize: 10),
        ),
      ),
      AdminStat(
        label: 'Active jobs',
        value: zero ? '0' : '384',
        footer: Text(
          zero ? 'No jobs published yet' : '+21 this week',
          style: TextStyle(color: t.gd, fontSize: 10),
        ),
      ),
      AdminStat(
        label: 'Interviews completed',
        value: zero ? '0' : '3,219',
        footer: Text(
          zero ? 'No interviews completed yet' : '↗ 12.6% this month',
          style: TextStyle(color: t.hi, fontSize: 10),
        ),
      ),
    ];
    if (!withoutIntegrity) {
      items.add(
        AdminStat(
          label: 'Integrity flags',
          value: zero ? '0' : '27',
          danger: !zero,
          neutral: zero,
          footer: AdminTag(
            zero ? 'NO ACTIVITY' : 'ACTION NEEDED',
            tone: zero ? AdminTone.neutral : AdminTone.red,
          ),
        ),
      );
    }
    if (mobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: .78,
        children: items,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: items
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                flex: e.key == 3 ? 14 : 10,
                child: Padding(
                  padding: const EdgeInsets.only(right: 13),
                  child: e.value,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<Widget> _alertRows() {
    final t = context.aurora;
    const data = [
      [
        'red',
        'High-risk interview integrity event',
        'INT-4821 · multiple voices detected · review required',
        '14:32:08',
        'CRITICAL',
      ],
      [
        'amber',
        'Celery queue threshold exceeded',
        'Worker analysis-02 · 38 tasks queued (limit 25)',
        '14:28:41',
        'WARNING',
      ],
      [
        'red',
        'Suspicious session behavior',
        'INT-4816 · frequent focus loss · verify with transcript',
        '14:21:17',
        'HIGH',
      ],
      [
        'blue',
        'Resume matching batch finished',
        'JOB-2048 · 164 SBERT comparisons completed',
        '14:15:03',
        'INFO',
      ],
      [
        'amber',
        'Interview webhook retry recovered',
        'Retell AI · callback accepted on attempt 2',
        '13:57:22',
        'WARNING',
      ],
      [
        'blue',
        'Daily database backup verified',
        'PostgreSQL snapshot · integrity check passed',
        '13:42:09',
        'INFO',
      ],
    ];
    return data.map((a) {
      final tone = switch (a[0]) {
        'red' => AdminTone.red,
        'amber' => AdminTone.amber,
        _ => AdminTone.blue,
      };
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.edge2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AdminLed(tone: tone),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a[1],
                    style: TextStyle(
                      color: t.tx,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(a[2], style: TextStyle(color: t.tx3, fontSize: 10)),
                  const SizedBox(height: 5),
                  MonoText(a[3], style: TextStyle(color: t.tx4, fontSize: 9)),
                ],
              ),
            ),
            AdminTag(a[4], tone: tone),
          ],
        ),
      );
    }).toList();
  }

  Widget _firstLaunch(bool mobile) {
    final t = context.aurora;
    final steps = mobile
        ? const [
            ['01', 'Set up recruiter accounts', 'Manage access from Users'],
            ['02', 'Publish a job opening', 'A recruiter can create a role'],
            [
              '03',
              'Complete an interview',
              'Unlock reports and integrity insights',
            ],
          ]
        : const [
            [
              '01',
              'Invite your team',
              'Set up recruiter access under User management',
            ],
            [
              '02',
              'Publish your first job',
              'Recruiters publish roles and accept applications',
            ],
            [
              '03',
              'Complete an interview',
              'Interview activity unlocks health insights',
            ],
          ];
    Widget stepList() => Column(
      children: steps
          .map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  MonoText(s[0], style: TextStyle(color: t.gd, fontSize: 13)),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s[1],
                          style: TextStyle(
                            color: t.tx,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          s[2],
                          style: TextStyle(color: t.tx3, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (!mobile)
                    const AdminTag('NOT STARTED')
                  else
                    Icon(Icons.radio_button_unchecked, color: t.tx3, size: 17),
                ],
              ),
            ),
          )
          .toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'PLATFORM / FIRST LAUNCH',
          'First-launch dashboard',
          'A clean starting point before your first recruiter, job, or interview.',
        ),
        if (mobile) ...[
          AdminPanel(
            hot: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✦', style: TextStyle(color: t.gd, fontSize: 30)),
                const SizedBox(height: 8),
                const AdminTag(
                  'WELCOME TO SKILLSENSE AI',
                  tone: AdminTone.blue,
                ),
                const SizedBox(height: 14),
                Text(
                  'Get your platform ready',
                  style: TextStyle(
                    color: t.tx,
                    fontSize: 19,
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Invite your first recruiter, publish a role, then start receiving applications. Your dashboard will populate automatically as activity begins.',
                  style: TextStyle(color: t.tx2, fontSize: 11, height: 1.5),
                ),
                const SizedBox(height: 15),
                AdminButton(
                  'Open user management',
                  kind: AdminButtonKind.primary,
                  fullWidth: true,
                  onPressed: () => go('AD-02'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _statGrid(true, false, zero: true),
          const SizedBox(height: 16),
          AdminPanel(title: 'Getting started', child: stepList()),
          const SizedBox(height: 13),
          AdminPanel(
            child: _emptyBlock(
              'Telemetry not connected',
              'Service metrics will appear when activity begins.',
              Icons.sensors_off_outlined,
            ),
          ),
          const SizedBox(height: 13),
          AdminPanel(
            child: _emptyBlock(
              'No activity to report',
              'Alerts will appear here when events occur.',
              Icons.notifications_none,
            ),
          ),
          _footer(),
        ] else ...[
          _statGrid(false, false, zero: true),
          _two(
            AdminPanel(
              title: 'Build your first workspace',
              hot: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✦', style: TextStyle(color: t.gd, fontSize: 31)),
                  const SizedBox(height: 9),
                  Text(
                    'The admin control plane is ready. Start by setting up your team; platform metrics and alerts will appear when real activity begins.',
                    style: TextStyle(color: t.tx2, fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 15),
                  stepList(),
                  const SizedBox(height: 15),
                  AdminButton(
                    'Open user management',
                    kind: AdminButtonKind.primary,
                    onPressed: () => go('AD-02'),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                AdminPanel(
                  title: 'Service telemetry',
                  trailing: const AdminTag('AWAITING TELEMETRY'),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metricTile(
                              'API LATENCY',
                              '—',
                              'Not connected',
                              AdminTone.neutral,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metricTile(
                              'CELERY QUEUE',
                              '—',
                              'Not connected',
                              AdminTone.neutral,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Telemetry will appear when services are connected.',
                        style: TextStyle(color: t.tx3, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                AdminPanel(
                  title: 'Recent alerts',
                  trailing: const AdminTag('0 EVENTS'),
                  child: _emptyBlock(
                    'Nothing to review yet',
                    'No activity to report.',
                    Icons.notifications_none,
                  ),
                ),
              ],
            ),
            false,
          ),
        ],
      ],
    );
  }

  Widget _emptyBlock(String title, String copy, IconData icon) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: t.tx3, size: 24),
            const SizedBox(height: 9),
            Text(
              title,
              style: TextStyle(
                color: t.tx,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(copy, style: TextStyle(color: t.tx3, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String userSearch = '';
  String userRole = 'All roles';
  String userStatus = 'Any status';
  final selectedUsers = <String>{};
  List<AdminUser> get visibleUsers => store.users.where((u) {
    final q = userSearch.toLowerCase();
    return (q.isEmpty ||
            '${u.name} ${u.email} ${u.id}'.toLowerCase().contains(q)) &&
        (userRole == 'All roles' || u.role == userRole) &&
        (userStatus == 'Any status' ||
            (u.active ? 'Active' : 'Suspended') == userStatus);
  }).toList();
  Future<void> _setUsers(List<AdminUser> users, bool active) async {
    final ok = await AdminModal.confirm(
      context,
      title:
          '${active ? 'Activate' : 'Suspend'} ${users.length} ${users.length == 1 ? 'account' : 'accounts'}?',
      message: 'This access change will be recorded in the audit log.',
      confirmLabel: active ? 'Activate' : 'Suspend',
      destructive: !active,
    );
    if (!ok || !mounted) return;
    setState(() {
      for (final u in users) {
        u.active = active;
        store.addAudit(
          'ACCOUNT_CHANGED',
          '${u.id} · account ${active ? 'activated' : 'suspended'}',
          'Accounts',
        );
      }
      selectedUsers.clear();
    });
    AdminToast.show(
      context,
      '${users.length} ${users.length == 1 ? 'account' : 'accounts'} ${active ? 'activated' : 'suspended'}',
    );
  }

  void _userDetail(AdminUser u) {
    final t = context.aurora;
    AdminModal.drawer(
      context,
      Builder(
        builder: (c) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Account details',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: t.tx,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(c),
                    icon: Icon(Icons.close, color: t.tx2),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _avatar(u.initials),
              const SizedBox(height: 12),
              Text(
                u.name,
                style: TextStyle(
                  color: t.tx,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 19),
              ...<String, String>{
                'User ID': u.id,
                'Email': u.email,
                'Role': u.role,
                'Organization': u.org,
                'Created': u.created,
                'Account status': u.active ? 'Active' : 'Suspended',
              }.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(color: t.tx3, fontSize: 11),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          e.value,
                          textAlign: TextAlign.right,
                          style: TextStyle(color: t.tx, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              AdminCallout(
                title: 'Confirmation required',
                description:
                    'Changes to account access are recorded in the audit log.',
                tone: u.active ? AdminTone.red : AdminTone.blue,
              ),
              const Spacer(),
              AdminButton(
                u.active ? 'Suspend account' : 'Activate account',
                kind: u.active
                    ? AdminButtonKind.destructive
                    : AdminButtonKind.primary,
                fullWidth: true,
                onPressed: () async {
                  Navigator.pop(c);
                  await _setUsers([u], !u.active);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _invite() {
    final t = context.aurora;
    final email = TextEditingController();
    String role = 'Recruiter';
    showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          backgroundColor: t.knob,
          title: Text(
            'Invite a platform user',
            style: TextStyle(color: t.tx, fontFamily: 'Space Grotesk'),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a sample invitation. Authentication provider and email delivery are not connected.',
                  style: TextStyle(color: t.tx2, fontSize: 11),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'name@company.com',
                  ),
                  onChanged: (_) => update(() {}),
                ),
                const SizedBox(height: 11),
                _dropdown(role, [
                  'Recruiter',
                  'Candidate',
                  'Admin',
                ], (v) => update(() => role = v)),
              ],
            ),
          ),
          actions: [
            AdminButton('Cancel', onPressed: () => Navigator.pop(c)),
            AdminButton(
              'Create demo invitation',
              kind: AdminButtonKind.primary,
              onPressed: email.text.contains('@')
                  ? () {
                      store.addAudit(
                        'ACCOUNT_CHANGED',
                        'Demo invite prepared: ${email.text.trim()} · $role',
                        'Accounts',
                      );
                      Navigator.pop(c);
                      AdminToast.show(
                        context,
                        'Demo invitation prepared · no email sent',
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    ).then((_) => email.dispose());
  }

  Widget _userFilters(bool mobile) {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => userSearch = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Search name, email or user ID',
          ),
        ),
        const SizedBox(height: 9),
        mobile
            ? Column(
                children: [
                  _dropdown(userRole, [
                    'All roles',
                    'Admin',
                    'Recruiter',
                    'Candidate',
                  ], (v) => setState(() => userRole = v)),
                  const SizedBox(height: 9),
                  _dropdown(userStatus, [
                    'Any status',
                    'Active',
                    'Suspended',
                  ], (v) => setState(() => userStatus = v)),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _dropdown(userRole, [
                      'All roles',
                      'Admin',
                      'Recruiter',
                      'Candidate',
                    ], (v) => setState(() => userRole = v)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _dropdown(userStatus, [
                      'Any status',
                      'Active',
                      'Suspended',
                    ], (v) => setState(() => userStatus = v)),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _dropdown(
    String value,
    List<String> options,
    ValueChanged<String> onChange,
  ) {
    final t = context.aurora;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: t.knob,
      style: TextStyle(color: t.tx, fontSize: 11),
      decoration: const InputDecoration(),
      items: options
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChange(v);
      },
    );
  }

  Widget _bulk(bool mobile) {
    final t = context.aurora;
    if (selectedUsers.isEmpty) return const SizedBox.shrink();
    final picked = store.users
        .where((u) => selectedUsers.contains(u.id))
        .toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.gd.withValues(alpha: .08),
        border: Border.all(color: t.gd.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 7,
        children: [
          MonoText(
            '${picked.length} users selected',
            style: TextStyle(color: t.gd, fontSize: 10),
          ),
          AdminButton(
            mobile ? 'Suspend' : 'Suspend selected',
            kind: AdminButtonKind.destructive,
            onPressed: () => _setUsers(picked, false),
          ),
          AdminButton(
            mobile ? 'Activate' : 'Activate selected',
            onPressed: () => _setUsers(picked, true),
          ),
          AdminButton(
            'Clear',
            kind: AdminButtonKind.text,
            onPressed: () => setState(selectedUsers.clear),
          ),
        ],
      ),
    );
  }

  Widget _users(bool mobile) {
    final t = context.aurora;
    final users = visibleUsers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'ACCESS CONTROL / ACCOUNTS',
          'User management',
          'Search, review and manage platform accounts with confirmation safeguards.',
          action: mobile
              ? IconButton(
                  onPressed: _invite,
                  icon: Icon(Icons.add, color: t.gd),
                )
              : AdminButton(
                  'Invite user',
                  kind: AdminButtonKind.primary,
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: _invite,
                ),
        ),
        if (mobile)
          Row(
            children: [
              const AdminTag('8 SAMPLE ACCOUNTS', tone: AdminTone.blue),
              const Spacer(),
              AdminButton(
                'Invite',
                kind: AdminButtonKind.text,
                onPressed: _invite,
              ),
            ],
          ),
        if (mobile) const SizedBox(height: 11),
        AdminPanel(
          title: mobile ? null : 'Platform accounts',
          hot: true,
          trailing: mobile
              ? null
              : const AdminTag('8 SAMPLE ACCOUNTS', tone: AdminTone.blue),
          padding: EdgeInsets.all(mobile ? 13 : 20),
          child: Column(
            children: [
              _userFilters(mobile),
              _bulk(mobile),
              if (users.isEmpty)
                _emptyBlock(
                  'No users match these filters.',
                  'Try another search or filter.',
                  Icons.search_off_outlined,
                )
              else if (mobile)
                ...users.map(_userCard)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    headingTextStyle: TextStyle(
                      color: t.tx3,
                      fontFamily: 'Space Grotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    dataTextStyle: TextStyle(color: t.tx2, fontSize: 11),
                    columns: [
                      DataColumn(
                        label: Checkbox(
                          value: users.every(
                            (u) => selectedUsers.contains(u.id),
                          ),
                          onChanged: (v) => setState(() {
                            for (final u in users) {
                              v == true
                                  ? selectedUsers.add(u.id)
                                  : selectedUsers.remove(u.id);
                            }
                          }),
                        ),
                      ),
                      const DataColumn(label: Text('USER / EMAIL')),
                      const DataColumn(label: Text('ROLE')),
                      const DataColumn(label: Text('CREATED')),
                      const DataColumn(label: Text('STATUS')),
                      const DataColumn(label: Text('USER ID')),
                      const DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: users
                        .map(
                          (u) => DataRow(
                            onSelectChanged: (_) => _userDetail(u),
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: selectedUsers.contains(u.id),
                                  onChanged: (v) => setState(() {
                                    v == true
                                        ? selectedUsers.add(u.id)
                                        : selectedUsers.remove(u.id);
                                  }),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    _avatar(u.initials),
                                    const SizedBox(width: 9),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.name,
                                          style: TextStyle(
                                            color: t.tx,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          u.email,
                                          style: TextStyle(
                                            color: t.tx3,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _userDetail(u),
                              ),
                              DataCell(Text(u.role)),
                              DataCell(
                                MonoText(
                                  u.created,
                                  style: TextStyle(color: t.tx2, fontSize: 10),
                                ),
                              ),
                              DataCell(
                                AdminTag(
                                  u.active ? 'ACTIVE' : 'SUSPENDED',
                                  tone: u.active
                                      ? AdminTone.green
                                      : AdminTone.red,
                                ),
                              ),
                              DataCell(
                                MonoText(
                                  u.id,
                                  style: TextStyle(color: t.tx3, fontSize: 10),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Switch(
                                      value: u.active,
                                      activeThumbColor: t.hi,
                                      onChanged: (v) => _setUsers([u], v),
                                    ),
                                    IconButton(
                                      onPressed: () => _userDetail(u),
                                      icon: Icon(
                                        Icons.chevron_right,
                                        color: t.tx3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Showing ${users.length} users',
                    style: TextStyle(color: t.tx3, fontSize: 10),
                  ),
                  if (!mobile) ...[
                    const Spacer(),
                    Text(
                      'Click any account for details · Changes require confirmation',
                      style: TextStyle(color: t.tx3, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (mobile) _footer(),
      ],
    );
  }

  Widget _userCard(AdminUser u) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: t.glass,
          border: Border.all(color: t.edge),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: selectedUsers.contains(u.id),
                  onChanged: (v) => setState(() {
                    v == true
                        ? selectedUsers.add(u.id)
                        : selectedUsers.remove(u.id);
                  }),
                ),
                _avatar(u.initials),
                const SizedBox(width: 8),
                Expanded(
                  child: MonoText(
                    u.id,
                    style: TextStyle(color: t.tx3, fontSize: 9),
                  ),
                ),
                AdminTag(
                  u.active ? 'ACTIVE' : 'SUSPENDED',
                  tone: u.active ? AdminTone.green : AdminTone.red,
                ),
              ],
            ),
            InkWell(
              onTap: () => _userDetail(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name,
                            style: TextStyle(
                              color: t.tx,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            u.email,
                            style: TextStyle(color: t.tx3, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.tx3),
                  ],
                ),
              ),
            ),
            Divider(color: t.edge2),
            Row(
              children: [
                Text(
                  '${u.role} · ${u.created}',
                  style: TextStyle(color: t.tx3, fontSize: 9),
                ),
                const Spacer(),
                Switch(
                  value: u.active,
                  activeThumbColor: t.hi,
                  onChanged: (v) => _setUsers([u], v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static final weights = <String, int>{
    'Resume Match': 30,
    'Technical': 35,
    'Behavioral': 20,
    'Communication': 15,
  };
  static final scoringThresholds = <String, double>{
    'Phone-detection threshold': 70,
    'Multi-person threshold': 65,
  };
  static final penalties = <String, int>{'LOW': 2, 'MED': 7, 'HIGH': 15};
  Widget _weightRow(String name, String subtitle) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: t.tx,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: t.tx3, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: TextFormField(
              key: ValueKey('weight-$name'),
              initialValue: '${weights[name]}',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                color: t.tx,
                fontSize: 12,
              ),
              onChanged: (v) =>
                  setState(() => weights[name] = int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 6),
          MonoText('%', style: TextStyle(color: t.tx2, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _rangeRow(
    String label,
    String description,
    double value,
    ValueChanged<double> onChange,
  ) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: t.tx,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              MonoText(
                '${value.round()}%',
                style: TextStyle(
                  color: t.gd,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: t.tx3, fontSize: 10)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: t.gd,
              inactiveTrackColor: t.trk,
              thumbColor: t.gd,
              overlayColor: t.gd.withValues(alpha: .15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(0, 100).toDouble(),
              max: 100,
              onChanged: onChange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoring(bool mobile) {
    final t = context.aurora;
    final total = weights.values.fold(0, (a, b) => a + b);
    Widget weightPanel = AdminPanel(
      title: 'Default scoring weights',
      hot: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile)
            Text(
              'Every newly created job inherits these rubric defaults until a recruiter customizes them.',
              style: TextStyle(color: t.tx3, fontSize: 10),
            ),
          _weightRow('Resume Match', 'Profile-to-role semantic fit'),
          _weightRow('Technical', 'Job-specific interview responses'),
          _weightRow('Behavioral', 'Observed interview conduct'),
          _weightRow('Communication', 'Clarity and coherence of answers'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: total == 100
                  ? t.hi.withValues(alpha: .05)
                  : t.pr.withValues(alpha: .07),
              border: Border.all(
                color: total == 100
                    ? t.hi.withValues(alpha: .3)
                    : t.pr.withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CapText(
                      'TOTAL WEIGHT',
                      style: TextStyle(color: total == 100 ? t.hi : t.pr),
                    ),
                    const Spacer(),
                    MonoText(
                      '$total%',
                      style: TextStyle(
                        color: total == 100 ? t.hi : t.pr,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                LinearProgressIndicator(
                  value: (total / 100).clamp(0, 1),
                  color: total == 100 ? t.hi : t.pr,
                  backgroundColor: t.trk,
                  minHeight: 5,
                ),
                const SizedBox(height: 7),
                Text(
                  total == 100
                      ? 'Ready to save · 100% required'
                      : 'Weights must total 100% before saving.',
                  style: TextStyle(
                    color: total == 100 ? t.hi : t.pr,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    Widget thresholdPanel = AdminPanel(
      title: mobile ? 'Cheating detection thresholds' : 'Integrity thresholds',
      child: Column(
        children: [
          if (!mobile)
            Text(
              'Risk signals are evidence for manual review, not automatic proof of cheating.',
              style: TextStyle(color: t.tx3, fontSize: 10),
            ),
          _rangeRow(
            'Phone-detection threshold',
            'YOLOv8-nano frame event sensitivity',
            scoringThresholds['Phone-detection threshold']!,
            (v) => setState(
              () => scoringThresholds['Phone-detection threshold'] = v,
            ),
          ),
          _rangeRow(
            'Multi-person threshold',
            'YOLOv8-nano presence signal',
            scoringThresholds['Multi-person threshold']!,
            (v) =>
                setState(() => scoringThresholds['Multi-person threshold'] = v),
          ),
        ],
      ),
    );
    Widget penaltyPanel = AdminPanel(
      title: mobile ? 'Risk penalties' : 'Penalty points by risk',
      child: Column(
        children: [
          for (final e in const [
            ['LOW', 'Minor, reviewable incident'],
            ['MED', 'Repeated questionable activity'],
            ['HIGH', 'Severe integrity concern'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  AdminTag(
                    e[0],
                    tone: e[0] == 'HIGH'
                        ? AdminTone.red
                        : e[0] == 'MED'
                        ? AdminTone.amber
                        : AdminTone.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e[1],
                      style: TextStyle(color: t.tx2, fontSize: 10),
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: TextFormField(
                      key: ValueKey('penalty-${e[0]}'),
                      initialValue: '${penalties[e[0]]}',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(
                        color: t.tx,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                      ),
                      onChanged: (v) => penalties[e[0]] = int.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('pts', style: TextStyle(color: t.tx3, fontSize: 9)),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'POLICY / SCORING',
          'Global scoring config',
          'Platform-wide scoring weights and integrity detection thresholds.',
        ),
        const AdminCallout(
          title: 'Changes apply to NEW jobs only.',
          description: 'Existing job scoring settings remain as configured.',
          tone: AdminTone.amber,
        ),
        const SizedBox(height: 16),
        mobile
            ? Column(
                children: [
                  weightPanel,
                  const SizedBox(height: 13),
                  thresholdPanel,
                  const SizedBox(height: 13),
                  penaltyPanel,
                ],
              )
            : _two(
                weightPanel,
                Column(
                  children: [
                    thresholdPanel,
                    const SizedBox(height: 13),
                    penaltyPanel,
                  ],
                ),
                false,
              ),
        const SizedBox(height: 15),
        if (!mobile)
          Text(
            '🔒 Saving writes a configuration event to Audit log.',
            style: TextStyle(color: t.tx3, fontSize: 10),
          ),
        AdminButton(
          'Save scoring defaults',
          kind: AdminButtonKind.primary,
          fullWidth: mobile,
          onPressed: total == 100
              ? () async {
                  final ok = await AdminModal.confirm(
                    context,
                    title: 'Save scoring defaults?',
                    message:
                        'New jobs will inherit the updated scoring weights, thresholds and penalties. This change will be logged.',
                    confirmLabel: 'Save defaults',
                  );
                  if (ok && mounted) {
                    store.addAudit(
                      'SCORING_CONFIG_CHANGED',
                      'Default scoring weights and integrity thresholds updated',
                      'Policy',
                    );
                    AdminToast.show(context, 'Scoring defaults saved');
                  }
                }
              : null,
        ),
        if (mobile) ...[
          const SizedBox(height: 7),
          Text(
            'An audit record is created when defaults are saved.',
            style: TextStyle(color: t.tx3, fontSize: 10),
          ),
          _footer(),
        ],
      ],
    );
  }

  final auditSearchController = TextEditingController();
  String auditSearch = '';
  String auditEvent = 'All events';
  String from = '2026-10-01', to = '2026-10-15';
  static const eventLabels = <String, String>{
    'All events': 'all',
    'Login': 'LOGIN',
    'Job status change': 'JOB_STATUS_CHANGED',
    'Interview created': 'INTERVIEW_CREATED',
    'Score generated': 'SCORE_GENERATED',
    'Account change': 'ACCOUNT_CHANGED',
    'Scoring config': 'SCORING_CONFIG_CHANGED',
    'Model config': 'MODEL_CONFIG_CHANGED',
    'Retention change': 'RETENTION_CHANGED',
    'Data erasure': 'DATA_ERASURE_REQUESTED',
  };
  List<AuditEntry> get filteredAudit => store.audit.where((a) {
    final q = auditSearch.toLowerCase();
    return (auditEvent == 'All events' || a.event == eventLabels[auditEvent]) &&
        (q.isEmpty ||
            '${a.actor} ${a.id} ${a.details} ${a.event}'.toLowerCase().contains(
              q,
            )) &&
        (from.isEmpty || a.date.substring(0, 10).compareTo(from) >= 0) &&
        (to.isEmpty || a.date.substring(0, 10).compareTo(to) <= 0);
  }).toList();
  Future<void> _exportAudit() async {
    final rows = filteredAudit;
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final data = [
      [
        'EVENT ID',
        'EVENT TYPE',
        'ACTOR',
        'TIMESTAMP (PKT)',
        'DETAILS',
        'CATEGORY',
      ],
      ...rows.map(
        (a) => [a.id, a.event, a.actor, a.date, a.details, a.category],
      ),
    ].map((r) => r.map(esc).join(',')).join('\r\n');
    try {
      final saved = await csv.downloadCsv('aurora-audit-log.csv', data);
      if (saved && mounted) {
        AdminToast.show(context, 'Exported ${rows.length} audit records');
      }
    } catch (_) {
      if (mounted) AdminToast.show(context, 'CSV export could not be saved');
    }
  }

  Widget _audit(bool mobile) {
    final t = context.aurora;
    final rows = filteredAudit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'GOVERNANCE / EVENT HISTORY',
          'Audit log',
          'An append-only view of important platform and administration events.',
          action: mobile
              ? null
              : AdminButton(
                  'Export CSV',
                  icon: Icons.download_outlined,
                  onPressed: _exportAudit,
                ),
        ),
        if (mobile)
          Row(
            children: [
              const AdminTag('IMMUTABLE RECORD', tone: AdminTone.blue),
              const Spacer(),
              AdminButton(
                'CSV',
                kind: AdminButtonKind.text,
                onPressed: _exportAudit,
              ),
            ],
          )
        else
          const AdminCallout(
            title: 'Immutable activity history.',
            description:
                'Events are append-only and cannot be edited or deleted.',
            tone: AdminTone.blue,
          ),
        const SizedBox(height: 15),
        AdminPanel(
          title: mobile ? null : 'Event history',
          hot: true,
          trailing: mobile
              ? null
              : AdminButton('Export CSV', onPressed: _exportAudit),
          child: Column(
            children: [
              TextField(
                controller: auditSearchController,
                onChanged: (v) => setState(() => auditSearch = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search actor, ID or details',
                ),
              ),
              const SizedBox(height: 9),
              _dropdown(
                auditEvent,
                eventLabels.keys.toList(),
                (v) => setState(() => auditEvent = v),
              ),
              const SizedBox(height: 9),
              mobile
                  ? Column(
                      children: [
                        _dateField(
                          'From',
                          from,
                          (v) => setState(() => from = v),
                        ),
                        const SizedBox(height: 8),
                        _dateField('To', to, (v) => setState(() => to = v)),
                        const SizedBox(height: 8),
                        AdminButton(
                          'Clear filters',
                          fullWidth: true,
                          onPressed: _clearAudit,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            'From',
                            from,
                            (v) => setState(() => from = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dateField(
                            'To',
                            to,
                            (v) => setState(() => to = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AdminButton('Clear filters', onPressed: _clearAudit),
                      ],
                    ),
              const SizedBox(height: 17),
              if (mobile)
                ...rows.map(_auditCard)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('EVENT ID')),
                      DataColumn(label: Text('EVENT TYPE')),
                      DataColumn(label: Text('ACTOR')),
                      DataColumn(label: Text('TIMESTAMP (PKT)')),
                      DataColumn(label: Text('DETAILS')),
                      DataColumn(label: Text('CATEGORY')),
                    ],
                    rows: rows
                        .map(
                          (a) => DataRow(
                            cells: [
                              DataCell(
                                MonoText(
                                  a.id,
                                  style: TextStyle(color: t.tx3, fontSize: 10),
                                ),
                              ),
                              DataCell(
                                Text(
                                  a.event.replaceAll('_', ' '),
                                  style: TextStyle(
                                    color: t.tx,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  a.actor,
                                  style: TextStyle(color: t.tx2, fontSize: 10),
                                ),
                              ),
                              DataCell(
                                MonoText(
                                  a.date,
                                  style: TextStyle(color: t.tx3, fontSize: 10),
                                ),
                              ),
                              DataCell(
                                Text(
                                  a.details,
                                  style: TextStyle(color: t.tx2, fontSize: 10),
                                ),
                              ),
                              DataCell(AdminTag(a.category.toUpperCase())),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (rows.isEmpty)
                _emptyBlock(
                  'No events match the selected filters.',
                  'Clear filters to see the full history.',
                  Icons.search_off_outlined,
                ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Text(
                    '${rows.length} records',
                    style: TextStyle(color: t.tx3, fontSize: 10),
                  ),
                  if (!mobile) ...[
                    const Spacer(),
                    Text(
                      'Audit entries are append-only in the intended backend implementation.',
                      style: TextStyle(color: t.tx3, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (mobile) _footer(),
      ],
    );
  }

  void _clearAudit() => setState(() {
    auditSearchController.clear();
    auditSearch = '';
    auditEvent = 'All events';
    from = '';
    to = '';
  });
  Widget _dateField(String label, String value, ValueChanged<String> changed) {
    final t = context.aurora;
    return Row(
      children: [
        Text('$label  ', style: TextStyle(color: t.tx3, fontSize: 10)),
        Expanded(
          child: TextFormField(
            key: ValueKey('audit-$label-$value'),
            initialValue: value,
            style: TextStyle(
              color: t.tx,
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
            ),
            onChanged: changed,
            decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
          ),
        ),
      ],
    );
  }

  Widget _auditCard(AuditEntry a) {
    final t = context.aurora;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.edge),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoText(a.date, style: TextStyle(color: t.tx3, fontSize: 9)),
          const SizedBox(height: 7),
          Text(
            a.event.replaceAll('_', ' '),
            style: TextStyle(
              color: t.tx,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(a.details, style: TextStyle(color: t.tx2, fontSize: 10)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(a.actor, style: TextStyle(color: t.tx3, fontSize: 9)),
              const Spacer(),
              MonoText(a.id, style: TextStyle(color: t.tx3, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _analytics(bool mobile) {
    final t = context.aurora;
    final tabs = ['Usage', 'Performance', 'Incidents'];
    Widget tabBar = Container(
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.edge),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
        children: tabs
            .map(
              (name) => Flexible(
                fit: mobile ? FlexFit.tight : FlexFit.loose,
                child: InkWell(
                  onTap: () => setState(() => analyticsTab = name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: analyticsTab == name
                          ? t.gd.withValues(alpha: .14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: analyticsTab == name ? t.gd : t.tx3,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'OPERATIONS / INTELLIGENCE',
          'System analytics',
          'Technical throughput, model latency and integrity trends.',
          action: mobile
              ? null
              : const AdminTag('MODEL TELEMETRY', tone: AdminTone.blue),
        ),
        if (!mobile)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.field,
              border: Border.all(color: t.edge),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Technical & model performance',
                      style: TextStyle(
                        color: t.tx,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Separate from recruiter hiring-funnel analytics',
                      style: TextStyle(color: t.tx3, fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                const AdminTag('LAST 7 DAYS · DEMO', tone: AdminTone.blue),
              ],
            ),
          ),
        tabBar,
        const SizedBox(height: 16),
        if (analyticsTab == 'Usage')
          _two(
            AdminPanel(
              title: 'Interview completion rate',
              hot: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '86.0%',
                          style: TextStyle(
                            color: t.tx,
                            fontFamily: 'JetBrains Mono',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: ' this week',
                          style: TextStyle(color: t.tx3, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _lineChart(
                    [.279, .396, .326, .534, .581, .697, .814],
                    t.gd,
                    mobile,
                  ),
                ],
              ),
            ),
            AdminPanel(
              title: 'Score distribution',
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: const AdminTag('MEDIAN 72', tone: AdminTone.blue),
                  ),
                  const SizedBox(height: 16),
                  _histogram(mobile),
                  const SizedBox(height: 10),
                  Text(
                    'Rubric score distribution · 2,842 scored interviews · score /100',
                    style: TextStyle(color: t.tx3, fontSize: 9),
                  ),
                ],
              ),
            ),
            mobile,
          )
        else if (analyticsTab == 'Performance')
          _two(
            AdminPanel(
              title: 'AI pipeline latency',
              hot: true,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: CapText('MODEL / OPERATION')),
                      Expanded(child: CapText('P50')),
                      if (!mobile) Expanded(child: CapText('P95')),
                      Expanded(child: CapText('SUCCESS')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...const [
                    [
                      'Gemini 2.5 Flash-Lite',
                      'Resume parsing',
                      '720 ms',
                      '1,340 ms',
                      '99.2%',
                    ],
                    [
                      'Gemini 2.5 Flash',
                      'Question generation',
                      '1,080 ms',
                      '2,180 ms',
                      '98.7%',
                    ],
                    [
                      'SBERT all-MiniLM-L6-v2',
                      'Resume matching',
                      '38 ms',
                      '91 ms',
                      '99.9%',
                    ],
                  ].map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r[0],
                                  style: TextStyle(
                                    color: t.tx,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  r[1],
                                  style: TextStyle(color: t.tx3, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: MonoText(
                              r[2],
                              style: TextStyle(color: t.tx2, fontSize: 10),
                            ),
                          ),
                          if (!mobile)
                            Expanded(
                              child: MonoText(
                                r[3],
                                style: TextStyle(color: t.tx2, fontSize: 10),
                              ),
                            ),
                          Expanded(
                            child: MonoText(
                              r[4],
                              style: TextStyle(color: t.hi, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AdminPanel(
              title: 'Pipeline services',
              child: Column(
                children: [
                  _labelValue(
                    'Django REST API',
                    'Healthy',
                    tone: AdminTone.green,
                  ),
                  _labelValue(
                    'Celery analysis worker',
                    '38 queued',
                    tone: AdminTone.amber,
                  ),
                  _labelValue(
                    'PostgreSQL primary',
                    'Healthy',
                    tone: AdminTone.green,
                  ),
                  _labelValue(
                    'Model inference success',
                    '99.4%',
                    tone: AdminTone.green,
                  ),
                ],
              ),
            ),
            mobile,
          )
        else
          _two(
            AdminPanel(
              title: 'Integrity incident rate',
              hot: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AdminTag('2.9% LATEST', tone: AdminTone.red),
                  const SizedBox(height: 21),
                  _lineChart(
                    [.162, .198, .181, .243, .28, .216, .261],
                    t.pr,
                    mobile,
                  ),
                ],
              ),
            ),
            AdminPanel(
              title: 'Incident triage',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _incidentTile('Open flags', '27', false)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _incidentTile('High severity', '9', true),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _incidentTile(
                          'Awaiting human review',
                          '14',
                          false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const AdminCallout(
                    title: 'Human review required',
                    description:
                        'Detection signals are review cues, not proof of misconduct.',
                    tone: AdminTone.amber,
                  ),
                ],
              ),
            ),
            mobile,
          ),
        if (mobile) _footer(),
      ],
    );
  }

  Widget _incidentTile(String label, String value, bool danger) {
    final t = context.aurora;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: danger ? t.pr.withValues(alpha: .4) : t.edge),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          MonoText(
            value,
            style: TextStyle(
              color: danger ? t.pr : t.tx,
              fontSize: 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.tx3, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _lineChart(List<double> points, Color color, bool mobile) {
    final t = context.aurora;
    return Column(
      children: [
        SizedBox(
          height: mobile ? 135 : 190,
          width: double.infinity,
          child: CustomPaint(
            painter: _AdminLinePainter(points, color, t.edge2),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: 'MTWTFSS'
              .split('')
              .map(
                (x) => CapText(x, style: TextStyle(color: t.tx3, fontSize: 9)),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _histogram(bool mobile) {
    final t = context.aurora;
    const heights = [.08, .13, .27, .44, .63, .82, .65, .51, .29, .15];
    return SizedBox(
      height: mobile ? 150 : 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          10,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: heights[i],
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == 7 ? t.gd : t.gd.withValues(alpha: .4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${i * 10}–${i * 10 + 9}',
                    style: TextStyle(color: t.tx3, fontSize: mobile ? 6 : 8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final modelVersions = <String, String>{
    'Resume parsing': 'Gemini 2.5 Flash-Lite',
    'Question generation': 'Gemini 2.5 Flash',
    'Semantic matching': 'SBERT · all-MiniLM-L6-v2',
    'Behavioral observation': 'MediaPipe + YOLOv8-nano + FER',
  };
  static final modelCodes = <String, String>{
    'Resume parsing': 'gemini-2.5-flash-lite',
    'Question generation': 'gemini-2.5-flash',
    'Semantic matching': 'all-MiniLM-L6-v2',
    'Behavioral observation': 'mp-yolo-fer-v1',
  };
  static final modelThresholds = <String, double>{
    'Phone detection': 70,
    'Multiple people': 65,
    'Gaze anomaly': 75,
  };
  final modelPreview = <String, double>{};
  static final flags = <String, bool>{
    'Integrity detection': true,
    'Rubric explanations': true,
    'Model health alerts': true,
  };
  Future<void> _changeVersion(String name) async {
    final t = context.aurora;
    final old = modelCodes[name]!;
    final alt = const {
      'Resume parsing': 'gemini-2.5-flash',
      'Question generation': 'gemini-2.5-pro',
      'Semantic matching': 'all-mpnet-base-v2',
      'Behavioral observation': 'mp-yolo-fer-v2',
    }[name]!;
    String selected = old;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
              backgroundColor: t.knob,
              title: Text(
                'Change $name model',
                style: TextStyle(color: t.tx, fontFamily: 'Space Grotesk'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A different model can change processing behavior. Confirm the new version before applying it.',
                    style: TextStyle(color: t.tx2, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(selected, [
                    old,
                    alt,
                  ], (v) => update(() => selected = v)),
                ],
              ),
              actions: [
                AdminButton('Cancel', onPressed: () => Navigator.pop(c, false)),
                AdminButton(
                  'Confirm model change',
                  kind: AdminButtonKind.primary,
                  onPressed: selected == old
                      ? null
                      : () => Navigator.pop(c, true),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (ok && mounted) {
      setState(() {
        modelCodes[name] = selected;
        modelVersions[name] = name == 'Semantic matching'
            ? 'SBERT · $selected'
            : name == 'Behavioral observation'
            ? 'Behavioral stack · $selected'
            : selected;
      });
      store.addAudit('MODEL_CONFIG_CHANGED', '$name → $selected', 'AI Models');
      AdminToast.show(context, 'Model version updated · audit record created');
    }
  }

  Future<void> _changeThreshold(String name, double old, double next) async {
    if (old.round() == next.round()) return;
    final ok = await AdminModal.confirm(
      context,
      title: 'Change $name threshold?',
      message:
          '${old.round()}% → ${next.round()}%. This privileged change will be logged.',
      confirmLabel: 'Apply threshold',
    );
    if (ok && mounted) {
      setState(() => modelThresholds[name] = next);
      store.addAudit(
        'MODEL_CONFIG_CHANGED',
        '$name threshold changed ${old.round()}% → ${next.round()}%',
        'Models',
      );
      AdminToast.show(context, '$name threshold updated');
    }
  }

  Widget _modelRangeRow(String name, String description) {
    final t = context.aurora;
    final saved = modelThresholds[name]!;
    final shown = modelPreview[name] ?? saved;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: t.tx,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              MonoText(
                '${shown.round()}%',
                style: TextStyle(
                  color: t.gd,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: t.tx3, fontSize: 10)),
          Slider(
            value: shown,
            max: 100,
            activeColor: t.gd,
            inactiveColor: t.trk,
            onChanged: (v) => setState(() => modelPreview[name] = v),
            onChangeEnd: (v) async {
              await _changeThreshold(name, saved, v);
              if (mounted) setState(() => modelPreview.remove(name));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeFlag(String name, bool next) async {
    final ok = await AdminModal.confirm(
      context,
      title: 'Change $name?',
      message:
          'Turn ${next ? 'on' : 'off'} $name? This privileged change will be logged.',
      confirmLabel: 'Apply change',
    );
    if (ok && mounted) {
      setState(() => flags[name] = next);
      store.addAudit(
        'MODEL_CONFIG_CHANGED',
        '$name ${next ? 'enabled' : 'disabled'}',
        'Models',
      );
      AdminToast.show(context, '$name updated');
    }
  }

  Widget _modelCard(String name, String description, String meta) {
    final t = context.aurora;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.edge),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CapText(name.toUpperCase())),
              const AdminTag('ACTIVE', tone: AdminTone.green),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            modelVersions[name]!,
            style: TextStyle(
              color: t.tx,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 7),
          Text(description, style: TextStyle(color: t.tx3, fontSize: 10)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MonoText(
                modelCodes[name]!,
                style: TextStyle(color: t.gd, fontSize: 9),
              ),
              AdminButton(
                'Change version',
                kind: AdminButtonKind.text,
                onPressed: () => _changeVersion(name),
              ),
            ],
          ),
          Divider(color: t.edge2),
          MonoText(
            'Last changed $meta',
            style: TextStyle(color: t.tx3, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _models(bool mobile) {
    final t = context.aurora;
    final cards = [
      _modelCard(
        'Resume parsing',
        'Structured candidate resume JSON',
        '2026-10-02 · Natasha Fatima',
      ),
      _modelCard(
        'Question generation',
        'Interview questions from job & profile',
        '2026-10-04 · Bilal Hussain',
      ),
      _modelCard(
        'Semantic matching',
        'Cached embeddings + cosine similarity',
        '2026-09-29 · Natasha Fatima',
      ),
      _modelCard(
        'Behavioral observation',
        'Gaze, people/phone detection, emotion cues',
        '2026-10-06 · Bilal Hussain',
      ),
    ];
    Widget models = AdminPanel(
      title: 'Active model versions',
      trailing: const AdminTag('4 MODULES', tone: AdminTone.blue),
      hot: true,
      child: mobile
          ? Column(
              children: cards
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: c,
                    ),
                  )
                  .toList(),
            )
          : Column(
              children: [
                _two(cards[0], cards[1], false),
                const SizedBox(height: 10),
                _two(cards[2], cards[3], false),
              ],
            ),
    );
    Widget thresholds = AdminPanel(
      title: mobile
          ? 'Confidence thresholds'
          : 'Behavioral confidence thresholds',
      child: Column(
        children: [
          for (final e in const [
            ['Phone detection', 'Event-level model confidence'],
            ['Multiple people', 'Person-detection confidence'],
            ['Gaze anomaly', 'Temporal observation sensitivity'],
          ])
            _modelRangeRow(e[0], e[1]),
        ],
      ),
    );
    Widget flagPanel = AdminPanel(
      title: mobile ? 'Feature flags' : 'Platform feature flags',
      child: Column(
        children: [
          for (final e in const [
            [
              'Integrity detection',
              'Collect phone, person and gaze risk signals',
            ],
            [
              'Rubric explanations',
              'Generate transparent score breakdowns and reasons',
            ],
            ['Model health alerts', 'Flag model failures and latency spikes'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e[0],
                          style: TextStyle(
                            color: t.tx,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          e[1],
                          style: TextStyle(color: t.tx3, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: flags[e[0]]!,
                    activeThumbColor: t.tglOn,
                    onChanged: (v) => _changeFlag(e[0], v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'OPERATIONS / MODEL CONTROL',
          'AI model config',
          'Review model versions, detection confidence and feature flags.',
          action: mobile
              ? null
              : const AdminTag('RESTRICTED ACCESS', tone: AdminTone.red),
        ),
        if (mobile) const AdminTag('RESTRICTED ACCESS', tone: AdminTone.red),
        const SizedBox(height: 10),
        const AdminCallout(
          title: 'Privileged system configuration',
          description:
              'Model and feature changes affect platform behavior. Every change requires confirmation and is written to Audit log.',
          tone: AdminTone.red,
        ),
        const SizedBox(height: 16),
        models,
        const SizedBox(height: 15),
        _two(thresholds, flagPanel, mobile),
        if (mobile) ...[
          const SizedBox(height: 10),
          Text(
            'Controls require confirmation before updates are applied.',
            style: TextStyle(color: t.tx3, fontSize: 10),
          ),
          _footer(),
        ],
      ],
    );
  }

  static final retention = <String, int>{
    'Behavioral frame data': 30,
    'Interview recordings': 90,
    'Application resumes': 180,
  };
  final userIdController = TextEditingController();
  final jobIdController = TextEditingController();
  Future<void> _saveRetention() async {
    final ok = await AdminModal.confirm(
      context,
      title: 'Save retention policy?',
      message: 'The updated retention periods will be logged to Audit log.',
      confirmLabel: 'Save policy',
    );
    if (ok && mounted) {
      store.addAudit(
        'RETENTION_CHANGED',
        'Retention policy updated: frames ${retention['Behavioral frame data']}d, recordings ${retention['Interview recordings']}d, resumes ${retention['Application resumes']}d',
        'Privacy',
      );
      AdminToast.show(context, 'Retention policy saved');
    }
  }

  Future<void> _erase(String kind, String id) async {
    if (id.trim().isEmpty) {
      AdminToast.show(context, 'Enter the ${kind.toLowerCase()} ID first');
      return;
    }
    final t = context.aurora;
    String typed = '';
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
              backgroundColor: t.knob,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.pr.withValues(alpha: .4)),
              ),
              title: Text(
                'Request $kind erasure',
                style: TextStyle(color: t.pr, fontFamily: 'Space Grotesk'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type $id to confirm this destructive request. The action will be logged.',
                    style: TextStyle(color: t.tx2, fontSize: 11),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (v) => update(() => typed = v),
                    decoration: InputDecoration(hintText: id),
                  ),
                ],
              ),
              actions: [
                AdminButton('Cancel', onPressed: () => Navigator.pop(c, false)),
                AdminButton(
                  'Request erasure',
                  kind: AdminButtonKind.destructive,
                  onPressed: typed == id ? () => Navigator.pop(c, true) : null,
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (ok && mounted) {
      store.addAudit(
        'DATA_ERASURE_REQUESTED',
        '$kind $id · erasure requested',
        'Privacy',
      );
      AdminToast.show(context, 'Erasure request recorded');
    }
  }

  Widget _retentionRow(String label, String subtitle, List<int> options) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: t.tx,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: t.tx3, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
            width: 135,
            child: _dropdown(
              '${retention[label]} days',
              options.map((e) => '$e days').toList(),
              (v) => setState(
                () => retention[label] = int.parse(v.split(' ').first),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _erasureForm(String label, TextEditingController controller) {
    final t = context.aurora;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapText(label.toUpperCase()),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: t.tx,
                    fontSize: 11,
                  ),
                  decoration: InputDecoration(hintText: 'Enter $label'),
                ),
              ),
              const SizedBox(width: 8),
              AdminButton(
                'Request erasure',
                kind: AdminButtonKind.destructive,
                onPressed: () => _erase(label, controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _retention(bool mobile) {
    final t = context.aurora;
    Widget periods = AdminPanel(
      title: 'Retention periods',
      hot: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Default durations for automated cleanup, subject to configured legal and contractual obligations.',
            style: TextStyle(color: t.tx3, fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 8),
          _retentionRow(
            'Behavioral frame data',
            'Gaze, person detection and frame-derived signals',
            [7, 14, 30, 60, 90],
          ),
          _retentionRow(
            'Interview recordings',
            'Retell AI audio/session recordings',
            [30, 60, 90, 180],
          ),
          _retentionRow(
            'Application resumes',
            'Uploaded resume files and extracted text',
            [30, 90, 180, 365],
          ),
          const SizedBox(height: 10),
          if (!mobile)
            Text(
              '🔒 Changes are logged to Audit log',
              style: TextStyle(color: t.tx3, fontSize: 10),
            ),
          AdminButton(
            'Save retention policy',
            kind: AdminButtonKind.primary,
            fullWidth: mobile,
            onPressed: _saveRetention,
          ),
        ],
      ),
    );
    Widget erasure = AdminPanel(
      title: 'Manual erasure',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request permanent erasure by user ID or job ID. Verification and backend permissions are required in production.',
            style: TextStyle(color: t.tx3, fontSize: 10, height: 1.4),
          ),
          _erasureForm('User ID', userIdController),
          _erasureForm('Job ID', jobIdController),
          const SizedBox(height: 9),
          const AdminCallout(
            title: 'Destructive intent',
            description: 'Typed confirmation required · logged to Audit log',
            tone: AdminTone.red,
          ),
        ],
      ),
    );
    Widget requestLog = AdminPanel(
      title: mobile
          ? 'Right-to-erasure requests'
          : 'Right-to-erasure request log',
      trailing: const AdminTag('2 PENDING', tone: AdminTone.amber),
      child: mobile
          ? Column(
              children: store.erasure
                  .map(
                    (r) => Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.field,
                        border: Border.all(color: t.edge),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  style: TextStyle(
                                    color: t.tx,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                MonoText(
                                  '${r.id} · ${r.userId} · ${r.received}',
                                  style: TextStyle(color: t.tx3, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                          AdminTag(
                            r.status,
                            tone: r.status == 'PENDING'
                                ? AdminTone.amber
                                : AdminTone.green,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('REQUEST')),
                  DataColumn(label: Text('USER')),
                  DataColumn(label: Text('USER ID')),
                  DataColumn(label: Text('RECEIVED')),
                  DataColumn(label: Text('STATUS')),
                ],
                rows: store.erasure
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(
                            MonoText(
                              r.id,
                              style: TextStyle(color: t.tx3, fontSize: 10),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.name,
                              style: TextStyle(color: t.tx, fontSize: 10),
                            ),
                          ),
                          DataCell(
                            MonoText(
                              r.userId,
                              style: TextStyle(color: t.tx3, fontSize: 10),
                            ),
                          ),
                          DataCell(
                            MonoText(
                              r.received,
                              style: TextStyle(color: t.tx3, fontSize: 10),
                            ),
                          ),
                          DataCell(
                            AdminTag(
                              r.status,
                              tone: r.status == 'PENDING'
                                  ? AdminTone.amber
                                  : AdminTone.green,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          mobile,
          'GOVERNANCE / PRIVACY',
          'Data retention',
          'Manage storage duration and request carefully confirmed data erasure.',
          action: mobile
              ? null
              : const AdminTag('PRIVACY CONTROLS', tone: AdminTone.red),
        ),
        if (mobile) const AdminTag('PRIVACY CONTROLS', tone: AdminTone.red),
        const SizedBox(height: 10),
        const AdminCallout(
          title: 'Lifecycle and privacy controls',
          description:
              'Policy changes and erasure actions create permanent audit records.',
          tone: AdminTone.blue,
        ),
        const SizedBox(height: 16),
        _two(periods, erasure, mobile),
        const SizedBox(height: 15),
        requestLog,
        if (mobile) _footer(),
      ],
    );
  }

  @override
  void dispose() {
    userIdController.dispose();
    jobIdController.dispose();
    auditSearchController.dispose();
    super.dispose();
  }
}

class _AdminLinePainter extends CustomPainter {
  _AdminLinePainter(this.points, this.color, this.grid);
  final List<double> points;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    final p = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(
          size.width * i / (points.length - 1),
          size.height * (1 - points[i]),
        ),
        3,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdminLinePainter old) =>
      old.color != color || old.points != points;
}
