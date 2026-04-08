import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/features/add_food/widgets/quick_add_item_card.dart';
import 'package:hk_food_calorie_ai/shared/models/quick_add_item.dart';

import '../../helpers/test_app.dart';

QuickAddItem _item() => QuickAddItem(
  id: 'q1',
  name: 'White Rice',
  calories: 230,
  protein: 4,
  carbs: 50,
  fat: 0,
  sugar: 0,
  icon: 'R',
);

void main() {
  testWidgets('QuickAddItemCard handles tap and long press in normal mode', (
    tester,
  ) async {
    var tapped = 0;
    var longPressed = 0;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: QuickAddItemCard(
            item: _item(),
            isEditMode: false,
            onTap: () => tapped += 1,
            onLongPress: () => longPressed += 1,
            onDelete: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(QuickAddItemCard));
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(QuickAddItemCard));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(longPressed, 1);
  });

  testWidgets('QuickAddItemCard shows delete badge in edit mode', (
    tester,
  ) async {
    var deleted = 0;

    await tester.pumpWidget(
      buildTestApp(
        child: Scaffold(
          body: QuickAddItemCard(
            item: _item(),
            isEditMode: true,
            onTap: () {},
            onLongPress: () {},
            onDelete: () => deleted += 1,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(deleted, 1);
  });
}
