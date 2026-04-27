import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/analysis/pages/weight_detail_page.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'renders About Weight knowledge card and three navigation cards',
    (tester) async {
      final fakeStorage = FakeStorageService(
        profile: UserProfile(gender: 'female', height: 175, weight: 47),
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
          child: Scaffold(
            body: WeightDetailPage(
              bodyData: [
                BodyMetric(
                  date: '2026-04-22',
                  weight: 47,
                  createdAt: '2026-04-22T12:00:00Z',
                ),
              ],
              currentWeekStart: DateTime(2026, 4, 19),
              profileWeight: 47,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('About Weight'), findsOneWidget);
      expect(find.text('Why Weight Range Matters'), findsOneWidget);
      expect(find.text('How We Calculate Your Target Range'), findsOneWidget);
      expect(find.text('Why +500 kcal per Day?'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'Body weight is not only about appearance',
              ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('opens detail page when tapping a navigation card', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService(
      profile: UserProfile(gender: 'female', height: 175, weight: 47),
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: Scaffold(
          body: WeightDetailPage(
            bodyData: [
              BodyMetric(
                date: '2026-04-22',
                weight: 47,
                createdAt: '2026-04-22T12:00:00Z',
              ),
            ],
            currentWeekStart: DateTime(2026, 4, 19),
            profileWeight: 47,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final cardTitleFinder = find.text('Why Weight Range Matters');
    await tester.ensureVisible(cardTitleFinder);
    await tester.pumpAndSettle();
    await tester.tap(cardTitleFinder);
    await tester.pumpAndSettle();

    expect(find.text('How Your Weight Range Is Calculated'), findsOneWidget);
    expect(find.text('Current weight'), findsOneWidget);
    expect(find.text('56.7kg'), findsOneWidget);
    expect(find.text('66.0kg'), findsOneWidget);
  });
}
