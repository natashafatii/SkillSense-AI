part of 'recruitment_review_screen.dart';

extension _CompactInterviewReview on _RecruitmentReviewScreenState {
  Widget _compactReview(RecruitmentReview? review) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(fontFamily: 'Plus Jakarta Sans');
    final width = MediaQuery.sizeOf(context).width;
    final gutter = ScreeningStyle.gutter(width);
    final compact = width <= 640;
    final sideBySide = width > 900;
    final refresh = ScreeningButton(
      'Refresh review',
      glyph: ScreeningGlyph.refresh,
      onPressed: controller.loading || controller.busy ? null : _refresh,
    );
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interview evidence & decisions',
          style: ScreeningStyle.text(
            (width * .024).clamp(22.0, 26.0),
            weight: 800,
            height: 1.15,
            spacing: -.7,
          ),
        ),
        if (review != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              review.application.jobTitle,
              review.application.jobCompany,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: ScreeningStyle.text(
              13,
              weight: 500,
              color: ScreeningStyle.muted,
            ),
          ),
        ],
      ],
    );
    final pageContent = review == null
        ? <Widget>[]
        : _tab == _compactTabs.length - 1
        ? [decisions(review)]
        : _tabContent(review);
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: ScreeningStyle.blue,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: ScreeningStyle.ink,
          error: ScreeningStyle.red,
        ),
        textTheme: textTheme.copyWith(
          bodyMedium: ScreeningStyle.text(13),
          bodyLarge: ScreeningStyle.text(13),
        ),
        dividerTheme: const DividerThemeData(
          color: ScreeningStyle.line,
          thickness: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          border: ScreeningStyle.field().border,
          enabledBorder: ScreeningStyle.field().enabledBorder,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ScreeningStyle.ink,
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            side: const BorderSide(color: ScreeningStyle.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: ScreeningStyle.text(12.5, weight: 600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: ScreeningStyle.blue,
            textStyle: ScreeningStyle.text(12.5, weight: 600),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: ScreeningStyle.canvas,
        body: CustomPaint(
          painter: const ScreeningBackground(),
          child: SafeArea(
            child: DefaultTextStyle(
              style: ScreeningStyle.text(13),
              child: Column(
                children: [
                  ScreeningCommandBar(
                    section: 'Interview review',
                    onSearch: () => _jumpReview(review),
                  ),
                  if (controller.loading || controller.busy)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: ScreeningStyle.accent,
                    ),
                  Expanded(
                    child: ListView(
                      key: PageStorageKey('compact-review-$_tab'),
                      padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 40),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              foregroundColor: ScreeningStyle.muted,
                              minimumSize: const Size(0, 28),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: ScreeningStyle.text(12.5, weight: 600),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScreeningIcon(
                                  ScreeningGlyph.back,
                                  color: ScreeningStyle.muted,
                                ),
                                SizedBox(width: 6),
                                Text('Back to screening evidence'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (compact) ...[
                          heading,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: refresh,
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: heading),
                              const SizedBox(width: 12),
                              refresh,
                            ],
                          ),
                        const SizedBox(height: 14),
                        ..._reviewNotices(),
                        if (review != null) ...[
                          _reviewHeader(review),
                          const SizedBox(height: 14),
                          _reviewSegments(),
                          const SizedBox(height: 14),
                          if (review.interview == null && _tab == 0)
                            _reviewCard(
                              'No interview evaluation yet',
                              children: const [
                                Text(
                                  'Interview answers, scores, and hiring decisions become available after an interview is completed and evaluated.',
                                ),
                              ],
                            ),
                          if (sideBySide && _tab != _compactTabs.length - 1)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: pageContent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: width <= 1100 ? 290 : 320,
                                  child: decisions(review),
                                ),
                              ],
                            )
                          else
                            ...pageContent,
                        ],
                      ],
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

  List<String> get _compactTabs => [
    ..._RecruitmentReviewScreenState._tabs,
    'Decision',
  ];

  void _selectPage(int index) {
    if (_tab != index) _update(() => _tab = index);
  }

  void _jumpReview(RecruitmentReview? review) {
    if (review == null) return;
    showScreeningSearch(context, {
      for (final (index, label) in _compactTabs.indexed)
        label: () => _selectPage(index),
    });
  }

  Widget _reviewSegments() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ScreeningStyle.soft,
        border: Border.all(color: ScreeningStyle.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          for (final (index, label) in _compactTabs.indexed)
            Semantics(
              selected: _tab == index,
              child: TextButton(
                onPressed: () => _selectPage(index),
                style: TextButton.styleFrom(
                  foregroundColor: _tab == index
                      ? ScreeningStyle.blue
                      : ScreeningStyle.muted,
                  backgroundColor: _tab == index
                      ? Colors.white
                      : Colors.transparent,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: ScreeningStyle.text(12, weight: 600),
                ),
                child: Text(label),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _screeningReviewCard(
    String title,
    List<Widget> children, {
    Widget? badge,
    Widget? leading,
  }) {
    final inset = ScreeningStyle.inset(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ScreeningPanel(
        tint: title == 'Decision',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 15, inset, 10),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (leading != null) leading,
                      Text(title, style: ScreeningStyle.title()),
                    ],
                  ),
                  if (badge != null) badge,
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmScreeningReview(
    String title,
    String detail,
    TextEditingController? input,
    TextEditingController? justification,
  ) async =>
      await showDialog<bool>(
        context: context,
        barrierColor: const Color(0x800b1730),
        builder: (context) => ScreeningDialog(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(detail),
              if (input != null) _reviewReason('Reason (required)', input),
              if (justification != null)
                _reviewReason(
                  'Override justification (required)',
                  justification,
                ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ScreeningButton(
                    'Cancel',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([input, justification]),
                    builder: (_, _) => ScreeningButton(
                      'Confirm',
                      kind: ScreeningButtonKind.primary,
                      onPressed:
                          (input?.text.trim().isEmpty ?? false) ||
                              (justification?.text.trim().isEmpty ?? false)
                          ? null
                          : () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ) ??
      false;

  Widget _reviewReason(String label, TextEditingController controller) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ScreeningStyle.text(12.5, weight: 700)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              maxLength: 2000,
              minLines: 3,
              maxLines: 3,
              style: ScreeningStyle.text(12.5, weight: 500),
              decoration: ScreeningStyle.field(),
            ),
          ],
        ),
      );
}
