// test/core/query_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/utils/query_utils.dart';

void main() {
  group('sanitizeLikeInput', () {
    test('escapes percent sign', () {
      expect(sanitizeLikeInput('100%'), '100\\%');
    });

    test('escapes underscore', () {
      expect(sanitizeLikeInput('test_value'), 'test\\_value');
    });

    test('escapes backslash', () {
      expect(sanitizeLikeInput(r'back\slash'), 'back\\\\slash');
    });

    test('escapes combined special characters', () {
      expect(sanitizeLikeInput('100% off_deal'), '100\\% off\\_deal');
    });

    test('leaves normal text unchanged', () {
      expect(sanitizeLikeInput('温泉太郎'), '温泉太郎');
      expect(sanitizeLikeInput('test'), 'test');
      expect(sanitizeLikeInput('hello world'), 'hello world');
    });

    test('handles empty string', () {
      expect(sanitizeLikeInput(''), '');
    });

    test('handles string with only special characters', () {
      expect(sanitizeLikeInput('%_%'), '\\%\\_\\%');
    });

    test('handles multiple consecutive specials', () {
      expect(sanitizeLikeInput('%%__'), '\\%\\%\\_\\_');
    });

    test('handles Japanese text with specials', () {
      expect(sanitizeLikeInput('100%の温泉_施設'), '100\\%の温泉\\_施設');
    });

    test('order of escaping: backslash first, then percent, then underscore', () {
      // This is important: backslash must be escaped first
      // Otherwise \% would become \\% → \\\%
      final result = sanitizeLikeInput(r'\%_');
      expect(result, '\\\\\\_'); // \\ + \% + \_
    });
  });
}
