import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/widgets/workspace_rail_layout.dart';

void main() {
  testWidgets('the canvas slides while keeping its width during motion', (
    tester,
  ) async {
    const bodyKey = Key('body');
    const railKey = Key('rail');
    final widths = <double>[];
    final body = LayoutBuilder(
      builder: (_, constraints) {
        widths.add(constraints.maxWidth);
        return const SizedBox.expand(key: bodyKey);
      },
    );

    Widget workspace(bool expanded, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: SizedBox.expand(
        child: WorkspaceRailLayout(
          expanded: expanded,
          expandedWidth: 280,
          rail: const SizedBox.expand(key: railKey),
          railColor: Colors.white,
          railBorderColor: Colors.grey,
          body: body,
        ),
      ),
    );

    await tester.pumpWidget(workspace(false));
    final fullWidth = tester.getSize(find.byKey(bodyKey)).width + 60;
    final bodyElement = tester.element(find.byKey(bodyKey));

    await tester.pumpWidget(workspace(true));
    await tester.pump(const Duration(milliseconds: 60));
    final openingLeft = tester.getTopLeft(find.byKey(bodyKey)).dx;
    expect(openingLeft, inExclusiveRange(60, 280));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx, greaterThan(openingLeft));
    expect(widths, [fullWidth - 60]);
    await tester.pumpAndSettle();
    expect(widths, [fullWidth - 60, fullWidth - 280]);
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx, 280);

    await tester.pumpWidget(workspace(false));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.getTopLeft(find.byKey(bodyKey)).dx,
      inExclusiveRange(60, 280),
    );
    await tester.pumpAndSettle();
    expect(widths, [fullWidth - 60, fullWidth - 280, fullWidth - 60]);
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx, 60);
    expect(tester.element(find.byKey(bodyKey)), same(bodyElement));

    await tester.pumpWidget(workspace(true, reduceMotion: true));
    expect(tester.getTopLeft(find.byKey(bodyKey)).dx, 280);
    expect(tester.getSize(find.byKey(bodyKey)).width, fullWidth - 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
