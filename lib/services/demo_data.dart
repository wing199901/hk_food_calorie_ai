import 'package:intl/intl.dart';
import '../models/meal.dart';
import '../models/body_metric.dart';

/// Pre-built demo data used to seed the app for guest / first-time users.
class DemoData {
  DemoData._();

  static List<Meal> buildMeals() {
    final today = DateTime.now();
    final todayBase = DateTime(today.year, today.month, today.day);
    final yesterdayBase = todayBase.subtract(const Duration(days: 1));
    final twoDaysAgoBase = todayBase.subtract(const Duration(days: 2));
    return [
      Meal(
        id: 'demo-1',
        name: 'Breakfast Bowl with Berries',
        calories: 320,
        protein: 12,
        carbs: 54,
        fat: 8,
        timestamp: todayBase
            .add(const Duration(hours: 8))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1602682822546-09bc5623461e?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-2',
        name: 'Grilled Chicken with Vegetables',
        calories: 420,
        protein: 38,
        carbs: 28,
        fat: 18,
        timestamp: todayBase
            .add(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1682423187670-4817da9a1b23?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-3',
        name: 'Fresh Green Salad Bowl',
        calories: 280,
        protein: 15,
        carbs: 22,
        fat: 14,
        timestamp: yesterdayBase
            .add(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1649531794884-b8bb1de72e68?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-4',
        name: 'Berry Smoothie',
        calories: 240,
        protein: 8,
        carbs: 42,
        fat: 5,
        timestamp: twoDaysAgoBase
            .add(const Duration(hours: 9))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1588068403046-169c80c69938?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
    ];
  }

  static List<BodyMetric> buildBodyHistory() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    return [
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 30))),
        weight: 72.5,
        waistline: 85,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 20))),
        weight: 71.8,
        waistline: 84,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 10))),
        weight: 71.2,
        waistline: 83,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 5))),
        weight: 70.8,
        waistline: 82.5,
      ),
      BodyMetric(
        date: fmt.format(now.subtract(const Duration(days: 1))),
        weight: 70.5,
        waistline: 82,
      ),
    ];
  }
}
