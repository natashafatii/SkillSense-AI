import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skillsense_ai/screens/hr/recruitment_review_screen.dart';
import 'phase2_contract.dart' as f;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'historical attempt selectors reset and require latest evidence for decision commands',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = f.Fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentReviewScreen(
            applicationId: 'app',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('interview')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('older · EVALUATED').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('transcript-older-new')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Select the latest attempt to review its current evidence',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Deliberate early override'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Override: HIRE'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a selected transcript leaving the history window is never replaced silently',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = f.Fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentReviewScreen(
            applicationId: 'app',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transcript-interview-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revision 1 · provider').last);
      await tester.pumpAndSettle();
      fixture.hideOldTranscript = true;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no newer transcript has been substituted'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Select this transcript and reevaluate',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'insufficient evidence permits deliberate transcript correction but no normal decision',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = f.Fixture()
        ..completionOutcome = 'INSUFFICIENT_EVIDENCE'
        ..workflow = 'INSUFFICIENT_EVIDENCE';
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentReviewScreen(
            applicationId: 'app',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Select this transcript and reevaluate',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'HIRE'))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining('Combined recommendation: Unavailable'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'recruiter sees authoritative scores and frozen evidence; conflicts preserve the reason',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = f.Fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentReviewScreen(
            applicationId: 'app',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Server scores'), findsOneWidget);
      expect(
        find.textContaining('Combined recommendation: 0.0%'),
        findsOneWidget,
      );
      expect(find.textContaining('Selected: new'), findsOneWidget);
      expect(find.textContaining('Frozen transcript 1'), findsOneWidget);
      expect(find.textContaining('No extraction record'), findsOneWidget);
      await tester.tap(find.text('Frozen wording · ANSWERED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('“yes” — turn'));
      await tester.pumpAndSettle();
      expect(find.text('Frozen turn turn'), findsOneWidget);
      expect(find.text('user\nHi 😀 yes'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('workflow-command-reason')),
        'Preserved recruiter wording',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'HIRE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Application version 7'), findsOneWidget);
      fixture.conflict = true;
      fixture.version = 8;
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved input retained'), findsOneWidget);
      expect(find.text('Preserved recruiter wording'), findsOneWidget);
      expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'mobile evidence workflow lays out without overflow and never makes a provider request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = f.Fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentReviewScreen(
            applicationId: 'app',
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 9; step++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(fixture.requests.every((r) => r.method == 'GET'), isTrue);
      expect(
        fixture.requests.any((r) => r.path.contains('voice-session')),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
