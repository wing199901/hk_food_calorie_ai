class AppTimePolicy {
  AppTimePolicy._();

  // Storage/transport timestamps are normalized to UTC ISO 8601.
  static String nowUtcIsoString() => DateTime.now().toUtc().toIso8601String();

  static DateTime? parseTransportTimestampToUtc(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    return parsed?.toUtc();
  }

  static DateTime? parseTransportTimestampToLocal(String? raw) {
    final utc = parseTransportTimestampToUtc(raw);
    return utc?.toLocal();
  }

  static String? normalizeTransportTimestamp(String? raw) {
    final utc = parseTransportTimestampToUtc(raw);
    return utc?.toIso8601String();
  }

  static DateTime? parseDateKeyLocal(String? dateKey) {
    if (dateKey == null || dateKey.trim().isEmpty) return null;
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime(year, month, day);
  }

  static DateTime startOfLocalDay(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  static String formatDateKeyLocal(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
