// Basic smoke test for FitCalorie app.
//
// The AppLoader widget accesses Supabase in initState, so a full
// integration launch is not possible without a running Supabase instance.
// This test simply verifies that the widget tree can be constructed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme smoke test', (WidgetTester tester) async {
    // Verify the theme and widget tree can be constructed.
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Center(child: Text('FitCalorie'))),
        ),
      ),
    );
    expect(find.text('FitCalorie'), findsOneWidget);
  });
}
