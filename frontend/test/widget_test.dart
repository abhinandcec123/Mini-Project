// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lifepulse_ai/main.dart';
import 'package:lifepulse_ai/widgets/global_command_bar.dart';

void main() {
  testWidgets('LifePulse launches the role access hub',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const LifePulseApp());
    await tester.pumpAndSettle();

    expect(find.text('LifePulse AI'), findsOneWidget);
    expect(find.text('Secure LifePulse Access Hub'), findsOneWidget);
    expect(find.text('Donor'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('global command bar fits mobile width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: GlobalCommandBar(
            role: 'admin',
            profileName: 'Central Admin',
            onLogout: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Export project'), findsNothing);
    expect(find.text('Mobile preview'), findsNothing);
    expect(find.text('Desktop view'), findsNothing);
    expect(find.text('Radar Map'), findsNothing);
  });
}
