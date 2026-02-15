// lib/core/utils/query_utils.dart

/// Sanitizes user input for use in PostgreSQL ILIKE queries.
///
/// Escapes special LIKE pattern characters (`%`, `_`, `\`) to prevent
/// unintended wildcard matching or SQL injection via pattern characters.
///
/// Example:
/// ```dart
/// final safe = sanitizeLikeInput('100% off_deal');
/// // Returns: '100\% off\_deal'
/// ```
String sanitizeLikeInput(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
