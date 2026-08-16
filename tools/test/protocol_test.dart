import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('shared protocol fixtures are valid JSON arrays', () {
    for (final name in ['conformance_cases.json', 'error_cases.json']) {
      final file = File('../protocol/testdata/$name');
      final value = jsonDecode(file.readAsStringSync());
      expect(value, isA<List>(), reason: name);
      expect((value as List), isNotEmpty, reason: name);
    }
  });

  test('protocol schemas declare the protocol contract', () {
    for (final name in [
      'environment.schema.json',
      'response.schema.json',
      'value.schema.json',
    ]) {
      final value =
          jsonDecode(File('../protocol/schema/$name').readAsStringSync())
              as Map;
      expect(value[r'$schema'], isA<String>(), reason: name);
      expect(value[r'$id'], isA<String>(), reason: name);
    }
  });
}
