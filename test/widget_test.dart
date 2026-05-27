// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: We might need to mock Firebase or AuthService if the test fails due to them.
    // For a simple smoke test, we'll try to pump the widget.
    await tester.pumpWidget(const MyApp());

    // Verify that our bottom navigation labels are present.
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('레시피'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('마이'), findsOneWidget);
  });
}
