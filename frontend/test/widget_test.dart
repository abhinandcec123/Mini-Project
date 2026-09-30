// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lifepulse_ai/main.dart';

void main() {
  testWidgets('LifePulse launches the role access hub',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LifePulseApp());
    await tester.pumpAndSettle();

    expect(find.text('LifePulse AI'), findsOneWidget);
    expect(find.text('Secure LifePulse Access Hub'), findsOneWidget);
    expect(find.text('Donor'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
