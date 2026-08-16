import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('matches shared error cases', () async {
    final raw = await File(
      '../../protocol/testdata/error_cases.json',
    ).readAsString();
    final cases = jsonDecode(raw) as List;
    final runtime = await CelRuntime.initialize();

    for (final item in cases) {
      final environment = Map<String, Object?>.from(item['environment'] as Map);
      final source = item['source'] as String;
      final variables = Map<String, Object?>.from(item['variables'] as Map);
      final expected = item['expectedCode'] as String;
      if (item['operation'] == 'validate') {
        final result = await runtime.validate(
          environment: environment,
          source: source,
        );
        expect(
          result.issues.single.code,
          expected,
          reason: item['name'] as String,
        );
      } else {
        try {
          await runtime.evaluate(
            environment: environment,
            source: source,
            variables: variables,
          );
          fail('expected $expected for ${item['name']}');
        } on CelBridgeException catch (error) {
          expect(error.code, expected, reason: item['name'] as String);
        }
      }
    }
  });
}
