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
        name: '菠蘿油 + 奶茶',
        calories: 520,
        protein: 8,
        carbs: 62,
        fat: 26,
        sugar: 28,
        timestamp: todayBase
            .add(const Duration(hours: 8))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1555126634-323283e090fa?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-2',
        name: '叉燒飯',
        calories: 680,
        protein: 32,
        carbs: 85,
        fat: 22,
        sugar: 8,
        timestamp: todayBase
            .add(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1569058242567-93de6f36f8eb?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-3',
        name: '雲吞麵',
        calories: 380,
        protein: 18,
        carbs: 48,
        fat: 12,
        sugar: 4,
        timestamp: yesterdayBase
            .add(const Duration(hours: 12))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1583032015879-e5022cb87c3b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      ),
      Meal(
        id: 'demo-4',
        name: '蛋撻',
        calories: 220,
        protein: 4,
        carbs: 28,
        fat: 10,
        sugar: 12,
        timestamp: twoDaysAgoBase
            .add(const Duration(hours: 9))
            .millisecondsSinceEpoch,
        image:
            'https://images.unsplash.com/photo-1582106245687-cbb466a9f07f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
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
