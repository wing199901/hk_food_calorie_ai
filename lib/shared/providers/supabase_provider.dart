import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// Global provider for [SupabaseService] (auth + DB operations).
final supabaseProvider = ChangeNotifierProvider<SupabaseService>((ref) {
  return SupabaseService();
});
