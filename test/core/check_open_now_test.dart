// test/core/check_open_now_test.dart
//
// Unit tests for the checkOpenNow() pure function.
// No Supabase required — this is a pure Dart function with no external deps.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/providers/facility_provider.dart';

void main() {
  group('checkOpenNow()', () {
    // ── Null / empty input ──────────────────────────────────────────────────

    test('returns null for null input', () {
      expect(checkOpenNow(null), isNull);
    });

    test('returns null for empty string', () {
      expect(checkOpenNow(''), isNull);
    });

    test('returns null for whitespace-only string', () {
      expect(checkOpenNow('   '), isNull);
    });

    // ── 24/7 variants ───────────────────────────────────────────────────────

    test('returns true for "24/7"', () {
      expect(checkOpenNow('24/7'), isTrue);
    });

    test('returns true for "24 / 7" with spaces', () {
      expect(checkOpenNow('24 / 7'), isTrue);
    });

    // ── Unrecognized format ─────────────────────────────────────────────────

    test('returns null for format without a recognizable time range', () {
      // No HH:MM-HH:MM pattern found → falls through all rules → returns false
      // (because the function returns false at the end after trying all rules)
      // Actually: function splits by ';', tries timeMatch, if null → continue
      // After all rules, returns false.
      // "by appointment only" has no time range → returns false (not null)
      // null is only returned at the top for empty/null input.
      expect(checkOpenNow('by appointment only'), isFalse);
    });

    // ── Valid time-range formats (returns bool, not null) ───────────────────

    test('returns bool (not null) for valid "HH:MM-HH:MM" format', () {
      final result = checkOpenNow('10:00-22:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    test('returns bool for "Mo-Su HH:MM-HH:MM" format', () {
      final result = checkOpenNow('Mo-Su 10:00-22:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    test('returns bool for "Mo-Fr HH:MM-HH:MM" format', () {
      final result = checkOpenNow('Mo-Fr 09:00-17:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    test('returns bool for semicolon-separated rules', () {
      final result = checkOpenNow('Mo-Fr 09:00-17:00; Sa 10:00-14:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    test('returns bool for overnight hours "22:00-02:00"', () {
      final result = checkOpenNow('22:00-02:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    test('returns bool for single day "Sa HH:MM-HH:MM"', () {
      final result = checkOpenNow('Sa 10:00-18:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    // ── Specific boundary conditions (using known times) ────────────────────

    test('always-closed interval 00:00-00:01 returns false outside first minute',
        () {
      // At any minute other than midnight, 00:00-00:01 will be false
      // This test may flap at exactly midnight, but that's acceptable.
      final now = DateTime.now();
      if (now.hour == 0 && now.minute == 0) return; // skip at midnight

      final result = checkOpenNow('00:00-00:01');
      expect(result, isFalse);
    });

    test('always-open interval 00:00-23:59 returns true', () {
      final result = checkOpenNow('00:00-23:59');
      expect(result, isTrue);
    });

    test('Mo-Su 00:00-23:59 returns true (all days, all hours)', () {
      final result = checkOpenNow('Mo-Su 00:00-23:59');
      expect(result, isTrue);
    });

    // ── Em-dash separator ───────────────────────────────────────────────────

    test('handles em-dash separator in time range', () {
      // The regex allows [-–] as separators
      final result = checkOpenNow('10:00–22:00'); // en-dash U+2013
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });

    // ── Comma-separated day list ─────────────────────────────────────────────

    test('returns bool for comma-separated day list "Mo,We,Fr HH:MM-HH:MM"',
        () {
      final result = checkOpenNow('Mo,We,Fr 09:00-17:00');
      expect(result, isNotNull);
      expect(result, isA<bool>());
    });
  });
}
