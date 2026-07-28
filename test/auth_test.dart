import 'package:chargenet_mobile/features/auth/login_screen.dart';
import 'package:chargenet_mobile/features/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the auth forms.
///
/// Every case stops at local validation, so nothing here touches the network or
/// the platform keystore.
void main() {
  /// A phone-sized surface: the forms scroll, but tapping needs the fields to
  /// be laid out where the user would see them.
  Future<void> pumpAuthScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: screen));
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('login reports an empty email and password', (tester) async {
    await pumpAuthScreen(tester, const LoginScreen());

    expect(find.text('Enter your email'), findsNothing);
    expect(find.text('Enter your password'), findsNothing);

    await tapButton(tester, 'Log in');

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('login rejects a malformed email', (tester) async {
    await pumpAuthScreen(tester, const LoginScreen());

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tapButton(tester, 'Log in');

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('the debug demo shortcut prefills the demo account', (
    tester,
  ) async {
    await pumpAuthScreen(tester, const LoginScreen());

    final demoButton = find.text('Use demo account');
    await tester.ensureVisible(demoButton);
    await tester.tap(demoButton);
    await tester.pump();

    expect(find.text(LoginScreen.demoEmail), findsOneWidget);
  });

  testWidgets('register rejects a mismatched confirmation', (tester) async {
    await pumpAuthScreen(tester, const RegisterScreen());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Aisyah Rahman');
    await tester.enterText(fields.at(1), 'aisyah@chargenet.my');
    await tester.enterText(fields.at(2), 'Sekret123');
    await tester.enterText(fields.at(3), 'Sekret124');
    await tapButton(tester, 'Create account');

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.text('Enter your name'), findsNothing);
  });
}
