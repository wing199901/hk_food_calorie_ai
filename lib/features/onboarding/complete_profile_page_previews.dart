import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/onboarding/complete_profile_page.dart';
import 'package:hk_food_calorie_ai/shared/models/body_metric.dart';
import 'package:hk_food_calorie_ai/shared/models/user_profile.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';

class PreviewStorageService extends StorageService {
  @override
  Future<void> setUserProfile(UserProfile profile) async {}

  @override
  void addBodyMetric(BodyMetric metric) {}

  @override
  void setLastCheckInDate(String dateStr) {}
}

Widget completeProfilePreviewWrapper(Widget child) {
  return ProviderScope(
    overrides: [
      storageProvider.overrideWith((ref) => PreviewStorageService()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void completeProfilePreviewOnComplete() {}

@Preview(
  group: 'Onboarding Setup',
  name: 'Empty (Step 1)',
  size: Size(390, 844),
  wrapper: completeProfilePreviewWrapper,
)
Widget completeProfileEmptyPreview() {
  return CompleteProfilePage(
    onComplete: completeProfilePreviewOnComplete,
    initialProfile: UserProfile(),
  );
}

@Preview(
  group: 'Onboarding Setup',
  name: 'Prefilled Imperial (Step 1)',
  size: Size(390, 844),
  wrapper: completeProfilePreviewWrapper,
)
Widget completeProfilePrefilledPreview() {
  return CompleteProfilePage(
    onComplete: completeProfilePreviewOnComplete,
    initialProfile: UserProfile(
      birthdate: '1998-01-20',
      gender: 'female',
      unitSystem: 'imperial',
      height: 165,
      weight: 58,
      waistline: 72,
      activityLevel: 'moderate',
    ),
  );
}
