import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

/// Global provider for [StorageService].
///
/// Initialised in `main()` via `overrideWithValue` so that
/// `SharedPreferences` is ready before the widget tree builds.
final storageProvider = ChangeNotifierProvider<StorageService>((ref) {
  // Fallback — should always be overridden in main().
  return StorageService();
});
