import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../dashboard/command_deck_screen.dart' show GridPainter;

class ScheduleInterviewScreen extends StatefulWidget {
  const ScheduleInterviewScreen({super.key});

  @override
  State<ScheduleInterviewScreen> createState() => _ScheduleInterviewScreenState();
}

class _ScheduleInterviewScreenState extends State<ScheduleInterviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Days list with concurrency booked load count
  final List<Map<String, dynamic>> _days = [
    {'day': 'MON', 'num': '11', 'booked': 6, 'limit': 10, 'selected': false, 'expanded': false},
    {'day': 'TUE', 'num': '12', 'booked': 4, 'limit': 10, 'selected': false, 'expanded': false},
    {'day': 'WED', 'num': '13', 'booked': 8, 'limit': 10, 'selected': true, 'expanded': true},
    {'day': 'THU', 'num': '14', 'booked': 0, 'limit': 10, 'selected': false, 'expanded': false},
    {'day': 'FRI', 'num': '15', 'booked': 5, 'limit': 10, 'selected': false, 'expanded': false},
  ];

  // Map of daily slots with three states: 'free', 'selected', 'taken'
  // Taken slots remain visible (struck-through, muted) for density inspection.
  late Map<int, List<Map<String, dynamic>>> _slotsPerDay;

  // Candidates awaiting schedule
  final List<Map<String, dynamic>> _candidates = [
    {
      'initials': 'AK',
      'name': 'Ayesha Khalid',
      'desc': 'Shortlisted 2d ago · 91',
      'slot': '13:00 Wed',
      'color': const Color(0xFFEFF6FF),
      'textCol': AppColors.dashboardBlue,
    },
    {
      'initials': 'FF',
      'name': 'F. Fatima',
      'desc': 'Shortlisted 1d ago · 78',
      'slot': 'Slot',
      'color': Colors.white,
      'textCol': const Color(0xFF475569),
    },
    {
      'initials': 'ZA',
      'name': 'Z. Abdullah',
      'desc': 'Shortlisted 5h ago · 74',
      'slot': 'Slot',
      'color': Colors.white,
      'textCol': const Color(0xFF475569),
    },
  ];

  int _selectedDayIndex = 2; // Default to Wednesday
  int _selectedCandidateIndex = 0; // Default to first candidate

  @override
  void initState() {
    super.initState();
    _slotsPerDay = {
      0: [
        {'time': '09:00', 'state': 'taken'},
        {'time': '10:30', 'state': 'free'},
        {'time': '13:00', 'state': 'taken'},
        {'time': '15:30', 'state': 'free'},
      ],
      1: [
        {'time': '09:00', 'state': 'taken'},
        {'time': '10:30', 'state': 'free'},
        {'time': '13:00', 'state': 'free'},
        {'time': '15:30', 'state': 'taken'},
      ],
      2: [
        {'time': '09:00', 'state': 'taken'},
        {'time': '10:30', 'state': 'free'},
        {'time': '11:30', 'state': 'taken'},
        {'time': '13:00', 'state': 'selected'},
        {'time': '14:00', 'state': 'taken'},
        {'time': '15:30', 'state': 'free'},
        {'time': '17:00', 'state': 'free'},
      ],
      3: [
        {'time': '09:00', 'state': 'free'},
        {'time': '10:30', 'state': 'free'},
        {'time': '13:00', 'state': 'free'},
        {'time': '15:30', 'state': 'free'},
      ],
      4: [
        {'time': '09:00', 'state': 'taken'},
        {'time': '10:30', 'state': 'taken'},
        {'time': '13:00', 'state': 'free'},
        {'time': '15:30', 'state': 'free'},
      ],
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectDay(int index) {
    setState(() {
      for (int i = 0; i < _days.length; i++) {
        _days[i]['selected'] = i == index;
      }
      _selectedDayIndex = index;
    });
  }

  void _selectSlot(int dayIndex, int slotIndex) {
    final slot = _slotsPerDay[dayIndex]![slotIndex];
    if (slot['state'] == 'taken') return; // Struck-through and taken: disabled

    setState(() {
      // Clear previous selection for this day
      for (var s in _slotsPerDay[dayIndex]!) {
        if (s['state'] == 'selected') {
          s['state'] = 'free';
        }
      }
      slot['state'] = 'selected';

      // Bind slot to selected candidate
      final dayName = _days[dayIndex]['day'].substring(0, 1) +
          _days[dayIndex]['day'].substring(1, 3).toLowerCase();
      _candidates[_selectedCandidateIndex]['slot'] = '${slot['time']} $dayName';
      _candidates[_selectedCandidateIndex]['color'] = const Color(0xFFEFF6FF);
      _candidates[_selectedCandidateIndex]['textCol'] = AppColors.dashboardBlue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── BASE GRADIENT ──────────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                ),
              ),
            ),
          ),

          // ── GRID PATTERN OVERLAY (Web Only) ─────────────────────────────────
          if (!isMobile) Positioned.fill(child: CustomPaint(painter: GridPainter())),

          // ── MAIN WORKSPACE CONTENT ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                // 1. LEFT RAIL (Web Only)
                if (!isMobile) _buildLeftRail(context),

                // 2. WORKSPACE
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar (Web Only)
                      if (!isMobile) _buildTopBar(),

                      // Mobile Header (Mobile Only)
                      if (isMobile) _buildMobileHeader(),

                      // Layout views
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 12 : 8,
                          ),
                          child: isMobile ? _buildMobileLayout() : _buildWebLayout(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── MOBILE BOTTOM NAVIGATION DOCK ──────────────────────────────────
          if (isMobile)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildMobileBottomDock(),
            ),
        ],
      ),
    );
  }

  // ── WEB LAYOUT ─────────────────────────────────────────────────────────────
  Widget _buildWebLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderArea(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel (Calendar Grid + Invite settings)
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildThisWeekCardWeb(),
                  const SizedBox(height: 20),
                  _buildInvitationCardWeb(),
                ],
              ),
            ),
            const SizedBox(width: 20),

            // Right Panel (Awaiting Queue)
            Expanded(
              flex: 2,
              child: _buildAwaitingScheduleCardWeb(),
            ),
          ],
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT (Stacked day-by-day expandable slots) ────────────────────
  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Candidate selection header
        _buildMobileAwaitingQueue(),
        const SizedBox(height: 16),

        // Title Capacity
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available days',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Cap: 10/day',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Day list (collapsible list)
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _days.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final day = _days[index];
            final bool isExpanded = day['expanded'];
            final int booked = day['booked'];
            final int limit = day['limit'];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: day['selected'] ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
                  width: day['selected'] ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  // Collapsible Day Header Row
                  InkWell(
                    onTap: () {
                      setState(() {
                        day['expanded'] = !isExpanded;
                        _selectDay(index);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${day['day']} ${day['num']}',
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (day['selected'])
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.dashboardBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              // Load Concurrency limit badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$booked/$limit booked',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Slot chips shown when expanded
                  if (isExpanded) ...[
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(_slotsPerDay[index]!.length, (sIdx) {
                          final slot = _slotsPerDay[index]![sIdx];
                          final String state = slot['state'];
                          final String time = slot['time'];

                          Color bg = Colors.white;
                          Color textCol = const Color(0xFF475569);
                          Border border = Border.all(color: const Color(0xFFCBD5E1), width: 1.2);
                          TextDecoration textDec = TextDecoration.none;

                          if (state == 'selected') {
                            bg = const Color(0xFFEFF6FF);
                            textCol = AppColors.dashboardBlue;
                            border = Border.all(color: AppColors.dashboardBlue, width: 1.5);
                          } else if (state == 'taken') {
                            bg = const Color(0xFFF1F5F9);
                            textCol = const Color(0xFF94A3B8);
                            border = Border.all(color: const Color(0xFFE2E8F0), width: 1);
                            textDec = TextDecoration.lineThrough;
                          }

                          return InkWell(
                            onTap: () => _selectSlot(index, sIdx),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44, minWidth: 70), // touch targets
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                                border: border,
                              ),
                              child: Center(
                                child: Text(
                                  time,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: textCol,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    decoration: textDec,
                                    decorationColor: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // Mobile Invitation / Booking Lifecycle card
        _buildMobileInvitationCard(),

        const SizedBox(height: 110),
      ],
    );
  }

  // ── MOBILE AWAITING QUEUE CHIPS ────────────────────────────────────────────
  Widget _buildMobileAwaitingQueue() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Awaiting schedule',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final cand = _candidates[idx];
              final isSelected = _selectedCandidateIndex == idx;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCandidateIndex = idx;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFCBD5E1) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            cand['initials'],
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cand['name'],
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              cand['desc'],
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.dashboardBlue : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          cand['slot'],
                          style: GoogleFonts.jetBrainsMono(
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── MOBILE INVITATION CARD ─────────────────────────────────────────────────
  Widget _buildMobileInvitationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking lifecycle',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Concise mobile lifecycle display text
          Text(
            'Invite sent → device-check link → reminders 24h/1h → 10-min no-show release',
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invitations Sent Successfully!')),
                );
                Navigator.of(context).pushReplacementNamed('/pipeline');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dashboardBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: Text(
                'Send invite',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE APP HEADER ──────────────────────────────────────────────────────
  Widget _buildMobileHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset('assets/images/logo.svg', height: 26),
              const SizedBox(width: 10),
              Text(
                'Schedule',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569)),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              Navigator.of(context).pushReplacementNamed(val);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: '/monitor',
                child: Row(
                  children: [
                    const Icon(Icons.videocam_rounded, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text('Live Monitor', style: GoogleFonts.inter(fontSize: 13.5)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: '/review',
                child: Row(
                  children: [
                    const Icon(Icons.video_library_rounded, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text('Interview Review', style: GoogleFonts.inter(fontSize: 13.5)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: '/settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text('Settings', style: GoogleFonts.inter(fontSize: 13.5)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WEB HEADER AREA ────────────────────────────────────────────────────────
  Widget _buildHeaderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Schedule Interview',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/monitor');
                },
                icon: const Icon(Icons.videocam_rounded, size: 16),
                label: Text(
                  'Live Monitor',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dashboardBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/review');
                },
                icon: const Icon(Icons.video_library_rounded, size: 16),
                label: Text(
                  'Interview Review',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WEB THIS WEEK CALENDAR GRID CARD ───────────────────────────────────────
  Widget _buildThisWeekCardWeb() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This week',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '‹ May 11-17 ›',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Days row with 6/10 booked indicators
          LayoutBuilder(
            builder: (context, constraints) {
              final double cellWidth = (constraints.maxWidth - 4 * 12) / 5;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(_days.length, (idx) {
                  final day = _days[idx];
                  final isSelected = day['selected'];

                  return InkWell(
                    onTap: () => _selectDay(idx),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: cellWidth,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.dashboardBlue : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.dashboardBlue.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            day['day'],
                            style: GoogleFonts.inter(
                              color: isSelected ? AppColors.dashboardBlue : const Color(0xFF94A3B8),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            day['num'],
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Agent booked loads vs limit cap count
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0x193B82F6) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${day['booked']}/${day['limit']} booked',
                              style: GoogleFonts.jetBrainsMono(
                                color: isSelected ? AppColors.dashboardBlue : const Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 20),

          // Daily time slots
          Text(
            '${_days[_selectedDayIndex]['day']}DAY INTERVIEW TIMESLOTS',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),

          // Slot Chips Wrap (never hide taken ones)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_slotsPerDay[_selectedDayIndex]!.length, (sIdx) {
              final slot = _slotsPerDay[_selectedDayIndex]![sIdx];
              final String state = slot['state'];
              final String time = slot['time'];

              Color bg = Colors.white;
              Color textCol = const Color(0xFF475569);
              Border border = Border.all(color: const Color(0xFFCBD5E1), width: 1.2);
              TextDecoration textDec = TextDecoration.none;

              if (state == 'selected') {
                bg = const Color(0xFFEFF6FF);
                textCol = AppColors.dashboardBlue;
                border = Border.all(color: AppColors.dashboardBlue, width: 1.5);
              } else if (state == 'taken') {
                bg = const Color(0xFFF1F5F9);
                textCol = const Color(0xFF94A3B8);
                border = Border.all(color: const Color(0xFFE2E8F0), width: 1);
                textDec = TextDecoration.lineThrough;
              }

              return InkWell(
                onTap: () => _selectSlot(_selectedDayIndex, sIdx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                    border: border,
                  ),
                  child: Text(
                    time,
                    style: GoogleFonts.jetBrainsMono(
                      color: textCol,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      decoration: textDec,
                      decorationColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── WEB INVITATION CARD (Booking Lifecycle) ────────────────────────────────
  Widget _buildInvitationCardWeb() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invitation lifecycle policy',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // Directly stated lifecycle operational rule text copy
          Text(
            'Stated rules: Invite sent → device-check link → reminder at 24h and 1h → slot auto-released after 10 min no-show.',
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email Preview Opened')),
                      );
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: Text(
                        'Preview email',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invitations Sent Successfully!')),
                      );
                      Navigator.of(context).pushReplacementNamed('/pipeline');
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Center(
                      child: Text(
                        'Send invite',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── WEB AWAITING SCHEDULE CARD ─────────────────────────────────────────────
  Widget _buildAwaitingScheduleCardWeb() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Awaiting schedule',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _buildSmallBadge(label: 'SHORTLIST', color: AppColors.dashboardBlue),
            ],
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _candidates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, idx) {
              final cand = _candidates[idx];
              final isSelected = _selectedCandidateIndex == idx;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCandidateIndex = idx;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE2E8F0) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            cand['initials'],
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF475569),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cand['name'],
                              style: GoogleFonts.inter(
                                color: const Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              cand['desc'],
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.dashboardBlue : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? AppColors.dashboardBlue : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Text(
                          cand['slot'],
                          style: GoogleFonts.jetBrainsMono(
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  // ── DOCK ON MOBILE ─────────────────────────────────────────────────────────
  Widget _buildMobileBottomDock() {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink(); // Auto-hide
    }

    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMobileDockItem(Icons.dashboard_rounded, '/dashboard', false),
          _buildMobileDockItem(Icons.menu_book_rounded, '/pipeline', false),
          _buildMobileDockItem(Icons.calendar_month_rounded, '/schedule', true), // active
          _buildMobileDockItem(Icons.emoji_events_outlined, '/rankings', false),
          _buildMobileDockItem(Icons.analytics_outlined, '/analytics', false),
        ],
      ),
    );
  }

  Widget _buildMobileDockItem(IconData icon, String route, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.of(context).pushReplacementNamed(route);
        }
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? AppColors.dashboardBlue : Colors.transparent,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF94A3B8),
          size: 22,
        ),
      ),
    );
  }

  // ── LEFT RAIL NAVIGATION (Web) ─────────────────────────────────────────────
  Widget _buildLeftRail(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'route': '/dashboard'},
      {'icon': Icons.menu_book_rounded, 'label': 'Jobs', 'route': '/pipeline'},
      {'icon': Icons.calendar_month_rounded, 'label': 'Interviews', 'route': '/schedule'},
      {'icon': Icons.emoji_events_outlined, 'label': 'Rankings', 'route': '/rankings'},
      {'icon': Icons.analytics_outlined, 'label': 'Analytics', 'route': '/analytics'},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/settings'},
    ];

    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              child: SvgPicture.asset('assets/images/logo.svg', height: 48),
            ),
          ),
          const SizedBox(height: 40),

          // Nav Items
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final isSelected = index == 2; // Interviews is active/selected (index 2)
                final item = navItems[index];
                final bool hasBadge = index == 1; // Jobs has unread item badge "18"

                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Active glowing orb
                      if (isSelected)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.dashboardBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.dashboardBlue.withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),

                      Tooltip(
                        message: item['label'],
                        waitDuration: const Duration(milliseconds: 350),
                        preferBelow: false,
                        verticalOffset: 24,
                        margin: const EdgeInsets.only(left: 45),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              if (!isSelected) {
                                Navigator.of(context).pushReplacementNamed(item['route']);
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: Icon(
                                  item['icon'],
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                  size: 19,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badge Sit on Top-Right Corner
                      if (hasBadge)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.dashboardBlue,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              '18',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
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

          // Avatar bottom
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
            ),
            child: Center(
              child: Text(
                'AR',
                style: GoogleFonts.inter(
                  color: AppColors.dashboardBlue,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WEB TOP BAR ────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumbs
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushReplacementNamed('/pipeline');
                  },
                  child: Text(
                    'INTERVIEWS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                ' / ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFCBD5E1),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'SCHEDULE',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Actions Search/Notifications
          Row(
            children: [
              // Search Input
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search or jump to...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF64748B),
                      size: 16,
                    ),
                    suffixIcon: Container(
                      width: 32,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '⌘K',
                        style: GoogleFonts.jetBrainsMono(
                          color: const Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Notification button
              _buildTopBarIconButton(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                badgeColor: AppColors.dashboardRed,
              ),
              const SizedBox(width: 10),

              // Language button
              _buildTopBarIconButton(
                icon: Icons.language_rounded,
                hasBadge: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required bool hasBadge,
    Color? badgeColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: const Color(0xFF475569), size: 18),
          if (hasBadge)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
