import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/meal.dart';
import '../../../shared/utils/storage_url_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../env/env.dart';

class MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;

  const MealCard({super.key, required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meal.image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMealImage(meal.image!, 80, 80),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(
                      DateTime.fromMillisecondsSinceEpoch(meal.timestamp),
                    ),
                    style: const TextStyle(
                      color: AppTheme.mutedForeground,
                      fontSize: 14,
                    ),
                  ),
                  if (meal.protein != null ||
                      meal.carbs != null ||
                      meal.fat != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (meal.protein != null)
                          Text(
                            'P: ${meal.protein}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                        if (meal.carbs != null)
                          Text(
                            'C: ${meal.carbs}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                        if (meal.fat != null)
                          Text(
                            'F: ${meal.fat}g',
                            style: const TextStyle(
                              color: AppTheme.mutedForeground,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${meal.calories}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    color: AppTheme.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealImage(String imageUrl, double width, double height) {
    if (_isNetworkImage(imageUrl)) {
      final resolvedUrl = normalizeStorageUrl(
        imageUrl,
        baseUrl: Env.supabaseUrl,
      );

      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            Container(width: width, height: height, color: AppTheme.muted),
        errorWidget: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppTheme.muted,
          child: const Icon(Icons.image),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppTheme.muted,
          child: const Icon(Icons.image),
        ),
      );
    }
  }

  bool _isNetworkImage(String path) {
    final parsed = Uri.tryParse(path);
    final looksLikeStoragePath =
        path.startsWith('/storage/v1/') ||
        path.startsWith('storage/v1/') ||
        (parsed != null && parsed.path.startsWith('/storage/v1/'));

    return path.startsWith('http') || looksLikeStoragePath;
  }
}
