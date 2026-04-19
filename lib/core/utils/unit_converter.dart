/// Unit conversion utilities.
/// The app always stores values in metric (kg, cm).
/// Use these helpers to convert for display and to convert user input back to metric.
class UnitConverter {
  UnitConverter._();

  // ─── Weight ────────────────────────────────────────────────────────────────

  /// kg → lbs
  static double kgToLbs(double kg) => kg * 2.20462;

  /// lbs → kg
  static double lbsToKg(double lbs) => lbs / 2.20462;

  // ─── Length ────────────────────────────────────────────────────────────────

  /// cm → inches
  static double cmToIn(double cm) => cm / 2.54;

  /// inches → cm
  static double inToCm(double inches) => inches * 2.54;

  /// cm → feet
  static double cmToFt(double cm) => cm / 30.48;

  /// feet → cm
  static double ftToCm(double feet) => feet * 30.48;

  // ─── Display helpers ───────────────────────────────────────────────────────

  /// Returns the display string for a metric weight value (kg stored).
  /// [isMetric] true → "70.0 kg", false → "154.3 lbs"
  static String formatWeight(double? kg, {required bool isMetric}) {
    if (kg == null) return '—';
    if (isMetric) return '${kg.toStringAsFixed(1)} kg';
    return '${kgToLbs(kg).toStringAsFixed(1)} lbs';
  }

  /// Returns the display string for a metric length value (cm stored).
  static String formatLength(double? cm, {required bool isMetric}) {
    if (cm == null) return '—';
    if (isMetric) return '${cm.toStringAsFixed(1)} cm';
    return '${cmToIn(cm).toStringAsFixed(1)} in';
  }

  /// Returns the display string for a metric height value (cm stored).
  static String formatHeight(double? cm, {required bool isMetric}) {
    if (cm == null) return '—';
    if (isMetric) return '${cm.toStringAsFixed(1)} cm';
    return '${cmToFt(cm).toStringAsFixed(1)} ft';
  }

  // ─── Controller helpers ────────────────────────────────────────────────────

  /// Returns the display value text for a TextField from a metric kg value.
  static String weightToDisplay(double? kg, {required bool isMetric}) {
    if (kg == null) return '';
    final v = isMetric ? kg : kgToLbs(kg);
    return v.toStringAsFixed(1);
  }

  /// Returns the display value text for a TextField from a metric cm value.
  /// This generic length helper uses inches in imperial mode.
  static String lengthToDisplay(double? cm, {required bool isMetric}) {
    if (cm == null) return '';
    final v = isMetric ? cm : cmToIn(cm);
    return v.toStringAsFixed(1);
  }

  /// Returns the display value text for a TextField from a metric height value.
  /// Height in imperial mode is shown in feet.
  static String heightToDisplay(double? cm, {required bool isMetric}) {
    if (cm == null) return '';
    final v = isMetric ? cm : cmToFt(cm);
    return v.toStringAsFixed(1);
  }

  /// Parses a TextField string as a metric kg value.
  /// Returns null if blank or unparseable.
  static double? parseWeight(String text, {required bool isMetric}) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    return isMetric ? v : lbsToKg(v);
  }

  /// Parses a TextField string as a metric cm value.
  /// This generic length parser expects inches in imperial mode.
  static double? parseLength(String text, {required bool isMetric}) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    return isMetric ? v : inToCm(v);
  }

  /// Parses a TextField string as a metric height value.
  /// Height in imperial mode expects feet.
  static double? parseHeight(String text, {required bool isMetric}) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    return isMetric ? v : ftToCm(v);
  }
}
