import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/profile/profile_page.dart';
import 'package:hk_food_calorie_ai/shared/widgets/profile_field_label.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';

import '../../helpers/fake_storage_service.dart';
import '../../helpers/test_app.dart';

// Integration test is not added for this visual layout tweak because
// deterministic widget assertions can validate label placement directly.
String _currentAge(String birthdateIso) {
  final birthdate = DateTime.parse(birthdateIso);
  final now = DateTime.now();
  var years = now.year - birthdate.year;
  if (now.month < birthdate.month ||
      (now.month == birthdate.month && now.day < birthdate.day)) {
    years -= 1;
  }
  return years.toString();
}

void main() {
  testWidgets('ProfilePage before save shows top labels above field values', (
    tester,
  ) async {
    const birthdateIso = '1990-05-20';
    final fakeStorage = FakeStorageService(
      profile: UserProfile(
        birthdate: birthdateIso,
        gender: 'female',
        unitSystem: 'metric',
      ),
    );

    await tester.pumpWidget(
      buildTestApp(
        overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
        child: const ProfilePage(),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is ProfileFieldLabel && widget.label == 'Birthdate',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ProfileFieldLabel && widget.label == 'Age',
      ),
      findsOneWidget,
    );

    final birthdateLabelY = tester.getTopLeft(find.text('Birthdate')).dy;
    final birthdateValueY = tester.getTopLeft(find.text(birthdateIso)).dy;
    final ageLabelY = tester.getTopLeft(find.text('Age')).dy;
    final ageValueY = tester
        .getTopLeft(find.text(_currentAge(birthdateIso)))
        .dy;

    expect(birthdateLabelY, lessThan(birthdateValueY));
    expect(ageLabelY, lessThan(ageValueY));
  });

  testWidgets(
    'ProfilePage edit mode shows Birthdate/Age labels above their fields',
    (tester) async {
      const birthdateIso = '1990-05-20';
      final fakeStorage = FakeStorageService(
        profile: UserProfile(
          birthdate: birthdateIso,
          gender: 'female',
          unitSystem: 'metric',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [storageProvider.overrideWith((ref) => fakeStorage)],
          child: const ProfilePage(),
        ),
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ProfileFieldLabel && widget.label == 'Birthdate',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ProfileFieldLabel && widget.label == 'Age',
        ),
        findsOneWidget,
      );

      final birthdateLabelY = tester.getTopLeft(find.text('Birthdate')).dy;
      final birthdateValueY = tester.getTopLeft(find.text(birthdateIso)).dy;
      final ageLabelY = tester.getTopLeft(find.text('Age')).dy;
      final ageValueY = tester
          .getTopLeft(find.text(_currentAge(birthdateIso)))
          .dy;

      expect(birthdateLabelY, lessThan(birthdateValueY));
      expect(ageLabelY, lessThan(ageValueY));
    },
  );
}
