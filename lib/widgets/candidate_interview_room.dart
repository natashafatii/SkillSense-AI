part of 'candidate_interview_workspace.dart';

const _roomBackground = Color(0xFFF6F8FE);
const _roomInk = Color(0xFF16213A);
const _roomLine = Color(0xFFE3E9F2);
const _roomTeal = Color(0xFF0E987D);
const _roomBlue = Color(0xFF3E6FF0);
const _roomSub = Color(0xFF52607C);
const _clockPath = 'M12 7v5l3 2m6-2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z';
const _micPath =
    'M9 5a3 3 0 1 1 6 0v6a3 3 0 1 1-6 0Zm-4 6a7 7 0 0 0 14 0m-7 7v4';
const _cameraPath =
    'M5 6h9a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Zm11 5 5-3v8l-5-3';
const _leavePath =
    'M10 17l-5-5 5-5m-5 5h12m-2-8h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3';
const _expandPath = 'M4 9V4h5m11 5V4h-5M4 15v5h5m11-5v5h-5';
const _exitPath = 'M9 4v5H4m11-5v5h5M9 20v-5H4m11 5v-5h5';
const _roomShadow = BoxShadow(
  color: Color(0x4516213A),
  blurRadius: 24,
  spreadRadius: -12,
  offset: Offset(0, 12),
);

extension on _CandidateInterviewWorkspaceState {
  Widget _interviewRoom(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final mobile = size.width <= 720;
      final focused = _previewOrigin != null;
      final edge = (size.width * .03).clamp(16.0, 40.0);
      final cameraWidth = mobile
          ? 132.0
          : (size.width * .19).clamp(232.0, 320.0);
      final footerHeight = focused ? 100.0 : 102.0;
      return Stack(
        key: _roomViewport,
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _InterviewRoomBackground()),
          if (!focused)
            Positioned.fill(
              top: 64,
              bottom: footerHeight,
              child: _mainStage(context, size, mobile, cameraWidth),
            ),
          if (lifecycle.videoRequired)
            Positioned(
              left: mobile ? null : edge,
              right: mobile ? 14 : null,
              top: mobile ? 70 : null,
              bottom: mobile ? null : 116,
              width: cameraWidth,
              height: cameraWidth * 9 / 16,
              child: SizedBox(
                key: _cameraAnchor,
                child: focused
                    ? null
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        onEnter: (_) => _cameraHover.value = true,
                        onExit: (_) => _cameraHover.value = false,
                        child: _roomCamera(context, edge: edge),
                      ),
              ),
            ),
          if (focused) ...[
            AnimatedBuilder(
              animation: _previewAnimation,
              child: _roomCamera(context, focused: true, edge: edge),
              builder: (context, camera) => Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fromRect(
                    rect: Rect.lerp(
                      _previewOrigin,
                      Offset.zero & size,
                      Curves.easeInOutCubic.transform(_previewAnimation.value),
                    )!,
                    child: camera!,
                  ),
                ],
              ),
            ),
            ..._fullscreenPanels(context, size, edge),
          ],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 64,
            child: _roomHeader(context, mobile, focused, edge, size.width),
          ),
          if (liveMonitorEnabled && _live && media.cameraReady)
            Positioned(
              top: 64,
              left: 12,
              child: LiveMonitor(
                key: ValueKey(lifecycle.identity.sessionId),
                sessionId: lifecycle.identity.sessionId,
                lifecycle: lifecycle,
              ),
            ),
          Positioned(
            bottom: focused ? 20 : 22,
            left: 16,
            right: 16,
            child: _bottomBar(context, mobile, focused: focused),
          ),
        ],
      );
    },
  );

  Widget _roomHeader(
    BuildContext context,
    bool mobile,
    bool focused,
    double edge,
    double width,
  ) {
    final snapshot = lifecycle.snapshot;
    final startedAt = snapshot?.startedAt;
    final count =
        snapshot?.questionCount ??
        lifecycle
            .interview
            ?.interview
            .questionReadiness
            .approvedQuestionCount ??
        0;
    final number = lifecycle.exchange.number;
    final resolved =
        number == null &&
        snapshot?.conversationOutcome == 'IN_PROGRESS' &&
        snapshot?.approvedQuestions.isEmpty == true &&
        count > 0;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: edge),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _fitHeader(
              width * .39 - edge,
              Alignment.centerLeft,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 28,
                    height: 28,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'SkillSense',
                    style: AppType.h3.style(context, color: _roomInk),
                  ),
                ],
              ),
            ),
          ),
          if (!mobile && count > 0)
            Semantics(
              label: number == null
                  ? '$count interview questions'
                  : 'Question $number of $count',
              child: SizedBox(
                width: math.min(count * 36.0 - 6, width * .44),
                child: Row(
                  children: [
                    for (var index = 0; index < count; index++) ...[
                      if (index > 0) SizedBox(width: count > 20 ? 2 : 6),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color:
                                resolved ||
                                    (number != null && index < number - 1)
                                ? _roomTeal
                                : number == index + 1
                                ? _roomBlue
                                : _roomLine,
                          ),
                          child: const SizedBox(height: 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: _fitHeader(
              width * .61 - edge - 8,
              Alignment.centerRight,
              Tooltip(
                message: 'Connection details',
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _details(context, initiallyExpanded: true),
                        ),
                      ),
                    ),
                  ),
                  child: startedAt == null
                      ? _roomPill(context, '00:00')
                      : _RoomClock(
                          startedAt: startedAt,
                          stoppedAt: snapshot?.audioEndedAt,
                          builder: (value) => _roomPill(context, value),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return focused
        ? ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xDBFFFFFF),
                  border: Border(bottom: BorderSide(color: Color(0xB3FFFFFF))),
                ),
                child: content,
              ),
            ),
          )
        : content;
  }

  Widget _fitHeader(double width, Alignment alignment, Widget child) =>
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(0, width)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: child,
        ),
      );

  Widget _roomPill(BuildContext context, String text) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _roomLine),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      children: [
        const _RoomIcon(_clockPath, size: 15, color: _roomSub),
        const SizedBox(width: 7),
        Text(
          text,
          style: AppType.numeric.style(context, color: const Color(0xFF38476A)),
        ),
      ],
    ),
  );

  Widget _mainStage(
    BuildContext context,
    Size size,
    bool mobile,
    double cameraWidth,
  ) {
    final medium = size.width <= 1100 && !mobile;
    final bottom = medium && lifecycle.videoRequired
        ? cameraWidth * 9 / 16 + 20
        : 0.0;
    final top = mobile ? math.min(size.height * .14, 110.0) : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, top, 20, bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: mobile
                ? 0
                : math.max(0.0, constraints.maxHeight - bottom),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_questionBadge(context) case final badge?) ...[
                    badge,
                    const SizedBox(height: 12),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _questionText(),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      top: size.height <= 640
                          ? 16
                          : mobile
                          ? 24
                          : 34,
                      bottom: size.height <= 640
                          ? 16
                          : mobile
                          ? 18
                          : 28,
                    ),
                    child: _agent(
                      context,
                      orbSize: size.height <= 640
                          ? 52
                          : mobile
                          ? 84
                          : 116,
                      horizontal: size.height <= 640,
                      gap: 14,
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 660,
                      minHeight: 110,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: _answer(context),
                    ),
                  ),
                  if (!_live && liveMonitorEnabled && lifecycle.videoRequired)
                    const Text(
                      'Your assigned recruiter may watch your camera and listen to both speakers during this interview.',
                    ),
                  if (!_live) _audioAction(),
                  if (media.cameraError case final failure?)
                    Text(
                      failure.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (!_live || publisher.needsAttention)
                    _connectionNotice(context),
                  if (!_live) _details(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _questionBadge(BuildContext context, {bool focused = false}) {
    final count = lifecycle.snapshot?.questionCount;
    final number = lifecycle.exchange.number;
    if (count == null || number == null) return null;
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: focused ? 5 : 7,
        horizontal: focused ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFDCF4EE),
        border: Border.all(color: const Color(0xFFB4E6DA)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'QUESTION $number OF $count',
        style: AppType.overline.style(context, color: const Color(0xFF0A6353)),
      ),
    );
  }

  Widget _questionText({
    bool focused = false,
    TextAlign textAlign = TextAlign.center,
  }) => Semantics(
    header: true,
    liveRegion: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final text =
            lifecycle.exchange.question ??
            (_live &&
                    lifecycle.snapshot?.questionNumber == null &&
                    (lifecycle.snapshot?.questionCount ?? 0) > 0
                ? 'All questions answered. Confirm when you have finished.'
                : _live
                ? 'Waiting for the interviewer…'
                : 'Let’s get you connected.');
        final style = (focused ? AppType.h2 : AppType.h1).style(
          context,
          color: _roomInk,
        );
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final lines = painter.computeLineMetrics().length;
        var width = constraints.maxWidth;
        // Match CSS text-wrap: balance for headings with up to six lines.
        if (lines > 1 && lines <= 6) {
          var lower = width / lines;
          while (width - lower > 1) {
            final middle = (lower + width) / 2;
            painter.layout(maxWidth: middle);
            if (painter.computeLineMetrics().length > lines) {
              lower = middle;
            } else {
              width = middle;
            }
          }
        }
        painter.dispose();
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Text(text, textAlign: textAlign, style: style),
        );
      },
    ),
  );

  String get _answerPlaceholder {
    if (!_live) return 'Join the interview to connect your audio.';
    if (lifecycle.agentTalking || lifecycle.agentThinking) return '';
    return lifecycle.microphoneMuted
        ? 'Turn on your microphone to answer.'
        : 'Listening. Answer whenever you are ready.';
  }

  Widget _answer(BuildContext context, {bool focused = false}) {
    final answer = lifecycle.exchange.answer;
    final answerStyle = AppType.bodyLg.style(
      context,
      color: answer.isEmpty ? TypographyColors.secondary : _roomInk,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: focused
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoomDot(size: 8, color: _roomTeal),
            SizedBox(width: 9),
            Text(
              'YOUR ANSWER',
              style: AppType.overline.style(context, color: Color(0xFF38476A)),
            ),
          ],
        ),
        SizedBox(height: focused ? 8 : 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.textScalerOf(context).scale(answerStyle.fontSize!) *
                (focused ? 6.4 : 7.5),
          ),
          child: Semantics(
            liveRegion: true,
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                answer.isEmpty ? _answerPlaceholder : answer,
                textAlign: focused ? TextAlign.start : TextAlign.center,
                style: answerStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _agent(
    BuildContext context, {
    required double orbSize,
    required bool horizontal,
    required double gap,
  }) {
    final speaking = _live && lifecycle.agentTalking;
    final thinking =
        _live &&
        lifecycle.agentThinking &&
        lifecycle.exchange.answer.isNotEmpty;
    final listening =
        _live && !speaking && !thinking && !lifecycle.microphoneMuted;
    final state = speaking
        ? 'Asking'
        : thinking
        ? 'Thinking'
        : listening
        ? 'Listening'
        : _live
        ? 'Muted'
        : _voiceLabel;
    final color = thinking ? _roomBlue : const Color(0xFF087F69);
    return Flex(
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InterviewerOrb(
          size: orbSize,
          speaking: speaking,
          listening: listening,
        ),
        SizedBox(width: horizontal ? gap : 0, height: horizontal ? 0 : gap),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
            decoration: BoxDecoration(
              color: thinking
                  ? const Color(0xFFE4EBFD)
                  : const Color(0xFFE3F6F0),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoomDot(size: 6, color: thinking ? _roomBlue : _roomTeal),
                const SizedBox(width: 6),
                Text(state, style: AppType.badge.style(context, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _fullscreenPanels(BuildContext context, Size size, double edge) {
    final narrow = size.width <= 900;
    final short = size.height < 540;
    final questionTop = narrow ? 136.0 : 146.0;
    final answerBottom = narrow ? (short ? 88.0 : 96.0) : 100.0;
    final answerHeight = short ? 50.0 : 200.0;
    final showAnswer =
        lifecycle.exchange.answer.isNotEmpty || _answerPlaceholder.isNotEmpty;
    final questionHeight = showAnswer && short
        ? size.height - answerBottom - answerHeight - 30 - questionTop - 8
        : (size.height - questionTop - 60) * .4;
    final badge = _questionBadge(context, focused: true);
    return [
      Positioned(
        top: questionTop,
        left: narrow ? 16 : edge,
        width: narrow ? size.width - 32 : (size.width * .25).clamp(280, 360),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(44, questionHeight)),
          child: _roomPanel(
            radius: 18,
            shadow: const BoxShadow(
              color: Color(0x7316213A),
              blurRadius: 34,
              spreadRadius: -16,
              offset: Offset(0, 14),
            ),
            padding: narrow
                ? const EdgeInsets.fromLTRB(18, 14, 18, 16)
                : const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: narrow
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (badge != null) ...[badge, const SizedBox(height: 12)],
                  _questionText(
                    focused: true,
                    textAlign: narrow ? TextAlign.center : TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: narrow ? 80 : null,
        bottom: narrow ? null : 26,
        right: narrow ? 14 : edge,
        child: _roomPanel(
          radius: narrow ? 99 : 20,
          padding: narrow
              ? const EdgeInsets.fromLTRB(6, 6, 14, 6)
              : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: _agent(
            context,
            orbSize: narrow ? 42 : 72,
            horizontal: narrow,
            gap: narrow ? 10 : 8,
          ),
        ),
      ),
      if (showAnswer)
        Positioned(
          left: narrow ? 16 : 180,
          right: narrow ? 16 : 180,
          bottom: answerBottom,
          child: Center(
            child: SizedBox(
              width: 660,
              child: _roomPanel(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: answerHeight),
                  child: short
                      ? SingleChildScrollView(
                          reverse: true,
                          child: _answer(context, focused: true),
                        )
                      : _answer(context, focused: true),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _roomPanel({
    required double radius,
    required EdgeInsets padding,
    required Widget child,
    BoxShadow shadow = _roomShadow,
  }) {
    final border = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: border, boxShadow: [shadow]),
      child: ClipRRect(
        borderRadius: border,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ColoredBox(
            color: const Color(0xEDFFFFFF),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }

  Widget _roomCamera(
    BuildContext context, {
    bool focused = false,
    required double edge,
  }) {
    final on = media.cameraReady && !_hideSelfView;
    final compactExit = MediaQuery.sizeOf(context).width <= 720;
    final radius = BorderRadius.circular(focused ? 0 : 18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: focused ? [] : const [_roomShadow],
      ),
      child: ClipRRect(
        key: const Key('session-camera-stage'),
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8EEF8), Color(0xFFDBE5F3)],
                ),
              ),
            ),
            KeyedSubtree(
              key: _previewKey,
              child: Offstage(
                offstage: !on,
                child: media.adapter.buildPreview(),
              ),
            ),
            if (focused && on)
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x610A1428),
                        Color(0x000A1428),
                        Color(0x000A1428),
                        Color(0x800A1428),
                      ],
                      stops: [0, .3, .52, 1],
                    ),
                  ),
                ),
              ),
            if (!on)
              LayoutBuilder(
                builder: (context, constraints) {
                  final expanded = focused && constraints.maxHeight >= 260;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: expanded ? 60 : 32,
                          backgroundColor: Colors.white,
                          child: Text(
                            'You',
                            style: AppType.h1.style(context, color: _roomSub),
                          ),
                        ),
                        if (expanded) ...[
                          const SizedBox(height: 18),
                          Text(
                            _hideSelfView
                                ? 'Your self-view is hidden'
                                : 'Your camera is off',
                            style: AppType.h3.style(
                              context,
                              color: Color(0xFF38476A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: media.busy || !lifecycle.canUseMedia
                                ? null
                                : _toggleRoomCamera,
                            child: Text(
                              _hideSelfView
                                  ? 'Show self-view'
                                  : 'Turn on camera',
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            if (!focused)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _maximizePreview,
                  excludeFromSemantics: true,
                  child: const MouseRegion(cursor: SystemMouseCursors.click),
                ),
              ),
            if ((!focused && !compactExit) ||
                (focused && MediaQuery.sizeOf(context).width > 900))
              Positioned(
                bottom: focused ? 30 : 8,
                left: focused ? edge : 8,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x9E16213A),
                      borderRadius: BorderRadius.circular(focused ? 11 : 9),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: focused ? 13 : 10,
                        vertical: focused ? 8 : 5,
                      ),
                      child: Text(
                        'You',
                        style: AppType.bodySm.style(
                          context,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (focused)
              Positioned(
                top: compactExit ? 80 : 82,
                left: compactExit ? 12 : edge,
                child: TextButton(
                  focusNode: _previewControlFocus,
                  onPressed: _restorePreview,
                  style: TextButton.styleFrom(
                    minimumSize: Size(compactExit ? 44 : 0, 42),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppType.button.style(context),
                    padding: EdgeInsets.symmetric(
                      horizontal: compactExit ? 0 : 16,
                    ),
                    backgroundColor: const Color(0xF0FFFFFF),
                    foregroundColor: _roomInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const _RoomIcon(_exitPath, label: 'Exit full screen'),
                      if (!compactExit) ...[
                        const SizedBox(width: 8),
                        const Text('Exit full screen'),
                      ],
                    ],
                  ),
                ),
              )
            else
              Positioned(
                right: 8,
                top: 8,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _cameraHover,
                    _previewControlFocus,
                  ]),
                  builder: (context, button) => AnimatedOpacity(
                    opacity:
                        _cameraHover.value ||
                            _previewControlFocus.hasFocus ||
                            !WidgetsBinding
                                .instance
                                .mouseTracker
                                .mouseIsConnected
                        ? 1
                        : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: button,
                  ),
                  child: IconButton(
                    focusNode: _previewControlFocus,
                    onPressed: _maximizePreview,
                    tooltip: 'Expand your camera to full screen',
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(32),
                      minimumSize: const Size.square(32),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0x9E16213A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const _RoomIcon(_expandPath),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomIcon extends StatelessWidget {
  const _RoomIcon(this.path, {this.size = 20, this.color, this.label});

  final String path;
  final double size;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.75" '
    'stroke-linecap="round" stroke-linejoin="round"><path d="$path"/></svg>',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? _roomInk,
      BlendMode.srcIn,
    ),
    semanticsLabel: label,
  );
}

class _RoomDot extends StatelessWidget {
  const _RoomDot({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: SizedBox.square(dimension: size),
  );
}

class _InterviewerOrb extends StatefulWidget {
  const _InterviewerOrb({
    required this.size,
    required this.speaking,
    required this.listening,
  });
  final double size;
  final bool speaking, listening;

  @override
  State<_InterviewerOrb> createState() => _InterviewerOrbState();
}

class _InterviewerOrbState extends State<_InterviewerOrb>
    with SingleTickerProviderStateMixin {
  late final _rings = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateRings();
  }

  @override
  void didUpdateWidget(covariant _InterviewerOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRings();
  }

  void _updateRings() {
    if (widget.speaking && !MediaQuery.disableAnimationsOf(context)) {
      if (!_rings.isAnimating) _rings.repeat();
    } else {
      _rings.stop();
    }
  }

  @override
  void dispose() {
    _rings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.listening ? _roomTeal : _roomBlue;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(0, -.2),
                radius: .78,
                colors: [Colors.white, Color(0xFFE4F4F6)],
                stops: [.35, 1],
              ),
              border: Border.all(color: const Color(0xFFCFE6EA)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .08),
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: .45),
                  blurRadius: 48,
                  spreadRadius: -12,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
          ),
          if (widget.speaking && !MediaQuery.disableAnimationsOf(context))
            AnimatedBuilder(
              animation: _rings,
              builder: (context, _) => Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  for (var phase in [0.0, .5])
                    Transform.scale(
                      scale:
                          1 +
                          .7 *
                              Curves.easeOut.transform(
                                (_rings.value + phase) % 1,
                              ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF9FD3D8).withValues(
                              alpha: .9 * (1 - ((_rings.value + phase) % 1)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Center(
            child: SvgPicture.asset(
              'assets/images/logo.svg',
              width: widget.size * .58,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterviewRoomBackground extends CustomPainter {
  const _InterviewRoomBackground();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(_roomBackground, BlendMode.srcOver);
    _ellipse(canvas, size, .60, 1.12, .50, .36, const Color(0x142E63F0), .60);
    _ellipse(canvas, size, -.06, .46, .36, .30, const Color(0x170FB89B), .60);
    _ellipse(canvas, size, .82, -.08, .46, .34, const Color(0x290FB89B), .65);
  }

  void _ellipse(
    Canvas canvas,
    Size size,
    double x,
    double y,
    double rx,
    double ry,
    Color color,
    double stop,
  ) {
    canvas.save();
    canvas.translate(size.width * x, size.height * y);
    canvas.scale(size.width * rx, size.height * ry);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: [0, stop],
        ).createShader(const Rect.fromLTRB(-1, -1, 1, 1)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InterviewRoomBackground oldDelegate) => false;
}
