// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:net_debug_tool/app/app.dart';

void main() {
  testWidgets('App starts and shows theme switch action', (WidgetTester tester) async {
    await tester.pumpWidget(const NetDebugApp());

    expect(find.text('TCP Server'), findsOneWidget);
    expect(find.byTooltip('切换明暗主题'), findsWidgets);
  });
}
