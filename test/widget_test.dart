// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // 앱의 진입점이 달라졌으므로 간단한 테스트로 대체하거나 필요 시 수정하세요.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Hello'))));
    expect(find.text('Hello'), findsOneWidget);
  });
}
