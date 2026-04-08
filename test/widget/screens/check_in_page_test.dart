import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/check_in/check_in_page.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

String _todayIso() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

void main() {
  testWidgets('CheckInPage saves metric inputs and calls onComplete', (
    tester,
  ) async {
    final fakeStorage = FakeStorageService(
      profile: UserProfile(
        birthdate: '1990-01-01',
        gender: 'male',
        unitSystem: 'metric',
        height: 175,
      ),
    );
    var completed = 0;

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: CheckInPage(onComplete: () => completed += 1),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '72.5');
    await tester.enterText(find.byType(TextField).at(1), '83.0');
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(fakeStorage.getBodyHistory(), hasLength(1));
    expect(fakeStorage.getLastCheckInDate(), _todayIso());
  });

  testWidgets('CheckInPage skip still sets last check-in date', (tester) async {
    final fakeStorage = FakeStorageService(
      profile: UserProfile(
        birthdate: '1990-01-01',
        gender: 'male',
        unitSystem: 'metric',
      ),
    );
    var completed = 0;

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: CheckInPage(onComplete: () => completed += 1),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(fakeStorage.getLastCheckInDate(), _todayIso());
  });
}
