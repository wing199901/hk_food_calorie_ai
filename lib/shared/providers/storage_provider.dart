import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

/// Global provider for [StorageService].
///
/// Initialised in `main()` via `overrideWith` so that
/// `SharedPreferences` is ready before the widget tree builds.
final storageProvider = Provider<StorageService>((ref) {
  // Fallback — should always be overridden in main().
  return StorageService();
});

/// Rebuild signal for widgets that depend on [StorageService] updates.
///
/// This keeps the app on Riverpod's non-legacy API while preserving
/// ChangeNotifier-driven refresh behavior from [StorageService].
final storageSignalProvider = NotifierProvider<_StorageSignalNotifier, int>(
  _StorageSignalNotifier.new,
);

class _StorageSignalNotifier extends Notifier<int> {
  @override
  int build() {
    final storage = ref.read(storageProvider);

    void onStorageChanged() {
      state = state + 1;
    }

    storage.addListener(onStorageChanged);
    ref.onDispose(() {
      storage.removeListener(onStorageChanged);
    });

    return 0;
  }
}
