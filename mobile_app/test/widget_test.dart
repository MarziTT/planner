import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pixel_planner_mobile/app/app.dart';

void main() {
  testWidgets('Pixel Planner app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PixelPlannerApp()));
    await tester.pump();

    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
