import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows light onboarding even when the OS prefers dark', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    isUserOnboardedNotifier.value = false;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    // Use a phone-sized surface: the default 800x600 makes the onboarding
    // artwork overflow. pumpAndSettle is avoided because the Lottie animation
    // loops forever.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('One app, Charge Anywhere.'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('One app, Charge Anywhere.')))
          .brightness,
      Brightness.light,
    );
  });
}
