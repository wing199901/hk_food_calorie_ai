import 'package:envied/envied.dart';
import 'package:flutter/foundation.dart';

part 'env.g.dart';

/// ── Development ─────────────────────────────────────────────
/// Reads from .env.development at code-generation time.
@Envied(path: '.env.development', obfuscate: true, name: 'DevEnv')
abstract class DevEnv {
  @EnviedField(varName: 'SUPABASE_URL')
  static final String supabaseUrl = _DevEnv.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static final String supabaseAnonKey = _DevEnv.supabaseAnonKey;
}

/// ── Production ──────────────────────────────────────────────
/// Reads from .env.production at code-generation time.
@Envied(path: '.env.production', obfuscate: true, name: 'ProdEnv')
abstract class ProdEnv {
  @EnviedField(varName: 'SUPABASE_URL')
  static final String supabaseUrl = _ProdEnv.supabaseUrl;

  @EnviedField(varName: 'SUPABASE_ANON_KEY')
  static final String supabaseAnonKey = _ProdEnv.supabaseAnonKey;
}

/// ── App Config ──────────────────────────────────────────────
/// Picks dev or prod values automatically based on build mode.
///   - flutter run           → kDebugMode = true  → DevEnv
///   - flutter build ios     → kReleaseMode = true → ProdEnv
class Env {
  Env._();

  static String get supabaseUrl =>
      kReleaseMode ? ProdEnv.supabaseUrl : DevEnv.supabaseUrl;

  static String get supabaseAnonKey =>
      kReleaseMode ? ProdEnv.supabaseAnonKey : DevEnv.supabaseAnonKey;
}
