import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pri_app/main.dart';

void main() {
  testWidgets('App renders with title and route selector',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BusTimeApp());

    expect(find.text('HK Bus ETA'), findsWidgets);
    expect(find.text('Select Route'), findsOneWidget);
    expect(find.text('S56'), findsWidgets);
  });
}
