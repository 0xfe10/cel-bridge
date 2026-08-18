import 'dart:convert';
import 'dart:io';

import 'package:cel_bridge/cel_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('matches shared type contract cases', () async {
    final raw = await File(
      '../../protocol/testdata/type_contract_cases.json',
    ).readAsString();
    final cases = jsonDecode(raw) as List;
    final runtime = await CelRuntime.initialize();

    for (final item in cases) {
      final name = item['name'] as String;
      final environment = Map<String, Object?>.from(item['environment'] as Map);
      final source = item['source'] as String;
      final expectedType = item['expectedResultType'];
      if (item['operation'] == 'validate') {
        final result = await runtime.validate(
          environment: environment,
          source: source,
          expectedResultType: expectedType,
        );
        expect(result.valid, item['valid'] as bool, reason: name);
        if (item.containsKey('resultType')) {
          expect(result.resultType?.toJson(), item['resultType'], reason: name);
        }
        if (item['expectedCode'] != null) {
          expect(result.issues.single.code, item['expectedCode'], reason: name);
        }
        continue;
      }

      final variables = Map<String, Object?>.from(
        (item['variables'] as Map?) ?? const {},
      );
      if (item['ok'] == false) {
        try {
          await runtime.evaluate(
            environment: environment,
            source: source,
            variables: variables,
            expectedResultType: expectedType,
          );
          fail('expected ${item['expectedCode']} for $name');
        } on CelBridgeException catch (error) {
          expect(error.code, item['expectedCode'], reason: name);
        }
        continue;
      }

      final value = await runtime.evaluate(
        environment: environment,
        source: source,
        variables: variables,
        expectedResultType: expectedType,
      );
      expect(value.toJson(), item['expected'], reason: name);
    }
  });
}
