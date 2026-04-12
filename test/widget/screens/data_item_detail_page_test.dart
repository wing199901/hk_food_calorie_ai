import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/core/theme/app_spacing.dart';
import 'package:hk_food_calorie_ai/core/theme/app_theme.dart';
import 'package:hk_food_calorie_ai/features/analysis/pages/data_item_detail_page.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('DataItemDetailPage uses light theme shell', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: const DataItemDetailPage(
          valueLabel: 'Height',
          value: '176 cm',
          dateText: '25 Mar 2026 at 01:38:00',
          dateAddedText: '25 Mar 2026 at 01:38:52',
          isUserEntered: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const Key('data_item_detail_scaffold')),
    );
    expect(scaffold.backgroundColor, AppTheme.background);

    final card = tester.widget<Container>(
      find.byKey(const Key('data_item_detail_card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, BorderRadius.circular(16));
    expect(card.padding, const EdgeInsets.symmetric(horizontal: AppSpacing.md));

    final dateAddedLabel = tester.widget<Text>(find.text('Date Added'));
    expect(dateAddedLabel.style?.fontSize, 12);
    expect(dateAddedLabel.style?.color, AppTheme.mutedForeground);

    final valueText = tester.widget<Text>(find.text('176 cm'));
    expect(valueText.style?.fontSize, 16);
    expect(valueText.style?.fontWeight, FontWeight.w600);

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Sample Details'), findsOneWidget);
    expect(find.text('Date Added'), findsOneWidget);
    expect(find.text('Was User Entered'), findsOneWidget);
    expect(find.text('Source'), findsNothing);
  });
}
