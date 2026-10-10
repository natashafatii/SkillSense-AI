import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillsense_ai/widgets/country_code_phone_field.dart';

void main() {
  testWidgets(
    'desktop country menu is separate from phone focus and validates length',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController();
      final focusNode = FocusNode();
      final formKey = GlobalKey<FormState>();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      String phone = '';
      bool valid = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Form(
                  key: formKey,
                  child: CountryCodePhoneField(
                    controller: controller,
                    focusNode: focusNode,
                    onPhoneChanged: (value) => phone = value,
                    onValidityChanged: (value) => valid = value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final numberInput = find.byType(TextField);
      final countryChip = find.byKey(const Key('country-picker-chip'));
      expect(
        tester.getTopLeft(countryChip).dx,
        lessThan(tester.getTopLeft(numberInput).dx),
      );
      await tester.tap(numberInput);
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
      expect(find.byKey(const Key('country-dropdown')), findsNothing);

      await tester.tap(countryChip);
      await tester.pumpAndSettle();
      final dropdown = find.byKey(const Key('country-dropdown'));
      final phoneBox = find.byKey(const Key('phone-field-box'));
      expect(dropdown, findsOneWidget);
      expect(tester.getTopLeft(dropdown).dx, tester.getTopLeft(phoneBox).dx);
      expect(
        tester.getTopLeft(dropdown).dy,
        tester.getBottomLeft(phoneBox).dy + 6,
      );
      expect(tester.getSize(dropdown).width, 320);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(find.byKey(const Key('country-search')), 'India');
      await tester.pump();
      expect(find.text('India'), findsNWidgets(2));
      expect(find.text('Pakistan'), findsNothing);
      await tester.tap(find.text('India').last);
      await tester.pumpAndSettle();
      expect(find.text('+91'), findsOneWidget);
      expect(focusNode.hasFocus, isTrue);
      await tester.tap(countryChip);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(dropdown, findsNothing);
      await tester.tap(countryChip);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(dropdown, findsNothing);
      focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('Phone number is required'), findsOneWidget);
      final phoneDecoration =
          tester.widget<Container>(phoneBox).decoration! as BoxDecoration;
      expect(phoneDecoration.border!.top.color, const Color(0xFFE85D5B));
      await tester.tap(numberInput);
      await tester.pumpAndSettle();
      expect(find.text('0 / 10 digits'), findsOneWidget);

      await tester.enterText(numberInput, '987654321');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      expect(valid, isFalse);
      await tester.enterText(numberInput, '9876543210');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      expect(valid, isTrue);
      expect(phone, '+919876543210');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile country picker is a bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CountryCodePhoneField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('country-picker-chip')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('country-search')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('country-search')),
      'United Arab',
    );
    await tester.pump();
    expect(find.text('Pakistan'), findsNothing);
    await tester.tap(find.text('United Arab Emirates'));
    await tester.pumpAndSettle();
    expect(find.text('+971'), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
