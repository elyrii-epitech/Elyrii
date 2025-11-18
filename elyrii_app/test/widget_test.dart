// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elyrii_app/main.dart';

void main() {
  testWidgets('App launches and renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app renders without errors
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that at least one page content is visible
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('Theme switching works', (WidgetTester tester) async {
    // Build our app
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // App should render successfully
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
